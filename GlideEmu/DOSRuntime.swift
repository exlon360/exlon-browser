import Foundation
import SwiftUI
import WebKit

final class DOSBundleBuilder {
    func buildBundle(for package: EmuPackage) throws -> URL {
        guard package.kind == .exe else {
            throw runtimeError("Only .exe packages can use the DOS runtime.")
        }

        let exeData = try Data(contentsOf: package.localURL)
        guard exeData.isEmpty == false else {
            throw runtimeError("The executable file is empty.")
        }

        let directory = try Self.bundleDirectory()
        let bundleURL = directory
            .appendingPathComponent(package.id.uuidString, isDirectory: false)
            .appendingPathExtension("jsdos")

        if FileManager.default.fileExists(atPath: bundleURL.path) {
            try FileManager.default.removeItem(at: bundleURL)
        }

        let zipData = try StoredZipArchive.makeArchive(entries: [
            StoredZipArchive.Entry(name: ".jsdos/dosbox.conf", data: Self.dosboxConfigData()),
            StoredZipArchive.Entry(name: ".jsdos/jsdos.json", data: Self.metadataData(for: package)),
            StoredZipArchive.Entry(name: "RUNME.EXE", data: exeData)
        ])

        try zipData.write(to: bundleURL, options: [.atomic])
        #if os(iOS)
        try? FileManager.default.setAttributes([.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication], ofItemAtPath: bundleURL.path)
        #endif
        return bundleURL
    }

    private static func bundleDirectory() throws -> URL {
        let applicationSupport = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directory = applicationSupport.appendingPathComponent("GlideEmuDOSBundles", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private static func dosboxConfigData() -> Data {
        let config = """
        [sdl]
        fullscreen=false
        autolock=false

        [dosbox]
        machine=svga_s3
        memsize=16

        [render]
        aspect=true
        scaler=normal2x

        [cpu]
        core=auto
        cycles=auto

        [mixer]
        nosound=false
        rate=44100
        blocksize=1024
        prebuffer=25

        [sblaster]
        sbtype=sb16
        sbbase=220
        irq=7
        dma=1
        hdma=5

        [speaker]
        pcspeaker=true

        [autoexec]
        @echo off
        mount c .
        c:
        RUNME.EXE
        """
        return Data(config.utf8)
    }

    private static func metadataData(for package: EmuPackage) throws -> Data {
        let metadata: [String: Any] = [
            "name": package.filename,
            "version": "1.0",
            "backend": "dosbox"
        ]
        return try JSONSerialization.data(withJSONObject: metadata, options: [.prettyPrinted, .sortedKeys])
    }

    private static func runtimeError(_ message: String) -> NSError {
        NSError(domain: "GlideEmuDOSRuntime", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
    }
}

struct DOSWebRunnerView: UIViewRepresentable {
    let bundleURL: URL
    let title: String

    func makeCoordinator() -> Coordinator {
        Coordinator(bundleURL: bundleURL, title: title)
    }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        configuration.setURLSchemeHandler(context.coordinator.schemeHandler, forURLScheme: DOSRuntimeSchemeHandler.scheme)

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.isOpaque = false
        webView.backgroundColor = .black
        webView.scrollView.backgroundColor = .black
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.bounces = false
        webView.allowsBackForwardNavigationGestures = false

        context.coordinator.load(in: webView)
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        context.coordinator.update(bundleURL: bundleURL, title: title, in: webView)
    }

    final class Coordinator {
        let schemeHandler: DOSRuntimeSchemeHandler
        private var currentBundleURL: URL
        private var currentTitle: String

        init(bundleURL: URL, title: String) {
            self.currentBundleURL = bundleURL
            self.currentTitle = title
            self.schemeHandler = DOSRuntimeSchemeHandler(bundleURL: bundleURL, title: title)
        }

        func update(bundleURL: URL, title: String, in webView: WKWebView) {
            guard bundleURL != currentBundleURL || title != currentTitle else { return }
            currentBundleURL = bundleURL
            currentTitle = title
            schemeHandler.update(bundleURL: bundleURL, title: title)
            load(in: webView)
        }

        func load(in webView: WKWebView) {
            guard let url = URL(string: "\(DOSRuntimeSchemeHandler.scheme)://runtime/index.html") else { return }
            webView.load(URLRequest(url: url))
        }
    }
}

final class DOSRuntimeSchemeHandler: NSObject, WKURLSchemeHandler {
    static let scheme = "glideemu"

    private let lock = NSLock()
    private var bundleURL: URL
    private var title: String

    init(bundleURL: URL, title: String) {
        self.bundleURL = bundleURL
        self.title = title
    }

    func update(bundleURL: URL, title: String) {
        lock.lock()
        self.bundleURL = bundleURL
        self.title = title
        lock.unlock()
    }

    func webView(_ webView: WKWebView, start urlSchemeTask: WKURLSchemeTask) {
        guard let url = urlSchemeTask.request.url else {
            finish(urlSchemeTask, error: Self.runtimeError("Missing runtime URL."))
            return
        }

        do {
            let responseData: Data
            let mimeType: String

            switch url.path {
            case "/index.html", "":
                responseData = Data(Self.indexHTML(title: snapshotTitle()).utf8)
                mimeType = "text/html"
            case "/bundle.jsdos":
                responseData = try Data(contentsOf: snapshotBundleURL())
                mimeType = "application/zip"
            case let path where path.hasPrefix("/assets/"):
                let assetName = url.lastPathComponent
                responseData = try Self.assetData(named: assetName)
                mimeType = Self.mimeType(for: assetName)
            default:
                responseData = Data("Not found".utf8)
                mimeType = "text/plain"
            }

            let response = URLResponse(
                url: url,
                mimeType: mimeType,
                expectedContentLength: responseData.count,
                textEncodingName: mimeType == "text/html" ? "utf-8" : nil
            )
            urlSchemeTask.didReceive(response)
            urlSchemeTask.didReceive(responseData)
            urlSchemeTask.didFinish()
        } catch {
            finish(urlSchemeTask, error: error)
        }
    }

    func webView(_ webView: WKWebView, stop urlSchemeTask: WKURLSchemeTask) {}

    private func snapshotBundleURL() -> URL {
        lock.lock()
        let value = bundleURL
        lock.unlock()
        return value
    }

    private func snapshotTitle() -> String {
        lock.lock()
        let value = title
        lock.unlock()
        return value
    }

    private func finish(_ task: WKURLSchemeTask, error: Error) {
        task.didFailWithError(error)
    }

    private static func indexHTML(title: String) -> String {
        let safeTitle = title
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")

        return """
        <!doctype html>
        <html>
        <head>
          <meta charset="utf-8">
          <meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover, maximum-scale=1, user-scalable=no">
          <title>\(safeTitle)</title>
          <link rel="stylesheet" href="glideemu://runtime/assets/js-dos.css">
          <style>
            html, body, #jsdos {
              width: 100%;
              height: 100%;
              margin: 0;
              padding: 0;
              overflow: hidden;
              background: #000;
              touch-action: none;
            }
            body {
              position: fixed;
              inset: 0;
              -webkit-user-select: none;
              user-select: none;
            }
            #boot {
              position: fixed;
              inset: 0;
              display: grid;
              place-items: center;
              z-index: 10;
              color: rgba(255,255,255,0.82);
              background: #000;
              font: 700 13px -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
              letter-spacing: 0;
              text-align: center;
              padding: 24px;
            }
            .dosbox-container, .dosbox-canvas, canvas {
              width: 100% !important;
              height: 100% !important;
              image-rendering: pixelated;
            }
          </style>
        </head>
        <body>
          <div id="jsdos"></div>
          <div id="boot">Starting DOSBox...</div>
          <script src="glideemu://runtime/assets/js-dos.js"></script>
          <script>
            const boot = document.getElementById("boot");
            function show(message) {
              boot.textContent = message;
              boot.style.display = "grid";
            }
            function hideBoot() {
              boot.style.display = "none";
            }
            window.addEventListener("error", function(event) {
              show(event.message || "Runtime failed to start.");
            });
            window.addEventListener("unhandledrejection", function(event) {
              show((event.reason && event.reason.message) || "Runtime failed to start.");
            });
            function start() {
              if (!window.Dos || !window.emulators) {
                show("DOS runtime script did not load.");
                return;
              }
              window.emulators.pathPrefix = "glideemu://runtime/assets/";
              const runner = Dos(document.getElementById("jsdos"));
              const result = runner.run("glideemu://runtime/bundle.jsdos");
              if (result && typeof result.then === "function") {
                result.then(hideBoot).catch(function(error) {
                  show(error && error.message ? error.message : "DOSBox could not run this EXE.");
                });
              } else {
                setTimeout(hideBoot, 1200);
              }
            }
            if (document.readyState === "loading") {
              document.addEventListener("DOMContentLoaded", start);
            } else {
              start();
            }
          </script>
        </body>
        </html>
        """
    }

    private static func assetData(named assetName: String) throws -> Data {
        guard assetName.range(of: #"^[A-Za-z0-9._-]+$"#, options: .regularExpression) != nil,
              let resourceURL = Bundle.main.resourceURL else {
            throw runtimeError("Invalid DOS runtime asset.")
        }

        let assetURL = resourceURL
            .appendingPathComponent("DOSRuntimeAssets", isDirectory: true)
            .appendingPathComponent(assetName, isDirectory: false)
        guard FileManager.default.fileExists(atPath: assetURL.path) else {
            throw runtimeError("Missing DOS runtime asset: \(assetName).")
        }
        return try Data(contentsOf: assetURL)
    }

    private static func mimeType(for assetName: String) -> String {
        switch assetName.lowercased() {
        case let name where name.hasSuffix(".js"):
            return "application/javascript"
        case let name where name.hasSuffix(".css"):
            return "text/css"
        case let name where name.hasSuffix(".wasm"):
            return "application/wasm"
        default:
            return "application/octet-stream"
        }
    }

    private static func runtimeError(_ message: String) -> NSError {
        NSError(domain: "GlideEmuDOSScheme", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
    }
}

private struct StoredZipArchive {
    struct Entry {
        let name: String
        let data: Data
    }

    private struct CentralRecord {
        let nameData: Data
        let crc: UInt32
        let size: UInt32
        let localHeaderOffset: UInt32
    }

    static func makeArchive(entries: [Entry]) throws -> Data {
        var archive = Data()
        var records: [CentralRecord] = []

        for entry in entries {
            guard let nameData = entry.name.data(using: .utf8) else {
                throw archiveError("Could not encode ZIP entry name.")
            }
            let size = try checkedUInt32(entry.data.count, label: entry.name)
            let offset = try checkedUInt32(archive.count, label: entry.name)
            let crc = CRC32.checksum(entry.data)

            archive.appendUInt32LE(0x0403_4b50)
            archive.appendUInt16LE(20)
            archive.appendUInt16LE(0x0800)
            archive.appendUInt16LE(0)
            archive.appendUInt16LE(0)
            archive.appendUInt16LE(0)
            archive.appendUInt32LE(crc)
            archive.appendUInt32LE(size)
            archive.appendUInt32LE(size)
            archive.appendUInt16LE(UInt16(nameData.count))
            archive.appendUInt16LE(0)
            archive.append(nameData)
            archive.append(entry.data)

            records.append(CentralRecord(nameData: nameData, crc: crc, size: size, localHeaderOffset: offset))
        }

        let centralDirectoryOffset = try checkedUInt32(archive.count, label: "central directory")
        var centralDirectory = Data()
        for record in records {
            centralDirectory.appendUInt32LE(0x0201_4b50)
            centralDirectory.appendUInt16LE(20)
            centralDirectory.appendUInt16LE(20)
            centralDirectory.appendUInt16LE(0x0800)
            centralDirectory.appendUInt16LE(0)
            centralDirectory.appendUInt16LE(0)
            centralDirectory.appendUInt16LE(0)
            centralDirectory.appendUInt32LE(record.crc)
            centralDirectory.appendUInt32LE(record.size)
            centralDirectory.appendUInt32LE(record.size)
            centralDirectory.appendUInt16LE(UInt16(record.nameData.count))
            centralDirectory.appendUInt16LE(0)
            centralDirectory.appendUInt16LE(0)
            centralDirectory.appendUInt16LE(0)
            centralDirectory.appendUInt16LE(0)
            centralDirectory.appendUInt32LE(0)
            centralDirectory.appendUInt32LE(record.localHeaderOffset)
            centralDirectory.append(record.nameData)
        }

        let centralDirectorySize = try checkedUInt32(centralDirectory.count, label: "central directory")
        archive.append(centralDirectory)
        archive.appendUInt32LE(0x0605_4b50)
        archive.appendUInt16LE(0)
        archive.appendUInt16LE(0)
        archive.appendUInt16LE(UInt16(records.count))
        archive.appendUInt16LE(UInt16(records.count))
        archive.appendUInt32LE(centralDirectorySize)
        archive.appendUInt32LE(centralDirectoryOffset)
        archive.appendUInt16LE(0)
        return archive
    }

    private static func checkedUInt32(_ value: Int, label: String) throws -> UInt32 {
        guard value <= Int(UInt32.max) else {
            throw archiveError("\(label) is too large for the bundled DOS runtime.")
        }
        return UInt32(value)
    }

    private static func archiveError(_ message: String) -> NSError {
        NSError(domain: "GlideEmuStoredZip", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
    }
}

private enum CRC32 {
    private static let table: [UInt32] = (0...255).map { value in
        var crc = UInt32(value)
        for _ in 0..<8 {
            if crc & 1 == 1 {
                crc = (crc >> 1) ^ 0xedb8_8320
            } else {
                crc >>= 1
            }
        }
        return crc
    }

    static func checksum(_ data: Data) -> UInt32 {
        var crc: UInt32 = 0xffff_ffff
        for byte in data {
            let index = Int((crc ^ UInt32(byte)) & 0xff)
            crc = (crc >> 8) ^ table[index]
        }
        return crc ^ 0xffff_ffff
    }
}

private extension Data {
    mutating func appendUInt16LE(_ value: UInt16) {
        append(UInt8(value & 0xff))
        append(UInt8((value >> 8) & 0xff))
    }

    mutating func appendUInt32LE(_ value: UInt32) {
        append(UInt8(value & 0xff))
        append(UInt8((value >> 8) & 0xff))
        append(UInt8((value >> 16) & 0xff))
        append(UInt8((value >> 24) & 0xff))
    }
}
