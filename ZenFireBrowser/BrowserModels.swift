import Compression
import Foundation

struct BrowserWebExtension: Codable, Identifiable, Equatable {
    let id: UUID
    var extensionIdentifier: String
    var name: String
    var version: String
    var description: String
    var homepageURLString: String
    var manifestVersion: Int
    var contentScripts: [BrowserWebExtensionContentScript]
    var resources: [String: String]
    var permissions: [String]
    var isEnabled: Bool
    var installedAt: Date
    var sourceFilename: String

    init(
        id: UUID = UUID(),
        extensionIdentifier: String,
        name: String,
        version: String,
        description: String = "",
        homepageURLString: String = "",
        manifestVersion: Int,
        contentScripts: [BrowserWebExtensionContentScript],
        resources: [String: String],
        permissions: [String] = [],
        isEnabled: Bool = true,
        installedAt: Date = Date(),
        sourceFilename: String
    ) {
        self.id = id
        self.extensionIdentifier = extensionIdentifier
        self.name = name
        self.version = version
        self.description = description
        self.homepageURLString = homepageURLString
        self.manifestVersion = manifestVersion
        self.contentScripts = contentScripts
        self.resources = resources
        self.permissions = permissions
        self.isEnabled = isEnabled
        self.installedAt = installedAt
        self.sourceFilename = sourceFilename
    }

    var displayName: String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? sourceFilename : trimmed
    }

    var detailText: String {
        let scriptCount = contentScripts.reduce(0) { partialResult, script in
            partialResult + script.js.count + script.css.count
        }
        let versionText = version.trimmingCharacters(in: .whitespacesAndNewlines)
        let prefix = versionText.isEmpty ? "Installed" : "Version \(versionText)"
        return "\(prefix) - \(scriptCount) content file\(scriptCount == 1 ? "" : "s") - content-script mode"
    }

    var supportedScriptCount: Int {
        contentScripts.reduce(0) { partialResult, script in
            partialResult + script.js.count + script.css.count
        }
    }

    func resourceText(for path: String) -> String? {
        let normalized = BrowserWebExtensionPackageReader.normalizedPath(path)
        return resources[normalized]
    }
}

struct BrowserWebExtensionContentScript: Codable, Equatable {
    var matches: [String]
    var excludeMatches: [String]
    var js: [String]
    var css: [String]
    var runAt: BrowserWebExtensionRunAt
    var allFrames: Bool

    var hasRunnableContent: Bool {
        js.isEmpty == false || css.isEmpty == false
    }
}

enum BrowserWebExtensionRunAt: String, Codable {
    case documentStart
    case documentEnd
    case documentIdle

    init(manifestValue: String?) {
        switch manifestValue {
        case "document_start":
            self = .documentStart
        case "document_idle":
            self = .documentIdle
        default:
            self = .documentEnd
        }
    }
}

enum BrowserWebExtensionInstallError: LocalizedError {
    case unsupportedFile
    case packageTooLarge
    case invalidPackage
    case missingManifest
    case manifestNeedsPackage
    case invalidManifest
    case noSupportedContentScripts
    case unsupportedCompression(String)
    case resourceTooLarge(String)
    case missingResource(String)

    var errorDescription: String? {
        switch self {
        case .unsupportedFile:
            return "Choose a Firefox .xpi, Chrome or Brave .crx, .zip, manifest.json, .user.js, .js, or .css file."
        case .packageTooLarge:
            return "That add-on package is too large for Glide's WebExtension importer."
        case .invalidPackage:
            return "That add-on package could not be read."
        case .missingManifest:
            return "The add-on package does not include manifest.json."
        case .manifestNeedsPackage:
            return "Choose the full .zip, .xpi, or .crx package so Glide can import the files referenced by manifest.json."
        case .invalidManifest:
            return "The add-on manifest could not be parsed."
        case .noSupportedContentScripts:
            return "This add-on does not include WebExtension content scripts Glide can inject yet."
        case .unsupportedCompression(let path):
            return "The add-on uses unsupported ZIP compression for \(path)."
        case .resourceTooLarge(let path):
            return "\(path) is too large to import as a content script."
        case .missingResource(let path):
            return "The manifest references \(path), but it was not found in the package."
        }
    }
}

enum BrowserWebExtensionPackageReader {
    private static let maxPackageBytes = 24 * 1024 * 1024
    private static let maxTextResourceBytes = 1 * 1024 * 1024

    static func installableExtension(from data: Data, sourceFilename: String) throws -> BrowserWebExtension {
        guard data.count <= maxPackageBytes else { throw BrowserWebExtensionInstallError.packageTooLarge }

        let lowercasedName = sourceFilename.lowercased()
        if lowercasedName.hasSuffix(".js") || lowercasedName.hasSuffix(".user.js") {
            return installableUserScript(data, sourceFilename: sourceFilename)
        }
        if lowercasedName.hasSuffix(".css") {
            return installableUserStyle(data, sourceFilename: sourceFilename)
        }
        if lowercasedName.hasSuffix(".json") {
            return try installableExtensionFromManifest(data, sourceFilename: sourceFilename)
        }

        guard lowercasedName.hasSuffix(".xpi") || lowercasedName.hasSuffix(".zip") || lowercasedName.hasSuffix(".crx") else {
            throw BrowserWebExtensionInstallError.unsupportedFile
        }

        let archiveData = lowercasedName.hasSuffix(".crx") ? try crxZipPayload(from: data) : data
        let archive = try BrowserZipArchive(data: archiveData)
        guard let manifestData = try archive.data(for: "manifest.json") else {
            throw BrowserWebExtensionInstallError.missingManifest
        }

        let manifest = try decodedManifest(from: manifestData)
        let contentScripts = compatibilityContentScripts(from: manifest)
        guard contentScripts.contains(where: \.hasRunnableContent) else {
            throw BrowserWebExtensionInstallError.noSupportedContentScripts
        }

        var resources: [String: String] = [:]
        for path in Set(contentScripts.flatMap { $0.js + $0.css }) {
            let normalized = normalizedPath(path)
            guard let resourceData = try archive.data(for: normalized) else {
                throw BrowserWebExtensionInstallError.missingResource(normalized)
            }
            guard resourceData.count <= maxTextResourceBytes else {
                throw BrowserWebExtensionInstallError.resourceTooLarge(normalized)
            }
            guard let text = String(data: resourceData, encoding: .utf8) else {
                throw BrowserWebExtensionInstallError.missingResource(normalized)
            }
            resources[normalized] = text
        }

        return BrowserWebExtension(
            extensionIdentifier: manifest.extensionIdentifier(sourceFilename: sourceFilename),
            name: manifest.name,
            version: manifest.version,
            description: manifest.description ?? "",
            homepageURLString: manifest.homepageURL ?? "",
            manifestVersion: manifest.manifestVersion,
            contentScripts: contentScripts,
            resources: resources,
            permissions: manifest.permissions ?? [],
            sourceFilename: sourceFilename
        )
    }

    static func normalizedPath(_ path: String) -> String {
        path
            .replacingOccurrences(of: "\\", with: "/")
            .split(separator: "/", omittingEmptySubsequences: true)
            .filter { $0 != "." && $0 != ".." }
            .joined(separator: "/")
    }

    private static func installableExtensionFromManifest(_ data: Data, sourceFilename: String) throws -> BrowserWebExtension {
        let manifest = try decodedManifest(from: data)
        let contentScripts = compatibilityContentScripts(from: manifest)
        guard contentScripts.contains(where: \.hasRunnableContent) else {
            throw BrowserWebExtensionInstallError.noSupportedContentScripts
        }

        guard contentScripts.flatMap({ $0.js + $0.css }).isEmpty else {
            throw BrowserWebExtensionInstallError.manifestNeedsPackage
        }

        return BrowserWebExtension(
            extensionIdentifier: manifest.extensionIdentifier(sourceFilename: sourceFilename),
            name: manifest.name,
            version: manifest.version,
            description: manifest.description ?? "",
            homepageURLString: manifest.homepageURL ?? "",
            manifestVersion: manifest.manifestVersion,
            contentScripts: contentScripts,
            resources: [:],
            permissions: manifest.permissions ?? [],
            sourceFilename: sourceFilename
        )
    }

    private static func installableUserScript(_ data: Data, sourceFilename: String) -> BrowserWebExtension {
        let source = String(data: data, encoding: .utf8) ?? ""
        let path = normalizedPath(sourceFilename.isEmpty ? "glide-userscript.js" : sourceFilename)
        return BrowserWebExtension(
            extensionIdentifier: "glide-userscript-\(path.lowercased())",
            name: sourceFilename.replacingOccurrences(of: ".user.js", with: "").replacingOccurrences(of: ".js", with: ""),
            version: "1.0",
            description: "Glide user script",
            homepageURLString: "",
            manifestVersion: 3,
            contentScripts: [
                BrowserWebExtensionContentScript(
                    matches: ["<all_urls>"],
                    excludeMatches: [],
                    js: [path],
                    css: [],
                    runAt: .documentEnd,
                    allFrames: false
                )
            ],
            resources: [path: source],
            permissions: ["activeTab"],
            sourceFilename: sourceFilename
        )
    }

    private static func installableUserStyle(_ data: Data, sourceFilename: String) -> BrowserWebExtension {
        let source = String(data: data, encoding: .utf8) ?? ""
        let path = normalizedPath(sourceFilename.isEmpty ? "glide-userstyle.css" : sourceFilename)
        return BrowserWebExtension(
            extensionIdentifier: "glide-userstyle-\(path.lowercased())",
            name: sourceFilename.replacingOccurrences(of: ".css", with: ""),
            version: "1.0",
            description: "Glide user style",
            homepageURLString: "",
            manifestVersion: 3,
            contentScripts: [
                BrowserWebExtensionContentScript(
                    matches: ["<all_urls>"],
                    excludeMatches: [],
                    js: [],
                    css: [path],
                    runAt: .documentStart,
                    allFrames: false
                )
            ],
            resources: [path: source],
            permissions: ["activeTab"],
            sourceFilename: sourceFilename
        )
    }

    private static func decodedManifest(from data: Data) throws -> BrowserWebExtensionManifest {
        do {
            return try JSONDecoder().decode(BrowserWebExtensionManifest.self, from: data)
        } catch {
            throw BrowserWebExtensionInstallError.invalidManifest
        }
    }

    private static func compatibilityContentScripts(from manifest: BrowserWebExtensionManifest) -> [BrowserWebExtensionContentScript] {
        let contentScripts = normalizedContentScripts(from: manifest)
        if contentScripts.contains(where: \.hasRunnableContent) {
            return contentScripts
        }

        let backgroundScripts = manifest.background?.compatibilityScripts ?? []
        guard backgroundScripts.isEmpty == false else { return contentScripts }
        return [
            BrowserWebExtensionContentScript(
                matches: ["<all_urls>"],
                excludeMatches: [],
                js: backgroundScripts.map(normalizedPath),
                css: [],
                runAt: .documentEnd,
                allFrames: false
            )
        ]
    }

    private static func normalizedContentScripts(from manifest: BrowserWebExtensionManifest) -> [BrowserWebExtensionContentScript] {
        (manifest.contentScripts ?? []).map { script in
            BrowserWebExtensionContentScript(
                matches: script.matches?.isEmpty == false ? script.matches ?? [] : ["<all_urls>"],
                excludeMatches: script.excludeMatches ?? [],
                js: (script.js ?? []).map(normalizedPath),
                css: (script.css ?? []).map(normalizedPath),
                runAt: BrowserWebExtensionRunAt(manifestValue: script.runAt),
                allFrames: script.allFrames ?? false
            )
        }
    }

    private static func crxZipPayload(from data: Data) throws -> Data {
        guard data.count >= 12,
              data[0] == 0x43,
              data[1] == 0x72,
              data[2] == 0x32,
              data[3] == 0x34 else {
            throw BrowserWebExtensionInstallError.invalidPackage
        }

        let version = data.uint32LE(at: 4)
        let zipStart: Int
        switch version {
        case 2:
            guard data.count >= 16 else { throw BrowserWebExtensionInstallError.invalidPackage }
            let publicKeyLength = Int(data.uint32LE(at: 8))
            let signatureLength = Int(data.uint32LE(at: 12))
            zipStart = 16 + publicKeyLength + signatureLength
        case 3:
            let headerLength = Int(data.uint32LE(at: 8))
            zipStart = 12 + headerLength
        default:
            throw BrowserWebExtensionInstallError.invalidPackage
        }

        guard zipStart >= 0,
              zipStart + 4 <= data.count,
              data.uint32LE(at: zipStart) == 0x04034b50 else {
            throw BrowserWebExtensionInstallError.invalidPackage
        }

        return Data(data[zipStart..<data.count])
    }
}

private struct BrowserWebExtensionManifest: Decodable {
    let manifestVersion: Int
    let name: String
    let version: String
    let description: String?
    let homepageURL: String?
    let permissions: [String]?
    let contentScripts: [BrowserWebExtensionManifestContentScript]?
    let background: BrowserWebExtensionManifestBackground?
    let browserSpecificSettings: BrowserWebExtensionGeckoSettings?
    let applications: BrowserWebExtensionApplications?

    enum CodingKeys: String, CodingKey {
        case manifestVersion = "manifest_version"
        case name
        case version
        case description
        case homepageURL = "homepage_url"
        case permissions
        case contentScripts = "content_scripts"
        case background
        case browserSpecificSettings = "browser_specific_settings"
        case applications
    }

    func extensionIdentifier(sourceFilename: String) -> String {
        let explicitID = browserSpecificSettings?.gecko?.id ?? applications?.gecko?.id
        if let explicitID,
           explicitID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
            return explicitID
        }

        let fallback = "\(name)-\(version)-\(sourceFilename)"
        return fallback
            .lowercased()
            .filter { $0.isLetter || $0.isNumber || $0 == "." || $0 == "-" || $0 == "_" }
    }
}

private struct BrowserWebExtensionManifestBackground: Decodable {
    let scripts: [String]?
    let serviceWorker: String?

    enum CodingKeys: String, CodingKey {
        case scripts
        case serviceWorker = "service_worker"
    }

    var compatibilityScripts: [String] {
        if let scripts, scripts.isEmpty == false {
            return scripts
        }
        if let serviceWorker, serviceWorker.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
            return [serviceWorker]
        }
        return []
    }
}

private struct BrowserWebExtensionManifestContentScript: Decodable {
    let matches: [String]?
    let excludeMatches: [String]?
    let js: [String]?
    let css: [String]?
    let runAt: String?
    let allFrames: Bool?

    enum CodingKeys: String, CodingKey {
        case matches
        case excludeMatches = "exclude_matches"
        case js
        case css
        case runAt = "run_at"
        case allFrames = "all_frames"
    }
}

private struct BrowserWebExtensionGeckoSettings: Decodable {
    let gecko: BrowserWebExtensionGeckoID?
}

private struct BrowserWebExtensionApplications: Decodable {
    let gecko: BrowserWebExtensionGeckoID?
}

private struct BrowserWebExtensionGeckoID: Decodable {
    let id: String?
}

private struct BrowserZipArchive {
    private struct Entry {
        let path: String
        let compressionMethod: UInt16
        let compressedSize: Int
        let uncompressedSize: Int
        let localHeaderOffset: Int
    }

    private let data: Data
    private let entries: [String: Entry]

    init(data: Data) throws {
        self.data = data
        self.entries = try Self.readEntries(from: data)
    }

    func data(for path: String) throws -> Data? {
        let normalized = BrowserWebExtensionPackageReader.normalizedPath(path)
        guard let entry = entries[normalized] else { return nil }
        guard entry.localHeaderOffset + 30 <= data.count,
              data.uint32LE(at: entry.localHeaderOffset) == 0x04034b50 else {
            throw BrowserWebExtensionInstallError.invalidPackage
        }

        let nameLength = Int(data.uint16LE(at: entry.localHeaderOffset + 26))
        let extraLength = Int(data.uint16LE(at: entry.localHeaderOffset + 28))
        let payloadStart = entry.localHeaderOffset + 30 + nameLength + extraLength
        let payloadEnd = payloadStart + entry.compressedSize
        guard payloadStart >= 0, payloadEnd <= data.count else {
            throw BrowserWebExtensionInstallError.invalidPackage
        }

        let payload = data[payloadStart..<payloadEnd]
        switch entry.compressionMethod {
        case 0:
            return Data(payload)
        case 8:
            return try inflate(payload, uncompressedSize: entry.uncompressedSize, path: normalized)
        default:
            throw BrowserWebExtensionInstallError.unsupportedCompression(normalized)
        }
    }

    private static func readEntries(from data: Data) throws -> [String: Entry] {
        guard let endOfCentralDirectory = data.endOfCentralDirectoryOffset else {
            throw BrowserWebExtensionInstallError.invalidPackage
        }

        let entryCount = Int(data.uint16LE(at: endOfCentralDirectory + 10))
        var offset = Int(data.uint32LE(at: endOfCentralDirectory + 16))
        var entries: [String: Entry] = [:]

        for _ in 0..<entryCount {
            guard offset + 46 <= data.count,
                  data.uint32LE(at: offset) == 0x02014b50 else {
                throw BrowserWebExtensionInstallError.invalidPackage
            }

            let method = data.uint16LE(at: offset + 10)
            let compressedSize = Int(data.uint32LE(at: offset + 20))
            let uncompressedSize = Int(data.uint32LE(at: offset + 24))
            let nameLength = Int(data.uint16LE(at: offset + 28))
            let extraLength = Int(data.uint16LE(at: offset + 30))
            let commentLength = Int(data.uint16LE(at: offset + 32))
            let localHeaderOffset = Int(data.uint32LE(at: offset + 42))
            let nameStart = offset + 46
            let nameEnd = nameStart + nameLength
            guard nameEnd <= data.count else {
                throw BrowserWebExtensionInstallError.invalidPackage
            }

            if let rawName = String(data: data[nameStart..<nameEnd], encoding: .utf8) {
                let path = BrowserWebExtensionPackageReader.normalizedPath(rawName)
                if path.isEmpty == false && rawName.hasSuffix("/") == false {
                    entries[path] = Entry(
                        path: path,
                        compressionMethod: method,
                        compressedSize: compressedSize,
                        uncompressedSize: uncompressedSize,
                        localHeaderOffset: localHeaderOffset
                    )
                }
            }

            offset += 46 + nameLength + extraLength + commentLength
        }

        return entries
    }

    private func inflate(_ payload: Data.SubSequence, uncompressedSize: Int, path: String) throws -> Data {
        guard uncompressedSize >= 0 else {
            throw BrowserWebExtensionInstallError.invalidPackage
        }

        var output = Data(count: uncompressedSize)
        let decodedCount = output.withUnsafeMutableBytes { outputBuffer in
            payload.withUnsafeBytes { inputBuffer in
                compression_decode_buffer(
                    outputBuffer.bindMemory(to: UInt8.self).baseAddress!,
                    uncompressedSize,
                    inputBuffer.bindMemory(to: UInt8.self).baseAddress!,
                    payload.count,
                    nil,
                    COMPRESSION_ZLIB
                )
            }
        }

        guard decodedCount == uncompressedSize else {
            throw BrowserWebExtensionInstallError.unsupportedCompression(path)
        }

        return output
    }
}

private extension Data {
    func uint16LE(at offset: Int) -> UInt16 {
        guard offset + 1 < count else { return 0 }
        return UInt16(self[offset]) | (UInt16(self[offset + 1]) << 8)
    }

    func uint32LE(at offset: Int) -> UInt32 {
        UInt32(uint16LE(at: offset)) | (UInt32(uint16LE(at: offset + 2)) << 16)
    }

    var endOfCentralDirectoryOffset: Int? {
        guard count >= 22 else { return nil }
        let minimumOffset = Swift.max(0, count - 65_557)
        for offset in stride(from: count - 22, through: minimumOffset, by: -1) {
            if uint32LE(at: offset) == 0x06054b50 {
                return offset
            }
        }
        return nil
    }
}

enum BrowserSearchEngine: String, CaseIterable, Identifiable {
    case duckDuckGo
    case google
    case bing
    case brave
    case startpage
    case kagi
    case custom

    static let defaultCustomTemplate = "https://duckduckgo.com/?q={query}"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .duckDuckGo:
            return "DuckDuckGo"
        case .google:
            return "Google"
        case .bing:
            return "Bing"
        case .brave:
            return "Brave"
        case .startpage:
            return "Startpage"
        case .kagi:
            return "Kagi"
        case .custom:
            return "Custom"
        }
    }

    private var queryTemplate: String {
        switch self {
        case .duckDuckGo:
            return "https://duckduckgo.com/?q={query}"
        case .google:
            return "https://www.google.com/search?q={query}"
        case .bing:
            return "https://www.bing.com/search?q={query}"
        case .brave:
            return "https://search.brave.com/search?q={query}"
        case .startpage:
            return "https://www.startpage.com/sp/search?query={query}"
        case .kagi:
            return "https://kagi.com/search?q={query}"
        case .custom:
            return Self.defaultCustomTemplate
        }
    }

    func searchURL(for query: String, customTemplate: String) -> URL {
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        let template = normalizedTemplate(customTemplate)
        let rawURLString: String

        if template.contains("{query}") {
            rawURLString = template.replacingOccurrences(of: "{query}", with: encodedQuery)
        } else {
            let separator = template.contains("?") ? "&" : "?"
            rawURLString = "\(template)\(separator)q=\(encodedQuery)"
        }

        return URL(string: rawURLString) ?? BrowserDefaults.homeURL
    }

    private func normalizedTemplate(_ customTemplate: String) -> String {
        if self != .custom {
            return queryTemplate
        }

        let trimmed = customTemplate.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else {
            return Self.defaultCustomTemplate
        }

        if trimmed.lowercased().hasPrefix("http://") || trimmed.lowercased().hasPrefix("https://") {
            return trimmed
        }

        return "https://\(trimmed)"
    }
}

enum BrowserDarkReaderTheme: String, CaseIterable, Identifiable {
    case zenCopy
    case catppuccinMocha
    case catppuccinMochaDark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .zenCopy:
            return "Zen Copy"
        case .catppuccinMocha:
            return "Catppuccin Mocha"
        case .catppuccinMochaDark:
            return "Catppuccin Dark"
        }
    }

    var symbolName: String {
        switch self {
        case .zenCopy:
            return "moon"
        case .catppuccinMocha:
            return "cup.and.saucer"
        case .catppuccinMochaDark:
            return "moon.stars.fill"
        }
    }
}

enum BrowserMusicTrack: String, CaseIterable, Identifiable {
    case focus
    case rain
    case midnight
    case drift
    case imported

    var id: String { rawValue }

    var title: String {
        switch self {
        case .focus:
            return "Focus Pulse"
        case .rain:
            return "Rain Glass"
        case .midnight:
            return "Midnight Synth"
        case .drift:
            return "Soft Drift"
        case .imported:
            return "Imported Audio"
        }
    }

    var subtitle: String {
        switch self {
        case .focus:
            return "Low, steady browser music"
        case .rain:
            return "Soft noise and slow tones"
        case .midnight:
            return "Dark synthetic pad"
        case .drift:
            return "Light ambient motion"
        case .imported:
            return "A local audio file"
        }
    }

    var symbolName: String {
        switch self {
        case .focus:
            return "music.note"
        case .rain:
            return "cloud.rain"
        case .midnight:
            return "moon.stars"
        case .drift:
            return "waveform"
        case .imported:
            return "music.note.list"
        }
    }
}

enum AIAssistant: String, CaseIterable, Identifiable {
    case chatGPT
    case gemini
    case claude
    case grok

    var id: String { rawValue }

    var title: String {
        switch self {
        case .chatGPT:
            return "ChatGPT"
        case .gemini:
            return "Gemini"
        case .claude:
            return "Claude"
        case .grok:
            return "Grok"
        }
    }

    var menuTitle: String {
        switch self {
        case .chatGPT:
            return "ChatGPT - best available"
        case .gemini:
            return "Gemini - best available"
        case .claude:
            return "Claude - best available"
        case .grok:
            return "Grok - best available"
        }
    }

    var symbolName: String {
        switch self {
        case .chatGPT:
            return "sparkles"
        case .gemini:
            return "diamond"
        case .claude:
            return "circle.hexagongrid"
        case .grok:
            return "bolt.horizontal"
        }
    }

    var url: URL {
        switch self {
        case .chatGPT:
            return URL(string: "https://chatgpt.com/")!
        case .gemini:
            return URL(string: "https://gemini.google.com/app")!
        case .claude:
            return URL(string: "https://claude.ai/new")!
        case .grok:
            return URL(string: "https://grok.com/")!
        }
    }
}

enum BrowserAIAction: String, CaseIterable, Identifiable {
    case summarize
    case keyPoints
    case explain
    case privacyCheck
    case rewrite
    case search

    var id: String { rawValue }

    var title: String {
        switch self {
        case .summarize:
            return "Summarize"
        case .keyPoints:
            return "Key Points"
        case .explain:
            return "Explain"
        case .privacyCheck:
            return "Privacy Check"
        case .rewrite:
            return "Rewrite"
        case .search:
            return "Search Better"
        }
    }

    var symbolName: String {
        switch self {
        case .summarize:
            return "text.alignleft"
        case .keyPoints:
            return "list.bullet.rectangle"
        case .explain:
            return "questionmark.circle"
        case .privacyCheck:
            return "shield.lefthalf.filled"
        case .rewrite:
            return "pencil.and.scribble"
        case .search:
            return "magnifyingglass"
        }
    }

    var instruction: String {
        switch self {
        case .summarize:
            return "Summarize this page in a concise, useful way."
        case .keyPoints:
            return "Extract the key points, dates, numbers, and actions from this page."
        case .explain:
            return "Explain this page clearly like I am trying to understand it fast."
        case .privacyCheck:
            return "Review this page for privacy or security risks and tell me what to watch for."
        case .rewrite:
            return "Rewrite the important content from this page in clearer language."
        case .search:
            return "Turn this page or question into better search queries and next steps."
        }
    }
}

struct BrowserHistoryItem: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var urlString: String
    var visitedAt: Date

    init(id: UUID = UUID(), title: String, urlString: String, visitedAt: Date = Date()) {
        self.id = id
        self.title = title
        self.urlString = urlString
        self.visitedAt = visitedAt
    }

    var url: URL? {
        URL(string: urlString)
    }
}

struct BrowserSearchResult: Identifiable {
    let id = UUID()
    var title: String
    var subtitle: String
    var symbolName: String
    var url: URL
}

struct BrowserEssentialItem: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var urlString: String
    var addedAt: Date

    init(id: UUID = UUID(), title: String, urlString: String, addedAt: Date = Date()) {
        self.id = id
        self.title = title
        self.urlString = urlString
        self.addedAt = addedAt
    }

    var url: URL? {
        URL(string: urlString)
    }
}

enum BrowserDownloadState: String, Codable {
    case inProgress
    case finished
    case failed

    var title: String {
        switch self {
        case .inProgress:
            return "Downloading"
        case .finished:
            return "Finished"
        case .failed:
            return "Failed"
        }
    }
}

enum BrowserTrackerBlockingLevel: String, CaseIterable, Identifiable, Codable {
    case standard
    case aggressive

    var id: String { rawValue }

    var title: String {
        switch self {
        case .standard:
            return "Standard"
        case .aggressive:
            return "Aggressive"
        }
    }
}

enum BrowserWebsiteDisplayMode: String, CaseIterable, Identifiable, Codable {
    case automatic
    case mobile
    case desktop

    var id: String { rawValue }

    var title: String {
        switch self {
        case .automatic:
            return "Auto"
        case .mobile:
            return "Mobile"
        case .desktop:
            return "Desktop"
        }
    }

    var symbolName: String {
        switch self {
        case .automatic:
            return "iphone.and.arrow.forward"
        case .mobile:
            return "iphone"
        case .desktop:
            return "desktopcomputer"
        }
    }
}

struct BrowserDownloadItem: Identifiable, Codable, Equatable {
    var id: UUID
    var filename: String
    var sourceURLString: String
    var localPath: String
    var createdAt: Date
    var state: BrowserDownloadState
    var errorMessage: String?
    var encryptedLocalPath: String?
    var originalByteCount: Int64?

    init(
        id: UUID = UUID(),
        filename: String,
        sourceURLString: String,
        localPath: String,
        createdAt: Date = Date(),
        state: BrowserDownloadState,
        errorMessage: String? = nil,
        encryptedLocalPath: String? = nil,
        originalByteCount: Int64? = nil
    ) {
        self.id = id
        self.filename = filename
        self.sourceURLString = sourceURLString
        self.localPath = localPath
        self.createdAt = createdAt
        self.state = state
        self.errorMessage = errorMessage
        self.encryptedLocalPath = encryptedLocalPath
        self.originalByteCount = originalByteCount
    }

    var localURL: URL {
        URL(fileURLWithPath: localPath)
    }

    var encryptedLocalURL: URL? {
        guard let encryptedLocalPath, encryptedLocalPath.isEmpty == false else { return nil }
        return URL(fileURLWithPath: encryptedLocalPath)
    }

    var isEncrypted: Bool {
        encryptedLocalPath?.isEmpty == false
    }
}

struct BrowserPasswordEntry: Identifiable, Codable, Equatable {
    var id: UUID
    var title: String
    var host: String
    var username: String
    var password: String
    var notes: String
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        title: String,
        host: String,
        username: String,
        password: String,
        notes: String = "",
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.host = host
        self.username = username
        self.password = password
        self.notes = notes
        self.updatedAt = updatedAt
    }

    var normalizedHost: String {
        Self.normalized(host)
    }

    static func normalized(_ rawHost: String) -> String {
        rawHost
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: #"^www\."#, with: "", options: .regularExpression)
    }
}

struct BrowserAdvancedConfig: Codable, Equatable {
    var topSearchBarEnabled: Bool
    var topSearchBarPlacement: String?
    var topSearchBarPositionX: Double?
    var topSearchBarPositionY: Double?
    var chromePlacement: String
    var sideTabsCollapsed: Bool
    var desktopZenModeEnabled: Bool?
    var compactModeHidesQuickControls: Bool?
    var compactModeHidesTopSearchBar: Bool?
    var compactModeRevealsTopSearchBar: Bool?
    var twoFingerDoubleTapCompactOnIPad: Bool?
    var searchEngine: String
    var customSearchTemplate: String
    var newTabOpensSearch: Bool?
    var autoCompactAfterSearchOnPhone: Bool?
    var darkReaderTheme: String?
    var stylusCatppuccinEnabled: Bool?
    var fpsForcerEnabled: Bool?
    var forcedFPS: Double?
    var browserMusicEnabled: Bool?
    var browserMusicTrack: String?
    var browserMusicVolume: Double?
    var devExperienceOverride: String?
    var darkReaderEnabled: Bool
    var adBlockerEnabled: Bool
    var trackerBlockingLevel: String?
    var blockScripts: Bool?
    var upgradeHTTPS: Bool?
    var fingerprintProtection: Bool?
    var blockSocialMedia: Bool?
    var blockPopupAds: Bool?
    var stripTrackingParameters: Bool?
    var blockBounceTracking: Bool?
    var webRTCProtection: Bool?
    var regionTricksEnabled: Bool?
    var regionTrickProfile: String?
    var moreMenuActions: [String]
    var customIcons: [String: String]
    var tabBarTransparencyEnabled: Bool
    var tabBarTransparency: Double
    var userBackgroundEnabled: Bool
    var colors: [String: String]
    var gradientColors: [String: String]?
}

enum BrowserRegionTrickProfile: String, CaseIterable, Identifiable, Codable {
    case unitedStates
    case unitedKingdom
    case canada
    case germany
    case france
    case japan
    case australia
    case brazil
    case india
    case singapore
    case china

    var id: String { rawValue }

    var title: String {
        switch self {
        case .unitedStates:
            return "United States"
        case .unitedKingdom:
            return "United Kingdom"
        case .canada:
            return "Canada"
        case .germany:
            return "Germany"
        case .france:
            return "France"
        case .japan:
            return "Japan"
        case .australia:
            return "Australia"
        case .brazil:
            return "Brazil"
        case .india:
            return "India"
        case .singapore:
            return "Singapore"
        case .china:
            return "China"
        }
    }

    var symbolName: String {
        switch self {
        case .unitedStates, .canada:
            return "globe.americas.fill"
        case .unitedKingdom, .germany, .france:
            return "globe.europe.africa.fill"
        case .japan, .india, .singapore, .china:
            return "globe.asia.australia.fill"
        case .australia:
            return "globe.asia.australia.fill"
        case .brazil:
            return "globe.americas.fill"
        }
    }

    var countryCode: String {
        switch self {
        case .unitedStates:
            return "US"
        case .unitedKingdom:
            return "GB"
        case .canada:
            return "CA"
        case .germany:
            return "DE"
        case .france:
            return "FR"
        case .japan:
            return "JP"
        case .australia:
            return "AU"
        case .brazil:
            return "BR"
        case .india:
            return "IN"
        case .singapore:
            return "SG"
        case .china:
            return "CN"
        }
    }

    var localeIdentifier: String {
        switch self {
        case .unitedStates:
            return "en-US"
        case .unitedKingdom:
            return "en-GB"
        case .canada:
            return "en-CA"
        case .germany:
            return "de-DE"
        case .france:
            return "fr-FR"
        case .japan:
            return "ja-JP"
        case .australia:
            return "en-AU"
        case .brazil:
            return "pt-BR"
        case .india:
            return "en-IN"
        case .singapore:
            return "en-SG"
        case .china:
            return "zh-CN"
        }
    }

    var languages: [String] {
        switch self {
        case .unitedStates:
            return ["en-US", "en"]
        case .unitedKingdom:
            return ["en-GB", "en"]
        case .canada:
            return ["en-CA", "fr-CA", "en", "fr"]
        case .germany:
            return ["de-DE", "de", "en"]
        case .france:
            return ["fr-FR", "fr", "en"]
        case .japan:
            return ["ja-JP", "ja", "en"]
        case .australia:
            return ["en-AU", "en"]
        case .brazil:
            return ["pt-BR", "pt", "en"]
        case .india:
            return ["en-IN", "hi-IN", "en", "hi"]
        case .singapore:
            return ["en-SG", "zh-SG", "ms-SG", "ta-SG", "en"]
        case .china:
            return ["zh-CN", "zh", "en"]
        }
    }

    var timeZoneIdentifier: String {
        switch self {
        case .unitedStates:
            return "America/New_York"
        case .unitedKingdom:
            return "Europe/London"
        case .canada:
            return "America/Toronto"
        case .germany:
            return "Europe/Berlin"
        case .france:
            return "Europe/Paris"
        case .japan:
            return "Asia/Tokyo"
        case .australia:
            return "Australia/Sydney"
        case .brazil:
            return "America/Sao_Paulo"
        case .india:
            return "Asia/Kolkata"
        case .singapore:
            return "Asia/Singapore"
        case .china:
            return "Asia/Shanghai"
        }
    }

    var timeZoneOffsetMinutes: Int {
        switch self {
        case .unitedStates, .canada:
            return 300
        case .unitedKingdom:
            return 0
        case .germany, .france:
            return -60
        case .japan:
            return -540
        case .australia:
            return -600
        case .brazil:
            return 180
        case .india:
            return -330
        case .singapore, .china:
            return -480
        }
    }

    var currencyCode: String {
        switch self {
        case .unitedStates:
            return "USD"
        case .unitedKingdom:
            return "GBP"
        case .canada:
            return "CAD"
        case .germany, .france:
            return "EUR"
        case .japan:
            return "JPY"
        case .australia:
            return "AUD"
        case .brazil:
            return "BRL"
        case .india:
            return "INR"
        case .singapore:
            return "SGD"
        case .china:
            return "CNY"
        }
    }

    var measurementSystem: String {
        switch self {
        case .unitedStates:
            return "imperial"
        default:
            return "metric"
        }
    }

    var coordinate: (latitude: Double, longitude: Double) {
        switch self {
        case .unitedStates:
            return (40.7128, -74.0060)
        case .unitedKingdom:
            return (51.5074, -0.1278)
        case .canada:
            return (43.6532, -79.3832)
        case .germany:
            return (52.5200, 13.4050)
        case .france:
            return (48.8566, 2.3522)
        case .japan:
            return (35.6762, 139.6503)
        case .australia:
            return (-33.8688, 151.2093)
        case .brazil:
            return (-23.5558, -46.6396)
        case .india:
            return (28.6139, 77.2090)
        case .singapore:
            return (1.3521, 103.8198)
        case .china:
            return (39.9042, 116.4074)
        }
    }

    var acceptLanguageHeader: String {
        languages.enumerated().map { index, language in
            guard index > 0 else { return language }
            let quality = max(0.1, 1.0 - (Double(index) * 0.1))
            return String(format: "%@;q=%.1f", language, quality)
        }
        .joined(separator: ",")
    }
}

struct CustomVPNProfile: Codable, Equatable {
    var countryName: String
    var serverAddress: String
    var remoteIdentifier: String
    var username: String
    var password: String?
    var isEnabled: Bool

    static let empty = CustomVPNProfile(
        countryName: "",
        serverAddress: "",
        remoteIdentifier: "",
        username: "",
        password: nil,
        isEnabled: false
    )

    var isConfigured: Bool {
        countryName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false &&
        serverAddress.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    }
}

struct BrowserTabFolder: Identifiable, Codable, Equatable {
    var id: UUID
    var name: String

    init(id: UUID = UUID(), name: String) {
        self.id = id
        self.name = name
    }
}

struct PersistedBrowserTab: Codable {
    var title: String
    var urlString: String
    var isSelected: Bool
    var folderID: UUID?
    var usesDevWebKitProfile: Bool?
}
