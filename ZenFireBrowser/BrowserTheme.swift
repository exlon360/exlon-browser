import SwiftUI
import UIKit

enum BrowserThemeToken: String, CaseIterable, Identifiable {
    case canvas
    case chrome
    case surface
    case field
    case border
    case accent
    case createTab
    case privateAccent
    case text
    case mutedText

    var id: String { rawValue }

    var title: String {
        switch self {
        case .canvas:
            return "Page Canvas"
        case .chrome:
            return "Browser Chrome"
        case .surface:
            return "Panels"
        case .field:
            return "Search Field"
        case .border:
            return "Borders"
        case .accent:
            return "Accent"
        case .createTab:
            return "New Tab Button"
        case .privateAccent:
            return "Private Accent"
        case .text:
            return "Text"
        case .mutedText:
            return "Muted Text"
        }
    }

    var defaultHex: String {
        switch self {
        case .canvas:
            return "#07090D"
        case .chrome:
            return "#101218"
        case .surface:
            return "#181B22"
        case .field:
            return "#20242D"
        case .border:
            return "#343A46"
        case .accent:
            return "#A9B4C8"
        case .createTab:
            return "#D6E2FF"
        case .privateAccent:
            return "#8B7CF6"
        case .text:
            return "#F4F7FB"
        case .mutedText:
            return "#8D96A8"
        }
    }
}

@MainActor
final class BrowserTheme: ObservableObject {
    @Published private var colorHexByToken: [BrowserThemeToken: String]

    private let defaults = UserDefaults.standard
    private static let storagePrefix = "ZenFireBrowser.theme."

    init() {
        var values: [BrowserThemeToken: String] = [:]
        for token in BrowserThemeToken.allCases {
            values[token] = UserDefaults.standard.string(forKey: Self.storageKey(for: token)) ?? token.defaultHex
        }
        self.colorHexByToken = values
    }

    func color(_ token: BrowserThemeToken) -> Color {
        Color(hex: colorHexByToken[token] ?? token.defaultHex)
    }

    func binding(for token: BrowserThemeToken) -> Binding<Color> {
        Binding(
            get: { self.color(token) },
            set: { self.setColor($0, for: token) }
        )
    }

    func setColor(_ color: Color, for token: BrowserThemeToken) {
        let hex = color.hexString ?? token.defaultHex
        colorHexByToken[token] = hex
        defaults.set(hex, forKey: Self.storageKey(for: token))
    }

    func resetToZenDefaults() {
        for token in BrowserThemeToken.allCases {
            colorHexByToken[token] = token.defaultHex
            defaults.set(token.defaultHex, forKey: Self.storageKey(for: token))
        }
    }

    private static func storageKey(for token: BrowserThemeToken) -> String {
        "\(storagePrefix)\(token.rawValue)"
    }
}

extension Color {
    init(hex: String) {
        let sanitized = hex
            .trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
            .uppercased()

        var value: UInt64 = 0
        Scanner(string: sanitized).scanHexInt64(&value)

        let red: Double
        let green: Double
        let blue: Double
        let alpha: Double

        switch sanitized.count {
        case 3:
            red = Double((value >> 8) & 0xF) / 15.0
            green = Double((value >> 4) & 0xF) / 15.0
            blue = Double(value & 0xF) / 15.0
            alpha = 1.0
        case 6:
            red = Double((value >> 16) & 0xFF) / 255.0
            green = Double((value >> 8) & 0xFF) / 255.0
            blue = Double(value & 0xFF) / 255.0
            alpha = 1.0
        case 8:
            red = Double((value >> 24) & 0xFF) / 255.0
            green = Double((value >> 16) & 0xFF) / 255.0
            blue = Double((value >> 8) & 0xFF) / 255.0
            alpha = Double(value & 0xFF) / 255.0
        default:
            red = 1.0
            green = 1.0
            blue = 1.0
            alpha = 1.0
        }

        self.init(red: red, green: green, blue: blue, opacity: alpha)
    }

    var hexString: String? {
        let uiColor = UIColor(self)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0

        guard uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha) else {
            return nil
        }

        return String(
            format: "#%02X%02X%02X",
            Int(red * 255),
            Int(green * 255),
            Int(blue * 255)
        )
    }
}
