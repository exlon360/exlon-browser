import Combine
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
            return "Local Darwin engine"
        case .apk:
            return "Local Android engine"
        case .exe:
            return "Local Windows engine"
        case .deb:
            return "Local Linux engine"
        case .unknown:
            return "Generic local engine"
        }
    }

    var runtimeNote: String {
        switch self {
        case .dmg:
            return "DMG files need a bundled local Darwin-compatible engine before they can run."
        case .apk:
            return "APK files need a bundled local Android runtime before they can run."
        case .exe:
            return "EXE files need a bundled local Windows compatibility engine before they can run."
        case .deb:
            return "DEB files need a bundled local Linux userspace engine before they can run."
        case .unknown:
            return "This file type is not mapped to a runtime slot."
        }
    }
}

enum EmuSessionState: String, Codable {
    case ready
    case engineMissing
    case failed

    var title: String {
        switch self {
        case .ready:
            return "Ready"
        case .engineMissing:
            return "Engine Missing"
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

    init(
        id: UUID = UUID(),
        packageID: UUID,
        packageName: String,
        packageKind: EmuPackageKind,
        startedAt: Date = Date(),
        state: EmuSessionState,
        logLines: [String]
    ) {
        self.id = id
        self.packageID = packageID
        self.packageName = packageName
        self.packageKind = packageKind
        self.startedAt = startedAt
        self.state = state
        self.logLines = logLines
    }
}

struct EmuTouchEvent: Codable, Equatable {
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

@MainActor
final class EmuLibrary: ObservableObject {
    @Published var packages: [EmuPackage] {
        didSet {
            savePackages()
        }
    }
    @Published var selectedPackageID: EmuPackage.ID?
    @Published var activeSession: EmuSession?
    @Published var isEmulatorPresented = false
    @Published var statusMessage = ""

    init() {
        let savedPackages = Self.loadPackages()
        self.packages = savedPackages
        self.selectedPackageID = savedPackages.first?.id
    }

    var selectedPackage: EmuPackage? {
        if let selectedPackageID = selectedPackageID,
           let selected = packages.first(where: { $0.id == selectedPackageID }) {
            return selected
        }

        return packages.first
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
        let state: EmuSessionState = package.kind == .unknown ? .failed : .engineMissing
        let lines = [
            Self.logLine("Loaded \(package.filename)."),
            Self.logLine("Detected \(package.kind.longTitle)."),
            Self.logLine("Selected \(package.kind.runtimeName)."),
            Self.logLine(package.kind.runtimeNote),
            Self.logLine("Using the bundled engine slot for this file type.")
        ]
        activeSession = EmuSession(
            packageID: package.id,
            packageName: package.filename,
            packageKind: package.kind,
            state: state,
            logLines: lines
        )
        isEmulatorPresented = true
        statusMessage = "Local engine session opened for \(package.filename)."
    }

    func recordTouch(_ event: EmuTouchEvent) {
        guard var session = activeSession else { return }

        switch event.type {
        case "tap":
            let x = Int((event.x ?? 0) * 100)
            let y = Int((event.y ?? 0) * 100)
            session.logLines.append(Self.logLine("Touch tap \(x)% \(y)% captured for local engine."))
        case "drag":
            session.logLines.append(Self.logLine("Touch drag captured for local engine."))
        case "pinch":
            session.logLines.append(Self.logLine("Touch pinch \(String(format: "%.2f", event.scale ?? 1)) captured for local engine."))
        case "key":
            session.logLines.append(Self.logLine("Touch key \(event.key ?? "unknown") captured for local engine."))
        default:
            session.logLines.append(Self.logLine("Touch event captured for local engine."))
        }

        activeSession = session
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
        isEmulatorPresented = false
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

    private static func logLine(_ message: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return "[\(formatter.string(from: Date()))] \(message)"
    }

    private static func libraryError(_ message: String) -> NSError {
        NSError(domain: "GlideEmuLibrary", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
    }

    private static let storageKey = "GlideEmu.packages"
}
