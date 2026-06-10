import Combine
import CoreGraphics
import Foundation

enum EmuPackageKind: String, Codable, CaseIterable, Identifiable {
    case dmg
    case apk
    case exe
    case deb
    case unknown

    var id: String { rawValue }

    static let importable: [EmuPackageKind] = [.dmg, .apk, .exe, .deb]

    static func kind(for url: URL) -> EmuPackageKind {
        switch url.pathExtension.lowercased() {
        case "dmg":
            return .dmg
        case "apk":
            return .apk
        case "exe":
            return .exe
        case "deb":
            return .deb
        default:
            return .unknown
        }
    }

    var title: String {
        switch self {
        case .dmg:
            return "DMG"
        case .apk:
            return "APK"
        case .exe:
            return "EXE"
        case .deb:
            return "DEB"
        case .unknown:
            return "Unknown"
        }
    }

    var longTitle: String {
        switch self {
        case .dmg:
            return "macOS disk image"
        case .apk:
            return "Android package"
        case .exe:
            return "Windows executable"
        case .deb:
            return "Debian package"
        case .unknown:
            return "Imported file"
        }
    }

    var symbolName: String {
        switch self {
        case .dmg:
            return "externaldrive"
        case .apk:
            return "app.badge"
        case .exe:
            return "terminal"
        case .deb:
            return "shippingbox"
        case .unknown:
            return "doc"
        }
    }

    var runtimeName: String {
        switch self {
        case .dmg:
            return "Darwin VM bridge"
        case .apk:
            return "Scrcpy Android VM"
        case .exe:
            return "Wine/QEMU VM bridge"
        case .deb:
            return "Linux container VM"
        case .unknown:
            return "Generic VM bridge"
        }
    }

    var bridgeRoute: String {
        switch self {
        case .dmg:
            return "darwin"
        case .apk:
            return "android-scrcpy"
        case .exe:
            return "windows"
        case .deb:
            return "linux"
        case .unknown:
            return "generic"
        }
    }

    var runtimeNote: String {
        switch self {
        case .dmg:
            return "Run sends the DMG to a Darwin VM bridge and opens the returned touch stream."
        case .apk:
            return "Run sends the APK to a scrcpy-style Android VM bridge, then controls it with touch input."
        case .exe:
            return "Run sends the EXE to a Windows compatibility VM bridge backed by Wine or QEMU."
        case .deb:
            return "Run sends the DEB to a Linux container VM bridge and streams the package session."
        case .unknown:
            return "This file type is not mapped to a VM bridge."
        }
    }
}

enum EmuSessionState: String, Codable {
    case ready
    case connecting
    case running
    case bridgeNeeded
    case failed

    var title: String {
        switch self {
        case .ready:
            return "Ready"
        case .connecting:
            return "Connecting"
        case .running:
            return "Running"
        case .bridgeNeeded:
            return "Bridge Needed"
        case .failed:
            return "Failed"
        }
    }
}

struct EmuPackage: Identifiable, Codable, Equatable {
    var id: UUID
    var filename: String
    var kind: EmuPackageKind
    var importedAt: Date
    var localPath: String
    var originalLocation: String
    var byteCount: Int64

    init(
        id: UUID = UUID(),
        filename: String,
        kind: EmuPackageKind,
        importedAt: Date = Date(),
        localPath: String,
        originalLocation: String,
        byteCount: Int64
    ) {
        self.id = id
        self.filename = filename
        self.kind = kind
        self.importedAt = importedAt
        self.localPath = localPath
        self.originalLocation = originalLocation
        self.byteCount = byteCount
    }

    var localURL: URL {
        URL(fileURLWithPath: localPath)
    }
}

struct EmuSession: Identifiable, Codable, Equatable {
    var id: UUID
    var packageID: UUID
    var packageName: String
    var packageKind: EmuPackageKind
    var startedAt: Date
    var state: EmuSessionState
    var logLines: [String]
    var bridgeURLString: String
    var streamURLString: String?
    var touchURLString: String?

    init(
        id: UUID = UUID(),
        packageID: UUID,
        packageName: String,
        packageKind: EmuPackageKind,
        startedAt: Date = Date(),
        state: EmuSessionState,
        logLines: [String],
        bridgeURLString: String = "",
        streamURLString: String? = nil,
        touchURLString: String? = nil
    ) {
        self.id = id
        self.packageID = packageID
        self.packageName = packageName
        self.packageKind = packageKind
        self.startedAt = startedAt
        self.state = state
        self.logLines = logLines
        self.bridgeURLString = bridgeURLString
        self.streamURLString = streamURLString
        self.touchURLString = touchURLString
    }

    var streamURL: URL? {
        guard let streamURLString = streamURLString else { return nil }
        return URL(string: streamURLString)
    }

    var touchURL: URL? {
        guard let touchURLString = touchURLString else { return nil }
        return URL(string: touchURLString)
    }
}

struct EmuTouchEvent: Codable {
    var type: String
    var x: Double?
    var y: Double?
    var dx: Double?
    var dy: Double?
    var scale: Double?
    var key: String?
    var timestamp: TimeInterval

    static func tap(x: Double, y: Double) -> EmuTouchEvent {
        EmuTouchEvent(type: "tap", x: x, y: y, dx: nil, dy: nil, scale: nil, key: nil, timestamp: Date().timeIntervalSince1970)
    }

    static func drag(x: Double, y: Double, dx: Double, dy: Double) -> EmuTouchEvent {
        EmuTouchEvent(type: "drag", x: x, y: y, dx: dx, dy: dy, scale: nil, key: nil, timestamp: Date().timeIntervalSince1970)
    }

    static func pinch(scale: Double) -> EmuTouchEvent {
        EmuTouchEvent(type: "pinch", x: nil, y: nil, dx: nil, dy: nil, scale: scale, key: nil, timestamp: Date().timeIntervalSince1970)
    }

    static func key(_ key: String) -> EmuTouchEvent {
        EmuTouchEvent(type: "key", x: nil, y: nil, dx: nil, dy: nil, scale: nil, key: key, timestamp: Date().timeIntervalSince1970)
    }
}

private struct EmuBridgeStartResponse: Decodable {
    var sessionID: String?
    var streamURL: String?
    var touchURL: String?
    var message: String?
}

@MainActor
final class EmuLibrary: ObservableObject {
    @Published var packages: [EmuPackage] {
        didSet {
            savePackages()
        }
    }
    @Published var selectedPackageID: EmuPackage.ID?
    @Published var activeSession: EmuSession?
    @Published var isVMSessionPresented = false
    @Published var statusMessage = ""
    @Published var bridgeURLText: String {
        didSet {
            UserDefaults.standard.set(bridgeURLText, forKey: Self.bridgeURLStorageKey)
        }
    }

    init() {
        let savedPackages = Self.loadPackages()
        self.packages = savedPackages
        self.selectedPackageID = savedPackages.first?.id
        self.bridgeURLText = UserDefaults.standard.string(forKey: Self.bridgeURLStorageKey) ?? ""
    }

    var selectedPackage: EmuPackage? {
        if let selectedPackageID = selectedPackageID,
           let selected = packages.first(where: { $0.id == selectedPackageID }) {
            return selected
        }

        return packages.first
    }

    var bridgeURL: URL? {
        Self.normalizedURL(from: bridgeURLText)
    }

    var isBridgeConfigured: Bool {
        bridgeURL != nil
    }

    func select(_ package: EmuPackage) {
        selectedPackageID = package.id
    }

    func importFiles(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            importURLs(urls)
        case .failure(let error):
            statusMessage = "Import failed: \(error.localizedDescription)"
        }
    }

    func importExternalURL(_ url: URL) {
        importURLs([url])
    }

    func run(_ package: EmuPackage) {
        selectedPackageID = package.id

        guard let bridgeURL = bridgeURL else {
            activeSession = EmuSession(
                packageID: package.id,
                packageName: package.filename,
                packageKind: package.kind,
                state: .bridgeNeeded,
                logLines: [
                    Self.logLine("Loaded \(package.filename)."),
                    Self.logLine("Detected \(package.kind.longTitle)."),
                    Self.logLine("Configure a Scrcpy VM Bridge URL to run this package."),
                    Self.logLine("The bridge should expose POST /api/sessions and return streamURL plus touchURL.")
                ]
            )
            isVMSessionPresented = true
            statusMessage = "Set a Scrcpy VM Bridge URL before running \(package.filename)."
            return
        }

        let session = EmuSession(
            packageID: package.id,
            packageName: package.filename,
            packageKind: package.kind,
            state: .connecting,
            logLines: [
                Self.logLine("Loaded \(package.filename)."),
                Self.logLine("Detected \(package.kind.longTitle)."),
                Self.logLine("Connecting to \(bridgeURL.absoluteString)."),
                Self.logLine("Runtime route: \(package.kind.bridgeRoute).")
            ],
            bridgeURLString: bridgeURL.absoluteString
        )
        activeSession = session
        isVMSessionPresented = true
        statusMessage = "Opening VM session for \(package.filename)."

        Task {
            await startBridgeSession(package: package, sessionID: session.id, bridgeURL: bridgeURL)
        }
    }

    func sendTouch(_ event: EmuTouchEvent) {
        guard let touchURL = activeSession?.touchURL else {
            appendSessionLog("Touch \(event.type) captured locally; no touch endpoint is connected.")
            return
        }

        Task {
            do {
                var request = URLRequest(url: touchURL)
                request.httpMethod = "POST"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.httpBody = try JSONEncoder().encode(event)
                _ = try await URLSession.shared.data(for: request)
            } catch {
                await MainActor.run {
                    self.appendSessionLog("Touch send failed: \(error.localizedDescription)")
                }
            }
        }
    }

    func delete(_ package: EmuPackage) {
        try? FileManager.default.removeItem(at: package.localURL)
        packages.removeAll { $0.id == package.id }
        if selectedPackageID == package.id {
            selectedPackageID = packages.first?.id
        }
        if activeSession?.packageID == package.id {
            activeSession = nil
        }
        statusMessage = "Removed \(package.filename)."
    }

    func clearSession() {
        activeSession = nil
        isVMSessionPresented = false
    }

    private func startBridgeSession(package: EmuPackage, sessionID: UUID, bridgeURL: URL) async {
        let endpoint = Self.endpoint(base: bridgeURL, path: "/api/sessions")

        do {
            let boundary = "GlideEmu-\(UUID().uuidString)"
            var request = URLRequest(url: endpoint)
            request.httpMethod = "POST"
            request.timeoutInterval = 120
            request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
            request.httpBody = try Self.multipartBody(
                fields: [
                    "kind": package.kind.rawValue,
                    "route": package.kind.bridgeRoute,
                    "filename": package.filename,
                    "touch": "true"
                ],
                fileField: "package",
                fileURL: package.localURL,
                filename: package.filename,
                boundary: boundary
            )

            let (data, response) = try await URLSession.shared.data(for: request)
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            guard (200...299).contains(statusCode) else {
                throw Self.libraryError("Bridge returned HTTP \(statusCode).")
            }

            let decoded = try JSONDecoder().decode(EmuBridgeStartResponse.self, from: data)
            await MainActor.run {
                self.applyBridgeResponse(decoded, package: package, sessionID: sessionID, bridgeURL: bridgeURL)
            }
        } catch {
            await MainActor.run {
                self.openDirectBridgeFallback(package: package, sessionID: sessionID, bridgeURL: bridgeURL, error: error)
            }
        }
    }

    private func applyBridgeResponse(_ response: EmuBridgeStartResponse, package: EmuPackage, sessionID: UUID, bridgeURL: URL) {
        guard activeSession?.id == sessionID else { return }

        let streamURLString = Self.absoluteURLString(response.streamURL, relativeTo: bridgeURL) ?? bridgeURL.absoluteString
        let touchURLString = Self.absoluteURLString(response.touchURL, relativeTo: bridgeURL)
            ?? Self.endpoint(base: bridgeURL, path: "/api/touch").absoluteString
        var session = activeSession
        session?.state = .running
        session?.streamURLString = streamURLString
        session?.touchURLString = touchURLString
        session?.logLines.append(Self.logLine(response.message ?? "Bridge accepted \(package.filename)."))
        session?.logLines.append(Self.logLine("Stream connected. Touch input is enabled."))
        activeSession = session
        statusMessage = "VM stream running for \(package.filename)."
    }

    private func openDirectBridgeFallback(package: EmuPackage, sessionID: UUID, bridgeURL: URL, error: Error) {
        guard activeSession?.id == sessionID else { return }

        let streamURL = Self.directStreamURL(base: bridgeURL, package: package)
        var session = activeSession
        session?.state = .running
        session?.streamURLString = streamURL.absoluteString
        session?.touchURLString = Self.endpoint(base: bridgeURL, path: "/api/touch").absoluteString
        session?.logLines.append(Self.logLine("Upload API failed: \(error.localizedDescription)"))
        session?.logLines.append(Self.logLine("Opened the bridge screen directly so touch streaming can still work."))
        activeSession = session
        statusMessage = "Opened bridge fallback for \(package.filename)."
    }

    private func appendSessionLog(_ message: String) {
        guard var session = activeSession else { return }
        session.logLines.append(Self.logLine(message))
        activeSession = session
    }

    private func importURLs(_ urls: [URL]) {
        guard urls.isEmpty == false else { return }

        var importedCount = 0
        var failureMessages: [String] = []

        for url in urls {
            do {
                let package = try importURL(url)
                packages.insert(package, at: 0)
                selectedPackageID = package.id
                importedCount += 1
            } catch {
                failureMessages.append("\(url.lastPathComponent): \(error.localizedDescription)")
            }
        }

        if importedCount > 0 {
            statusMessage = "Imported \(importedCount) package\(importedCount == 1 ? "" : "s")."
        }
        if failureMessages.isEmpty == false {
            statusMessage = failureMessages.joined(separator: "\n")
        }
    }

    private func importURL(_ url: URL) throws -> EmuPackage {
        let kind = EmuPackageKind.kind(for: url)
        guard EmuPackageKind.importable.contains(kind) else {
            throw Self.libraryError("Use a .dmg, .apk, .exe, or .deb file.")
        }

        let didAccess = url.startAccessingSecurityScopedResource()
        defer {
            if didAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }

        let directory = try Self.packageDirectory()
        let filename = Self.safeFilename(url.lastPathComponent)
        let destination = directory.appendingPathComponent("\(UUID().uuidString)-\(filename)")

        if FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.removeItem(at: destination)
        }

        try FileManager.default.copyItem(at: url, to: destination)
        #if os(iOS)
        try? FileManager.default.setAttributes([.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication], ofItemAtPath: destination.path)
        #endif

        let values = try destination.resourceValues(forKeys: [.fileSizeKey])
        return EmuPackage(
            filename: filename,
            kind: kind,
            localPath: destination.path,
            originalLocation: url.path,
            byteCount: Int64(values.fileSize ?? 0)
        )
    }

    private func savePackages() {
        do {
            let data = try JSONEncoder().encode(packages)
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        } catch {
            statusMessage = "Could not save package library: \(error.localizedDescription)"
        }
    }

    private static func loadPackages() -> [EmuPackage] {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let packages = try? JSONDecoder().decode([EmuPackage].self, from: data) else {
            return []
        }

        return packages.filter { FileManager.default.fileExists(atPath: $0.localPath) }
    }

    private static func packageDirectory() throws -> URL {
        let applicationSupport = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directory = applicationSupport.appendingPathComponent("GlideEmuPackages", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private static func safeFilename(_ filename: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: ".-_ "))
        let scalars = filename.unicodeScalars.map { allowed.contains($0) ? Character($0) : "-" }
        let cleaned = String(scalars).trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? "package.bin" : cleaned
    }

    private static func normalizedURL(from rawValue: String) -> URL? {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return nil }

        if trimmed.lowercased().hasPrefix("http://") || trimmed.lowercased().hasPrefix("https://") {
            return URL(string: trimmed)
        }

        return URL(string: "http://\(trimmed)")
    }

    private static func endpoint(base: URL, path: String) -> URL {
        guard var components = URLComponents(url: base, resolvingAgainstBaseURL: false) else {
            return base.appendingPathComponent(path.trimmingCharacters(in: CharacterSet(charactersIn: "/")))
        }

        let basePath = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let endpointPath = path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        components.path = "/" + [basePath, endpointPath].filter { $0.isEmpty == false }.joined(separator: "/")
        return components.url ?? base
    }

    private static func absoluteURLString(_ value: String?, relativeTo base: URL) -> String? {
        guard let value = value, value.isEmpty == false else { return nil }
        if value.lowercased().hasPrefix("http://") || value.lowercased().hasPrefix("https://") {
            return value
        }
        return URL(string: value, relativeTo: base)?.absoluteURL.absoluteString
    }

    private static func directStreamURL(base: URL, package: EmuPackage) -> URL {
        guard var components = URLComponents(url: base, resolvingAgainstBaseURL: false) else {
            return base
        }

        var queryItems = components.queryItems ?? []
        queryItems.append(URLQueryItem(name: "kind", value: package.kind.rawValue))
        queryItems.append(URLQueryItem(name: "route", value: package.kind.bridgeRoute))
        queryItems.append(URLQueryItem(name: "file", value: package.filename))
        queryItems.append(URLQueryItem(name: "touch", value: "1"))
        components.queryItems = queryItems
        return components.url ?? base
    }

    private static func multipartBody(
        fields: [String: String],
        fileField: String,
        fileURL: URL,
        filename: String,
        boundary: String
    ) throws -> Data {
        var body = Data()

        for (key, value) in fields {
            body.appendString("--\(boundary)\r\n")
            body.appendString("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n")
            body.appendString("\(value)\r\n")
        }

        body.appendString("--\(boundary)\r\n")
        body.appendString("Content-Disposition: form-data; name=\"\(fileField)\"; filename=\"\(filename)\"\r\n")
        body.appendString("Content-Type: application/octet-stream\r\n\r\n")
        body.append(try Data(contentsOf: fileURL))
        body.appendString("\r\n--\(boundary)--\r\n")
        return body
    }

    private static func logLine(_ message: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return "[\(formatter.string(from: Date()))] \(message)"
    }

    private static func libraryError(_ message: String) -> NSError {
        NSError(domain: "GlideEmuLibrary", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
    }

    private static let storageKey = "GlideEmu.packages"
    private static let bridgeURLStorageKey = "GlideEmu.bridgeURL"
}

private extension Data {
    mutating func appendString(_ string: String) {
        append(string.data(using: .utf8) ?? Data())
    }
}
