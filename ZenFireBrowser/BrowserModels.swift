import Foundation

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

struct BrowserAdvancedConfig: Codable, Equatable {
    var topSearchBarEnabled: Bool
    var topSearchBarPlacement: String?
    var topSearchBarPositionX: Double?
    var topSearchBarPositionY: Double?
    var chromePlacement: String
    var sideTabsCollapsed: Bool
    var searchEngine: String
    var customSearchTemplate: String
    var newTabOpensSearch: Bool?
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
    var moreMenuActions: [String]
    var customIcons: [String: String]
    var tabBarTransparencyEnabled: Bool
    var tabBarTransparency: Double
    var userBackgroundEnabled: Bool
    var colors: [String: String]
    var gradientColors: [String: String]?
}

struct CustomVPNProfile: Codable, Equatable {
    var countryName: String
    var serverAddress: String
    var remoteIdentifier: String
    var username: String
    var isEnabled: Bool

    static let empty = CustomVPNProfile(
        countryName: "",
        serverAddress: "",
        remoteIdentifier: "",
        username: "",
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
