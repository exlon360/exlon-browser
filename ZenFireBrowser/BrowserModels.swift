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

struct PersistedBrowserTab: Codable {
    var title: String
    var urlString: String
    var isSelected: Bool
}
