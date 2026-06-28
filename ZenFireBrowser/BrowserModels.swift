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
        }
    }

    var symbolName: String {
        switch self {
        case .unitedStates, .canada:
            return "globe.americas.fill"
        case .unitedKingdom, .germany, .france:
            return "globe.europe.africa.fill"
        case .japan, .india, .singapore:
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
        case .singapore:
            return -480
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
