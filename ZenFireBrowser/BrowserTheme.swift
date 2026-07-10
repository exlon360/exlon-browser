import AVFoundation
import SwiftUI
import UIKit
import UniformTypeIdentifiers

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

    var defaultGradientHex: String {
        switch self {
        case .canvas:
            return "#111827"
        case .chrome:
            return "#1A2230"
        case .surface:
            return "#232936"
        case .field:
            return "#2D3442"
        case .border:
            return "#4C5667"
        case .accent:
            return "#D6E2FF"
        case .createTab:
            return "#A9B4C8"
        case .privateAccent:
            return "#C4B5FD"
        case .text:
            return "#FFFFFF"
        case .mutedText:
            return "#BAC2D1"
        }
    }
}

struct SavedBrowserTheme: Identifiable, Codable, Equatable {
    var id: UUID
    var name: String
    var colorHexByToken: [String: String]
    var gradientColorHexByToken: [String: String]?
    var gradientStartX: Double?
    var gradientStartY: Double?
    var gradientEndX: Double?
    var gradientEndY: Double?
    var gradientPositionsByToken: [String: BrowserGradientPosition]?
    var gradientCirclesByToken: [String: [BrowserThemeGradientCircle]]?
    var customColors: [BrowserCustomThemeColor]?
    var isTabBarTransparencyEnabled: Bool
    var tabBarTransparency: Double
    var isUserBackgroundEnabled: Bool
    var userBackgroundImageData: Data?
    var userBackgroundVideoData: Data?
    var userBackgroundVideoContentType: String?
    var userBackgroundVideoDuration: Double?
    var savedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        colorHexByToken: [String: String],
        gradientColorHexByToken: [String: String]? = nil,
        gradientStartX: Double? = nil,
        gradientStartY: Double? = nil,
        gradientEndX: Double? = nil,
        gradientEndY: Double? = nil,
        gradientPositionsByToken: [String: BrowserGradientPosition]? = nil,
        gradientCirclesByToken: [String: [BrowserThemeGradientCircle]]? = nil,
        customColors: [BrowserCustomThemeColor]? = nil,
        isTabBarTransparencyEnabled: Bool,
        tabBarTransparency: Double,
        isUserBackgroundEnabled: Bool,
        userBackgroundImageData: Data?,
        userBackgroundVideoData: Data? = nil,
        userBackgroundVideoContentType: String? = nil,
        userBackgroundVideoDuration: Double? = nil,
        savedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.colorHexByToken = colorHexByToken
        self.gradientColorHexByToken = gradientColorHexByToken
        self.gradientStartX = gradientStartX
        self.gradientStartY = gradientStartY
        self.gradientEndX = gradientEndX
        self.gradientEndY = gradientEndY
        self.gradientPositionsByToken = gradientPositionsByToken
        self.gradientCirclesByToken = gradientCirclesByToken
        self.customColors = customColors
        self.isTabBarTransparencyEnabled = isTabBarTransparencyEnabled
        self.tabBarTransparency = tabBarTransparency
        self.isUserBackgroundEnabled = isUserBackgroundEnabled
        self.userBackgroundImageData = userBackgroundImageData
        self.userBackgroundVideoData = userBackgroundVideoData
        self.userBackgroundVideoContentType = userBackgroundVideoContentType
        self.userBackgroundVideoDuration = userBackgroundVideoDuration
        self.savedAt = savedAt
    }
}

struct BrowserGradientPosition: Codable, Equatable {
    var startX: Double
    var startY: Double
    var endX: Double
    var endY: Double

    init(startX: Double = 0.0, startY: Double = 0.0, endX: Double = 1.0, endY: Double = 1.0) {
        self.startX = min(max(startX, 0), 1)
        self.startY = min(max(startY, 0), 1)
        self.endX = min(max(endX, 0), 1)
        self.endY = min(max(endY, 0), 1)
    }

    init(focusX: Double, focusY: Double) {
        let x = min(max(focusX, 0), 1)
        let y = min(max(focusY, 0), 1)
        self.init(startX: 1.0 - x, startY: 1.0 - y, endX: x, endY: y)
    }

    var startPoint: UnitPoint {
        UnitPoint(x: startX, y: startY)
    }

    var endPoint: UnitPoint {
        UnitPoint(x: endX, y: endY)
    }

    var focusX: Double {
        endX
    }

    var focusY: Double {
        endY
    }
}

struct BrowserThemeGradientCircle: Identifiable, Codable, Equatable {
    var id: UUID
    var colorHex: String
    var intensity: Double
    var x: Double
    var y: Double

    init(id: UUID = UUID(), colorHex: String, intensity: Double = 0.72, x: Double = 0.5, y: Double = 0.5) {
        self.id = id
        self.colorHex = colorHex
        self.intensity = min(max(intensity, 0), 1)
        self.x = min(max(x, 0), 1)
        self.y = min(max(y, 0), 1)
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case colorHex
        case intensity
        case x
        case y
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        self.colorHex = try container.decodeIfPresent(String.self, forKey: .colorHex) ?? "#C4B5FD"
        self.intensity = min(max(try container.decodeIfPresent(Double.self, forKey: .intensity) ?? 0.72, 0), 1)
        self.x = min(max(try container.decodeIfPresent(Double.self, forKey: .x) ?? 0.5, 0), 1)
        self.y = min(max(try container.decodeIfPresent(Double.self, forKey: .y) ?? 0.5, 0), 1)
    }
}

struct BrowserCustomThemeColor: Identifiable, Codable, Equatable {
    var id: UUID
    var name: String
    var colorHex: String
    var gradientHex: String
    var location: Double
    var gradientX: Double?
    var gradientY: Double?
    var intensity: Double?

    init(
        id: UUID = UUID(),
        name: String,
        colorHex: String,
        gradientHex: String,
        location: Double,
        gradientX: Double? = nil,
        gradientY: Double? = nil,
        intensity: Double? = nil
    ) {
        self.id = id
        self.name = name
        self.colorHex = colorHex
        self.gradientHex = gradientHex
        self.location = min(max(location, 0), 1)
        self.gradientX = gradientX.map { min(max($0, 0), 1) }
        self.gradientY = gradientY.map { min(max($0, 0), 1) }
        self.intensity = intensity.map { min(max($0, 0), 1) }
    }
}

extension UTType {
    static let glideTheme = UTType(exportedAs: "com.exlon360.glide.theme", conformingTo: .json)
}

@MainActor
final class BrowserTheme: ObservableObject {
    @Published private var colorHexByToken: [BrowserThemeToken: String]
    @Published private var gradientColorHexByToken: [BrowserThemeToken: String]
    @Published private var gradientPositionByToken: [String: BrowserGradientPosition] {
        didSet {
            vault.save(gradientPositionByToken, forKey: Self.gradientPositionByTokenKey)
        }
    }
    @Published private var gradientCirclesByToken: [String: [BrowserThemeGradientCircle]] {
        didSet {
            vault.save(gradientCirclesByToken, forKey: Self.gradientCirclesByTokenKey)
        }
    }
    @Published var customColors: [BrowserCustomThemeColor] {
        didSet {
            vault.save(customColors, forKey: Self.customColorsKey)
        }
    }
    @Published var gradientStartX: Double {
        didSet {
            let clamped = Self.clampedUnit(gradientStartX)
            if clamped != gradientStartX {
                gradientStartX = clamped
                return
            }
            vault.save(gradientStartX, forKey: Self.gradientStartXKey)
        }
    }
    @Published var gradientStartY: Double {
        didSet {
            let clamped = Self.clampedUnit(gradientStartY)
            if clamped != gradientStartY {
                gradientStartY = clamped
                return
            }
            vault.save(gradientStartY, forKey: Self.gradientStartYKey)
        }
    }
    @Published var gradientEndX: Double {
        didSet {
            let clamped = Self.clampedUnit(gradientEndX)
            if clamped != gradientEndX {
                gradientEndX = clamped
                return
            }
            vault.save(gradientEndX, forKey: Self.gradientEndXKey)
        }
    }
    @Published var gradientEndY: Double {
        didSet {
            let clamped = Self.clampedUnit(gradientEndY)
            if clamped != gradientEndY {
                gradientEndY = clamped
                return
            }
            vault.save(gradientEndY, forKey: Self.gradientEndYKey)
        }
    }
    @Published var isTabBarTransparencyEnabled: Bool {
        didSet {
            vault.save(isTabBarTransparencyEnabled, forKey: Self.tabBarTransparencyEnabledKey)
        }
    }
    @Published var tabBarTransparency: Double {
        didSet {
            let clamped = min(max(tabBarTransparency, 0), 1.0)
            if clamped != tabBarTransparency {
                tabBarTransparency = clamped
                return
            }
            vault.save(tabBarTransparency, forKey: Self.tabBarTransparencyKey)
        }
    }
    @Published var isUserBackgroundEnabled: Bool {
        didSet {
            vault.save(isUserBackgroundEnabled, forKey: Self.userBackgroundEnabledKey)
        }
    }
    @Published private var userBackgroundImageData: Data?
    @Published private var userBackgroundVideoData: Data?
    @Published private var userBackgroundVideoContentType: String?
    @Published private var userBackgroundVideoDuration: Double?
    @Published private var userBackgroundVideoStorageID: String?
    @Published var backgroundImportMessage = ""
    @Published var savedThemes: [SavedBrowserTheme]

    private let vault: SecureBrowserVault
    private static let storagePrefix = "ZenFireBrowser.theme."
    private static let tabBarTransparencyEnabledKey = "\(storagePrefix)tabBarTransparencyEnabled"
    private static let tabBarTransparencyKey = "\(storagePrefix)tabBarTransparency"
    private static let userBackgroundEnabledKey = "\(storagePrefix)userBackgroundEnabled"
    private static let userBackgroundImageDataKey = "\(storagePrefix)userBackgroundImageData"
    private static let userBackgroundVideoDataKey = "\(storagePrefix)userBackgroundVideoData"
    private static let userBackgroundVideoStorageIDKey = "\(storagePrefix)userBackgroundVideoStorageID"
    private static let userBackgroundVideoContentTypeKey = "\(storagePrefix)userBackgroundVideoContentType"
    private static let userBackgroundVideoDurationKey = "\(storagePrefix)userBackgroundVideoDuration"
    private static let savedThemesKey = "\(storagePrefix)savedThemes"
    private static let gradientStartXKey = "\(storagePrefix)gradientStartX"
    private static let gradientStartYKey = "\(storagePrefix)gradientStartY"
    private static let gradientEndXKey = "\(storagePrefix)gradientEndX"
    private static let gradientEndYKey = "\(storagePrefix)gradientEndY"
    private static let gradientPositionByTokenKey = "\(storagePrefix)gradientPositionByToken"
    private static let gradientCirclesByTokenKey = "\(storagePrefix)gradientCirclesByToken"
    private static let customColorsKey = "\(storagePrefix)customColors"
    private static let videoBackgroundMinimumDuration = 5.0
    private static let videoBackgroundMaximumDuration = 15.0 * 60.0
    private static let backgroundVideoDirectoryName = "GlideBackgroundVideos"
    private static let backgroundVideoFileExtension = "glidebg"

    init(vault: SecureBrowserVault) {
        self.vault = vault
        var values: [BrowserThemeToken: String] = [:]
        var gradientValues: [BrowserThemeToken: String] = [:]
        for token in BrowserThemeToken.allCases {
            values[token] = vault.load(String.self, forKey: Self.storageKey(for: token), default: token.defaultHex)
            gradientValues[token] = vault.load(
                String.self,
                forKey: Self.gradientStorageKey(for: token),
                default: token.defaultGradientHex
            )
        }
        let legacyGradientPosition = BrowserGradientPosition(
            startX: Self.clampedUnit(vault.load(Double.self, forKey: Self.gradientStartXKey, default: 0.0)),
            startY: Self.clampedUnit(vault.load(Double.self, forKey: Self.gradientStartYKey, default: 0.0)),
            endX: Self.clampedUnit(vault.load(Double.self, forKey: Self.gradientEndXKey, default: 1.0)),
            endY: Self.clampedUnit(vault.load(Double.self, forKey: Self.gradientEndYKey, default: 1.0))
        )
        self.colorHexByToken = values
        self.gradientColorHexByToken = gradientValues
        self.gradientPositionByToken = Self.normalizedGradientPositions(
            vault.load([String: BrowserGradientPosition].self, forKey: Self.gradientPositionByTokenKey, default: [:]),
            fallback: legacyGradientPosition
        )
        self.gradientCirclesByToken = Self.normalizedGradientCircles(
            vault.load([String: [BrowserThemeGradientCircle]].self, forKey: Self.gradientCirclesByTokenKey, default: [:]),
            fallbackGradientHexByToken: gradientValues
        )
        self.gradientStartX = legacyGradientPosition.startX
        self.gradientStartY = legacyGradientPosition.startY
        self.gradientEndX = legacyGradientPosition.endX
        self.gradientEndY = legacyGradientPosition.endY
        self.customColors = Self.normalizedCustomColors(
            vault.load([BrowserCustomThemeColor].self, forKey: Self.customColorsKey, default: [])
        )
        self.isTabBarTransparencyEnabled = vault.load(Bool.self, forKey: Self.tabBarTransparencyEnabledKey, default: true)
        self.tabBarTransparency = vault.load(Double.self, forKey: Self.tabBarTransparencyKey, default: 0.82)
        self.isUserBackgroundEnabled = vault.load(Bool.self, forKey: Self.userBackgroundEnabledKey, default: false)
        self.userBackgroundImageData = vault.loadOptional(Data.self, forKey: Self.userBackgroundImageDataKey)
        self.userBackgroundVideoData = vault.loadOptional(Data.self, forKey: Self.userBackgroundVideoDataKey)
        self.userBackgroundVideoStorageID = vault.loadOptional(String.self, forKey: Self.userBackgroundVideoStorageIDKey)
        self.userBackgroundVideoContentType = vault.loadOptional(String.self, forKey: Self.userBackgroundVideoContentTypeKey)
        self.userBackgroundVideoDuration = vault.loadOptional(Double.self, forKey: Self.userBackgroundVideoDurationKey)
        self.savedThemes = vault.load([SavedBrowserTheme].self, forKey: Self.savedThemesKey, default: [])
        loadOrMigrateStoredVideoBackground()
        migrateLoadedThemeToEncryptedVault()
    }

    func color(_ token: BrowserThemeToken) -> Color {
        Color(hex: colorHexByToken[token] ?? token.defaultHex)
    }

    func gradientColor(_ token: BrowserThemeToken) -> Color {
        Color(hex: gradientColorHexByToken[token] ?? token.defaultGradientHex)
    }

    func hex(for token: BrowserThemeToken) -> String {
        colorHexByToken[token] ?? token.defaultHex
    }

    func gradientHex(for token: BrowserThemeToken) -> String {
        gradientColorHexByToken[token] ?? token.defaultGradientHex
    }

    var colorConfig: [String: String] {
        Dictionary(uniqueKeysWithValues: BrowserThemeToken.allCases.map { token in
            (token.rawValue, hex(for: token))
        })
    }

    var gradientColorConfig: [String: String] {
        Dictionary(uniqueKeysWithValues: BrowserThemeToken.allCases.map { token in
            (token.rawValue, gradientHex(for: token))
        })
    }

    var gradientStartPoint: UnitPoint {
        UnitPoint(x: gradientStartX, y: gradientStartY)
    }

    var gradientEndPoint: UnitPoint {
        UnitPoint(x: gradientEndX, y: gradientEndY)
    }

    var gradientCoordinateConfig: [String: Double] {
        [
            "startX": gradientStartX,
            "startY": gradientStartY,
            "endX": gradientEndX,
            "endY": gradientEndY
        ]
    }

    var gradientPositionConfigByToken: [String: BrowserGradientPosition] {
        Dictionary(uniqueKeysWithValues: BrowserThemeToken.allCases.map { token in
            (token.rawValue, gradientPosition(for: token))
        })
    }

    var gradientCircleConfigByToken: [String: [BrowserThemeGradientCircle]] {
        Dictionary(uniqueKeysWithValues: BrowserThemeToken.allCases.map { token in
            (token.rawValue, gradientCircles(for: token))
        })
    }

    var customGradientColors: [Color] {
        customColors
            .sorted { $0.location < $1.location }
            .flatMap { stop in
                [
                    Color(hex: stop.colorHex).opacity(customColorIntensity(stop)),
                    Color(hex: stop.gradientHex).opacity(customColorIntensity(stop))
                ]
            }
    }

    var tabBarOpacity: Double {
        isTabBarTransparencyEnabled ? max(0.0, 1.0 - tabBarTransparency) : 1.0
    }

    var chromeMaterialOpacity: Double {
        isTabBarTransparencyEnabled ? tabBarOpacity * 0.72 : 0.72
    }

    var chromeGradientOpacity: Double {
        isTabBarTransparencyEnabled ? tabBarOpacity : 1.0
    }

    var controlOpacity: Double {
        isTabBarTransparencyEnabled ? max(0.18, 1.0 - (tabBarTransparency * 0.65)) : 1.0
    }

    var hasUserBackground: Bool {
        userBackgroundImageData != nil || userBackgroundVideoData != nil
    }

    var userBackgroundImage: UIImage? {
        guard let userBackgroundImageData = userBackgroundImageData else { return nil }
        return UIImage(data: userBackgroundImageData)
    }

    var hasUserBackgroundVideo: Bool {
        userBackgroundVideoData != nil
    }

    var userBackgroundVideo: (data: Data, contentType: String?)? {
        guard let userBackgroundVideoData = userBackgroundVideoData else { return nil }
        return (userBackgroundVideoData, userBackgroundVideoContentType)
    }

    var userBackgroundVideoDurationLabel: String? {
        guard let userBackgroundVideoDuration = userBackgroundVideoDuration else { return nil }
        let seconds = Int(userBackgroundVideoDuration.rounded())
        if seconds >= 60 {
            return "\(seconds / 60)m \(seconds % 60)s video"
        }
        return "\(seconds)s video"
    }

    func binding(for token: BrowserThemeToken) -> Binding<Color> {
        Binding(
            get: { self.color(token) },
            set: { self.setColor($0, for: token) }
        )
    }

    func gradientBinding(for token: BrowserThemeToken) -> Binding<Color> {
        Binding(
            get: { self.gradientColor(token) },
            set: { self.setGradientColor($0, for: token) }
        )
    }

    func gradientPosition(for token: BrowserThemeToken) -> BrowserGradientPosition {
        gradientPositionByToken[token.rawValue] ?? BrowserGradientPosition(
            startX: gradientStartX,
            startY: gradientStartY,
            endX: gradientEndX,
            endY: gradientEndY
        )
    }

    func gradientStartPoint(for token: BrowserThemeToken) -> UnitPoint {
        gradientPosition(for: token).startPoint
    }

    func gradientEndPoint(for token: BrowserThemeToken) -> UnitPoint {
        gradientPosition(for: token).endPoint
    }

    func gradientCircles(for token: BrowserThemeToken) -> [BrowserThemeGradientCircle] {
        gradientCirclesByToken[token.rawValue] ?? [
            BrowserThemeGradientCircle(colorHex: gradientHex(for: token), intensity: 0.72)
        ]
    }

    func gradientColors(for token: BrowserThemeToken) -> [Color] {
        let circles = gradientCircles(for: token).sorted {
            gradientLocation(for: $0, token: token) < gradientLocation(for: $1, token: token)
        }
        guard circles.isEmpty == false else {
            return [gradientColor(token)]
        }
        return circles.map { circle in
            Color(hex: circle.colorHex).opacity(circle.intensity)
        }
    }

    func gradientStops(for token: BrowserThemeToken) -> [Gradient.Stop] {
        var stops = [Gradient.Stop(color: color(token), location: 0)]
        stops.append(contentsOf: gradientCircles(for: token).map { circle in
            Gradient.Stop(
                color: Color(hex: circle.colorHex).opacity(circle.intensity),
                location: CGFloat(gradientLocation(for: circle, token: token))
            )
        })
        stops.append(Gradient.Stop(color: color(token).opacity(0.86), location: 1))
        return stops.sorted { $0.location < $1.location }
    }

    var customGradientStops: [Gradient.Stop] {
        customColors.flatMap { color -> [Gradient.Stop] in
            let intensity = customColorIntensity(color)
            let center = customGradientLocation(for: color)
            let spread = 0.04 + (0.08 * intensity)
            return [
                Gradient.Stop(
                    color: Color(hex: color.colorHex).opacity(intensity),
                    location: CGFloat(max(0, center - spread))
                ),
                Gradient.Stop(
                    color: Color(hex: color.gradientHex).opacity(intensity),
                    location: CGFloat(min(1, center + spread))
                )
            ]
        }
        .sorted { $0.location < $1.location }
    }

    func combinedGradientStops(for token: BrowserThemeToken, includeCustomColors: Bool) -> [Gradient.Stop] {
        let stops = gradientStops(for: token) + (includeCustomColors ? customGradientStops : [])
        return stops.sorted { $0.location < $1.location }
    }

    @discardableResult
    func addGradientCircle(for token: BrowserThemeToken) -> BrowserThemeGradientCircle {
        var circles = gradientCircles(for: token)
        let palette = [
            token.defaultGradientHex,
            "#7DD3FC",
            "#C4B5FD",
            "#A7F3D0",
            "#FDE68A",
            "#F9A8D4",
            "#67E8F9"
        ]
        let circle = BrowserThemeGradientCircle(
            colorHex: palette[circles.count % palette.count],
            intensity: min(0.9, 0.5 + Double(circles.count) * 0.08),
            x: Self.defaultGradientCircleCoordinate(for: circles.count).x,
            y: Self.defaultGradientCircleCoordinate(for: circles.count).y
        )
        circles.append(circle)
        setGradientCircles(circles, for: token)
        return circle
    }

    func removeGradientCircle(_ circle: BrowserThemeGradientCircle, for token: BrowserThemeToken) {
        var circles = gradientCircles(for: token)
        guard circles.count > 1 else { return }
        circles.removeAll { $0.id == circle.id }
        setGradientCircles(circles, for: token)
    }

    func setGradientCircleColor(_ color: Color, circle: BrowserThemeGradientCircle, for token: BrowserThemeToken) {
        var circles = gradientCircles(for: token)
        guard let index = circles.firstIndex(where: { $0.id == circle.id }) else { return }
        circles[index].colorHex = color.hexString ?? circles[index].colorHex
        setGradientCircles(circles, for: token)
    }

    func setGradientCircleIntensity(_ intensity: Double, circle: BrowserThemeGradientCircle, for token: BrowserThemeToken) {
        var circles = gradientCircles(for: token)
        guard let index = circles.firstIndex(where: { $0.id == circle.id }) else { return }
        circles[index].intensity = Self.clampedUnit(intensity)
        setGradientCircles(circles, for: token)
    }

    func setGradientCirclePosition(x: Double, y: Double, circle: BrowserThemeGradientCircle, for token: BrowserThemeToken) {
        var circles = gradientCircles(for: token)
        guard let index = circles.firstIndex(where: { $0.id == circle.id }) else { return }
        circles[index].x = Self.clampedUnit(x)
        circles[index].y = Self.clampedUnit(y)
        setGradientCircles(circles, for: token)
    }

    func setColor(_ color: Color, for token: BrowserThemeToken) {
        let hex = color.hexString ?? token.defaultHex
        var values = colorHexByToken
        values[token] = hex
        colorHexByToken = values
        vault.save(hex, forKey: Self.storageKey(for: token))
    }

    func setGradientColor(_ color: Color, for token: BrowserThemeToken) {
        let hex = color.hexString ?? token.defaultGradientHex
        var values = gradientColorHexByToken
        values[token] = hex
        gradientColorHexByToken = values
        setGradientCircles([BrowserThemeGradientCircle(colorHex: hex, intensity: 0.72)], for: token)
        vault.save(hex, forKey: Self.gradientStorageKey(for: token))
    }

    func updateGradientStart(x: Double, y: Double) {
        gradientStartX = x
        gradientStartY = y
        syncLegacyGradientPositionToAllTokens()
    }

    func updateGradientEnd(x: Double, y: Double) {
        gradientEndX = x
        gradientEndY = y
        syncLegacyGradientPositionToAllTokens()
    }

    func updateGradientFocus(x: Double, y: Double, for token: BrowserThemeToken) {
        gradientPositionByToken[token.rawValue] = BrowserGradientPosition(focusX: x, focusY: y)
    }

    func setGradientPosition(_ position: BrowserGradientPosition, for token: BrowserThemeToken) {
        gradientPositionByToken[token.rawValue] = BrowserGradientPosition(
            startX: position.startX,
            startY: position.startY,
            endX: position.endX,
            endY: position.endY
        )
    }

    func resetGradientFocus(for token: BrowserThemeToken) {
        gradientPositionByToken[token.rawValue] = BrowserGradientPosition()
    }

    func resetGradientMotion() {
        gradientStartX = 0.0
        gradientStartY = 0.0
        gradientEndX = 1.0
        gradientEndY = 1.0
        gradientPositionByToken = Self.normalizedGradientPositions([:], fallback: BrowserGradientPosition())
    }

    @discardableResult
    func addCustomColor() -> BrowserCustomThemeColor {
        let presets = [
            ("Vapor Blue", "#7DD3FC", "#C4B5FD"),
            ("Solar Mint", "#A7F3D0", "#FDE68A"),
            ("Hot Signal", "#F9A8D4", "#67E8F9"),
            ("Amber Glass", "#FDBA74", "#93C5FD")
        ]
        let preset = presets[customColors.count % presets.count]
        let stop = BrowserCustomThemeColor(
            name: preset.0,
            colorHex: preset.1,
            gradientHex: preset.2,
            location: customColors.isEmpty ? 0.5 : min(0.92, 0.18 + (Double(customColors.count) * 0.18)),
            gradientX: customColors.isEmpty ? 0.5 : min(0.92, 0.18 + (Double(customColors.count) * 0.18)),
            gradientY: 0.5,
            intensity: 0.72
        )
        customColors.append(stop)
        return stop
    }

    func removeCustomColor(_ color: BrowserCustomThemeColor) {
        customColors.removeAll { $0.id == color.id }
    }

    func renameCustomColor(_ color: BrowserCustomThemeColor, to rawName: String) {
        guard let index = customColors.firstIndex(where: { $0.id == color.id }) else { return }
        let trimmed = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        customColors[index].name = trimmed.isEmpty ? "Custom Color \(index + 1)" : trimmed
    }

    func setCustomColor(_ color: Color, for customColor: BrowserCustomThemeColor) {
        guard let index = customColors.firstIndex(where: { $0.id == customColor.id }) else { return }
        customColors[index].colorHex = color.hexString ?? customColors[index].colorHex
    }

    func setCustomGradientColor(_ color: Color, for customColor: BrowserCustomThemeColor) {
        guard let index = customColors.firstIndex(where: { $0.id == customColor.id }) else { return }
        customColors[index].gradientHex = color.hexString ?? customColors[index].gradientHex
    }

    func setCustomColorLocation(_ location: Double, for customColor: BrowserCustomThemeColor) {
        guard let index = customColors.firstIndex(where: { $0.id == customColor.id }) else { return }
        customColors[index].location = Self.clampedUnit(location)
    }

    func setCustomColorIntensity(_ intensity: Double, for customColor: BrowserCustomThemeColor) {
        guard let index = customColors.firstIndex(where: { $0.id == customColor.id }) else { return }
        customColors[index].intensity = Self.clampedUnit(intensity)
    }

    func setCustomGradientFocus(x: Double, y: Double, for customColor: BrowserCustomThemeColor) {
        guard let index = customColors.firstIndex(where: { $0.id == customColor.id }) else { return }
        let clampedX = Self.clampedUnit(x)
        customColors[index].gradientX = clampedX
        customColors[index].gradientY = Self.clampedUnit(y)
        customColors[index].location = clampedX
    }

    func customColorIntensity(_ color: BrowserCustomThemeColor) -> Double {
        Self.clampedUnit(color.intensity ?? 0.72)
    }

    func currentTheme(named rawName: String) -> SavedBrowserTheme {
        let trimmedName = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        let themeName = trimmedName.isEmpty ? "Glide Theme" : trimmedName
        let savedColors = Dictionary(uniqueKeysWithValues: colorHexByToken.map { ($0.key.rawValue, $0.value) })
        let savedGradientColors = Dictionary(uniqueKeysWithValues: gradientColorHexByToken.map { ($0.key.rawValue, $0.value) })
        return SavedBrowserTheme(
            name: themeName,
            colorHexByToken: savedColors,
            gradientColorHexByToken: savedGradientColors,
            gradientStartX: gradientStartX,
            gradientStartY: gradientStartY,
            gradientEndX: gradientEndX,
            gradientEndY: gradientEndY,
            gradientPositionsByToken: gradientPositionConfigByToken,
            gradientCirclesByToken: gradientCircleConfigByToken,
            customColors: customColors,
            isTabBarTransparencyEnabled: isTabBarTransparencyEnabled,
            tabBarTransparency: tabBarTransparency,
            isUserBackgroundEnabled: isUserBackgroundEnabled,
            userBackgroundImageData: userBackgroundImageData,
            userBackgroundVideoData: userBackgroundVideoData,
            userBackgroundVideoContentType: userBackgroundVideoContentType,
            userBackgroundVideoDuration: userBackgroundVideoDuration
        )
    }

    func resetToZenDefaults() {
        for token in BrowserThemeToken.allCases {
            colorHexByToken[token] = token.defaultHex
            gradientColorHexByToken[token] = token.defaultGradientHex
            vault.save(token.defaultHex, forKey: Self.storageKey(for: token))
            vault.save(token.defaultGradientHex, forKey: Self.gradientStorageKey(for: token))
        }

        isTabBarTransparencyEnabled = true
        tabBarTransparency = 0.82
        resetGradientMotion()
        gradientCirclesByToken = Self.defaultGradientCircles(fallbackGradientHexByToken: gradientColorHexByToken)
        customColors = []
        isUserBackgroundEnabled = false
        userBackgroundImageData = nil
        userBackgroundVideoData = nil
        userBackgroundVideoContentType = nil
        userBackgroundVideoDuration = nil
        removeStoredUserBackgroundVideo()
        vault.remove(Self.userBackgroundImageDataKey)
        vault.remove(Self.userBackgroundVideoDataKey)
        vault.remove(Self.userBackgroundVideoStorageIDKey)
        vault.remove(Self.userBackgroundVideoContentTypeKey)
        vault.remove(Self.userBackgroundVideoDurationKey)
    }

    func applyAdvancedConfig(
        colors: [String: String],
        gradientColors: [String: String]?,
        gradientCoordinates: [String: Double]?,
        gradientPositionsByToken: [String: BrowserGradientPosition]?,
        gradientCirclesByToken: [String: [BrowserThemeGradientCircle]]?,
        customColors: [BrowserCustomThemeColor]?,
        tabBarTransparencyEnabled: Bool,
        tabBarTransparency: Double,
        userBackgroundEnabled: Bool
    ) {
        for token in BrowserThemeToken.allCases {
            guard let hex = colors[token.rawValue],
                  Color.isValidHex(hex) else { continue }
            colorHexByToken[token] = hex
            vault.save(hex, forKey: Self.storageKey(for: token))
        }
        if let gradientColors {
            for token in BrowserThemeToken.allCases {
                guard let hex = gradientColors[token.rawValue],
                      Color.isValidHex(hex) else { continue }
                gradientColorHexByToken[token] = hex
                vault.save(hex, forKey: Self.gradientStorageKey(for: token))
            }
        }
        if let gradientCoordinates {
            gradientStartX = gradientCoordinates["startX"] ?? gradientStartX
            gradientStartY = gradientCoordinates["startY"] ?? gradientStartY
            gradientEndX = gradientCoordinates["endX"] ?? gradientEndX
            gradientEndY = gradientCoordinates["endY"] ?? gradientEndY
            syncLegacyGradientPositionToAllTokens()
        }
        if let gradientPositionsByToken {
            self.gradientPositionByToken = Self.normalizedGradientPositions(
                gradientPositionsByToken,
                fallback: BrowserGradientPosition(
                    startX: gradientStartX,
                    startY: gradientStartY,
                    endX: gradientEndX,
                    endY: gradientEndY
                )
            )
        }
        if let gradientCirclesByToken {
            self.gradientCirclesByToken = Self.normalizedGradientCircles(
                gradientCirclesByToken,
                fallbackGradientHexByToken: gradientColorHexByToken
            )
        } else if gradientColors != nil {
            self.gradientCirclesByToken = Self.defaultGradientCircles(fallbackGradientHexByToken: gradientColorHexByToken)
        }
        if let customColors {
            self.customColors = Self.normalizedCustomColors(customColors)
        }

        isTabBarTransparencyEnabled = tabBarTransparencyEnabled
        self.tabBarTransparency = tabBarTransparency
        isUserBackgroundEnabled = userBackgroundEnabled && hasUserBackground
    }

    func setUserBackground(from url: URL) {
        let didAccess = url.startAccessingSecurityScopedResource()
        defer {
            if didAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }

        guard let rawData = try? Data(contentsOf: url) else {
            return
        }

        let contentType = (try? url.resourceValues(forKeys: [.contentTypeKey]))?.contentType
        if contentType?.conforms(to: .movie) == true || contentType?.conforms(to: .video) == true {
            setUserBackground(fromVideoData: rawData, contentTypeIdentifier: contentType?.identifier)
        } else {
            setUserBackground(fromImageData: rawData)
        }
    }

    func setUserBackground(fromImageData rawData: Data) {
        guard let image = UIImage(data: rawData),
              let data = image.jpegData(compressionQuality: 0.86) else {
            backgroundImportMessage = "That image could not be imported."
            return
        }

        userBackgroundImageData = data
        userBackgroundVideoData = nil
        userBackgroundVideoContentType = nil
        userBackgroundVideoDuration = nil
        removeStoredUserBackgroundVideo()
        isUserBackgroundEnabled = true
        backgroundImportMessage = "Image background applied."
        vault.save(data, forKey: Self.userBackgroundImageDataKey)
        vault.remove(Self.userBackgroundVideoDataKey)
        vault.remove(Self.userBackgroundVideoStorageIDKey)
        vault.remove(Self.userBackgroundVideoContentTypeKey)
        vault.remove(Self.userBackgroundVideoDurationKey)
    }

    func setUserBackground(fromVideoData rawData: Data, contentTypeIdentifier: String?) {
        guard let metadata = Self.videoMetadata(from: rawData, contentTypeIdentifier: contentTypeIdentifier) else {
            backgroundImportMessage = "That video could not be imported."
            return
        }

        guard metadata.duration >= Self.videoBackgroundMinimumDuration,
              metadata.duration <= Self.videoBackgroundMaximumDuration else {
            backgroundImportMessage = "Choose a video between 5 seconds and 15 minutes."
            return
        }

        guard let storageID = storeUserBackgroundVideo(rawData) else {
            backgroundImportMessage = "That video could not be saved securely."
            return
        }

        removeStoredUserBackgroundVideo()
        userBackgroundVideoStorageID = storageID
        userBackgroundVideoData = rawData
        userBackgroundVideoContentType = contentTypeIdentifier ?? UTType.mpeg4Movie.identifier
        userBackgroundVideoDuration = metadata.duration
        userBackgroundImageData = metadata.posterData
        isUserBackgroundEnabled = true
        backgroundImportMessage = "Animated background applied."
        vault.remove(Self.userBackgroundVideoDataKey)
        vault.save(storageID, forKey: Self.userBackgroundVideoStorageIDKey)
        vault.save(userBackgroundVideoContentType, forKey: Self.userBackgroundVideoContentTypeKey)
        vault.save(metadata.duration, forKey: Self.userBackgroundVideoDurationKey)
        if let posterData = metadata.posterData {
            vault.save(posterData, forKey: Self.userBackgroundImageDataKey)
        } else {
            vault.remove(Self.userBackgroundImageDataKey)
        }
    }

    func clearUserBackground() {
        userBackgroundImageData = nil
        userBackgroundVideoData = nil
        userBackgroundVideoContentType = nil
        userBackgroundVideoDuration = nil
        removeStoredUserBackgroundVideo()
        isUserBackgroundEnabled = false
        backgroundImportMessage = ""
        vault.remove(Self.userBackgroundImageDataKey)
        vault.remove(Self.userBackgroundVideoDataKey)
        vault.remove(Self.userBackgroundVideoStorageIDKey)
        vault.remove(Self.userBackgroundVideoContentTypeKey)
        vault.remove(Self.userBackgroundVideoDurationKey)
    }

    @discardableResult
    func saveCurrentTheme(named rawName: String) -> SavedBrowserTheme {
        let trimmedName = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        let themeName = trimmedName.isEmpty ? "Saved Theme \(savedThemes.count + 1)" : trimmedName
        let theme = currentTheme(named: themeName)
        saveTheme(theme)
        return theme
    }

    func saveTheme(_ theme: SavedBrowserTheme) {
        savedThemes.removeAll { $0.id == theme.id || $0.name.caseInsensitiveCompare(theme.name) == .orderedSame }
        savedThemes.insert(theme, at: 0)
        if savedThemes.count > 12 {
            savedThemes = Array(savedThemes.prefix(12))
        }
        persistSavedThemes()
    }

    func applySavedTheme(_ savedTheme: SavedBrowserTheme) {
        for token in BrowserThemeToken.allCases {
            let value = savedTheme.colorHexByToken[token.rawValue] ?? token.defaultHex
            let gradientValue = savedTheme.gradientColorHexByToken?[token.rawValue] ?? token.defaultGradientHex
            colorHexByToken[token] = value
            gradientColorHexByToken[token] = gradientValue
            vault.save(value, forKey: Self.storageKey(for: token))
            vault.save(gradientValue, forKey: Self.gradientStorageKey(for: token))
        }

        gradientStartX = savedTheme.gradientStartX ?? 0.0
        gradientStartY = savedTheme.gradientStartY ?? 0.0
        gradientEndX = savedTheme.gradientEndX ?? 1.0
        gradientEndY = savedTheme.gradientEndY ?? 1.0
        if let gradientPositionsByToken = savedTheme.gradientPositionsByToken {
            gradientPositionByToken = Self.normalizedGradientPositions(
                gradientPositionsByToken,
                fallback: BrowserGradientPosition(
                    startX: gradientStartX,
                    startY: gradientStartY,
                    endX: gradientEndX,
                    endY: gradientEndY
                )
            )
        } else {
            syncLegacyGradientPositionToAllTokens()
        }
        gradientCirclesByToken = Self.normalizedGradientCircles(
            savedTheme.gradientCirclesByToken ?? [:],
            fallbackGradientHexByToken: gradientColorHexByToken
        )
        customColors = Self.normalizedCustomColors(savedTheme.customColors ?? [])
        isTabBarTransparencyEnabled = savedTheme.isTabBarTransparencyEnabled
        tabBarTransparency = savedTheme.tabBarTransparency
        userBackgroundImageData = savedTheme.userBackgroundImageData
        removeStoredUserBackgroundVideo()
        userBackgroundVideoData = savedTheme.userBackgroundVideoData
        if let userBackgroundVideoData = savedTheme.userBackgroundVideoData,
           let storageID = storeUserBackgroundVideo(userBackgroundVideoData) {
            userBackgroundVideoStorageID = storageID
            vault.save(storageID, forKey: Self.userBackgroundVideoStorageIDKey)
        } else {
            userBackgroundVideoStorageID = nil
            vault.remove(Self.userBackgroundVideoStorageIDKey)
        }
        userBackgroundVideoContentType = savedTheme.userBackgroundVideoContentType
        userBackgroundVideoDuration = savedTheme.userBackgroundVideoDuration
        isUserBackgroundEnabled = savedTheme.isUserBackgroundEnabled &&
            (savedTheme.userBackgroundImageData != nil || savedTheme.userBackgroundVideoData != nil)

        if let data = savedTheme.userBackgroundImageData {
            vault.save(data, forKey: Self.userBackgroundImageDataKey)
        } else {
            vault.remove(Self.userBackgroundImageDataKey)
        }
        vault.remove(Self.userBackgroundVideoDataKey)
        if let contentType = savedTheme.userBackgroundVideoContentType {
            vault.save(contentType, forKey: Self.userBackgroundVideoContentTypeKey)
        } else {
            vault.remove(Self.userBackgroundVideoContentTypeKey)
        }
        if let duration = savedTheme.userBackgroundVideoDuration {
            vault.save(duration, forKey: Self.userBackgroundVideoDurationKey)
        } else {
            vault.remove(Self.userBackgroundVideoDurationKey)
        }
    }

    func deleteSavedTheme(_ savedTheme: SavedBrowserTheme) {
        savedThemes.removeAll { $0.id == savedTheme.id }
        persistSavedThemes()
    }

    func exportThemeFile(_ savedTheme: SavedBrowserTheme) throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("GlideThemeExports", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let filename = "\(Self.safeThemeFilename(savedTheme.name)).glidetheme"
        let url = directory.appendingPathComponent(filename)
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(savedTheme)
        try data.write(to: url, options: [.atomic])
        return url
    }

    func importTheme(from url: URL) throws -> SavedBrowserTheme {
        let didAccess = url.startAccessingSecurityScopedResource()
        defer {
            if didAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }

        let data = try Data(contentsOf: url)
        var importedTheme = try JSONDecoder().decode(SavedBrowserTheme.self, from: data)
        importedTheme.id = UUID()
        importedTheme.savedAt = Date()
        saveTheme(importedTheme)
        applySavedTheme(importedTheme)
        return importedTheme
    }

    private func persistSavedThemes() {
        vault.save(savedThemes, forKey: Self.savedThemesKey)
    }

    private func setGradientCircles(_ circles: [BrowserThemeGradientCircle], for token: BrowserThemeToken) {
        var values = gradientCirclesByToken
        let normalized = Self.normalizedGradientCircleList(
            circles,
            fallbackHex: gradientHex(for: token)
        )
        values[token.rawValue] = normalized
        gradientCirclesByToken = values
        if let primaryHex = normalized.first?.colorHex {
            gradientColorHexByToken[token] = primaryHex
            vault.save(primaryHex, forKey: Self.gradientStorageKey(for: token))
        }
    }

    private func gradientLocation(for circle: BrowserThemeGradientCircle, token: BrowserThemeToken) -> Double {
        Self.projectedGradientLocation(
            x: circle.x,
            y: circle.y,
            position: gradientPosition(for: token)
        )
    }

    private func customGradientLocation(for color: BrowserCustomThemeColor) -> Double {
        Self.projectedGradientLocation(
            x: color.gradientX ?? color.location,
            y: color.gradientY ?? 0.5,
            position: BrowserGradientPosition(
                startX: gradientStartX,
                startY: gradientStartY,
                endX: gradientEndX,
                endY: gradientEndY
            )
        )
    }

    private func syncLegacyGradientPositionToAllTokens() {
        gradientPositionByToken = Self.normalizedGradientPositions(
            [:],
            fallback: BrowserGradientPosition(
                startX: gradientStartX,
                startY: gradientStartY,
                endX: gradientEndX,
                endY: gradientEndY
            )
        )
    }

    private func migrateLoadedThemeToEncryptedVault() {
        for token in BrowserThemeToken.allCases {
            vault.save(colorHexByToken[token] ?? token.defaultHex, forKey: Self.storageKey(for: token))
            vault.save(
                gradientColorHexByToken[token] ?? token.defaultGradientHex,
                forKey: Self.gradientStorageKey(for: token)
            )
        }
        vault.save(isTabBarTransparencyEnabled, forKey: Self.tabBarTransparencyEnabledKey)
        vault.save(tabBarTransparency, forKey: Self.tabBarTransparencyKey)
        vault.save(gradientStartX, forKey: Self.gradientStartXKey)
        vault.save(gradientStartY, forKey: Self.gradientStartYKey)
        vault.save(gradientEndX, forKey: Self.gradientEndXKey)
        vault.save(gradientEndY, forKey: Self.gradientEndYKey)
        vault.save(gradientPositionByToken, forKey: Self.gradientPositionByTokenKey)
        vault.save(gradientCirclesByToken, forKey: Self.gradientCirclesByTokenKey)
        vault.save(customColors, forKey: Self.customColorsKey)
        vault.save(isUserBackgroundEnabled, forKey: Self.userBackgroundEnabledKey)
        if let userBackgroundImageData = userBackgroundImageData {
            vault.save(userBackgroundImageData, forKey: Self.userBackgroundImageDataKey)
        } else {
            vault.remove(Self.userBackgroundImageDataKey)
        }
        if userBackgroundVideoData != nil, userBackgroundVideoStorageID == nil {
            persistLoadedUserBackgroundVideoToFile()
        }
        vault.remove(Self.userBackgroundVideoDataKey)
        if let userBackgroundVideoStorageID = userBackgroundVideoStorageID {
            vault.save(userBackgroundVideoStorageID, forKey: Self.userBackgroundVideoStorageIDKey)
        } else {
            vault.remove(Self.userBackgroundVideoStorageIDKey)
        }
        if let userBackgroundVideoContentType = userBackgroundVideoContentType {
            vault.save(userBackgroundVideoContentType, forKey: Self.userBackgroundVideoContentTypeKey)
        } else {
            vault.remove(Self.userBackgroundVideoContentTypeKey)
        }
        if let userBackgroundVideoDuration = userBackgroundVideoDuration {
            vault.save(userBackgroundVideoDuration, forKey: Self.userBackgroundVideoDurationKey)
        } else {
            vault.remove(Self.userBackgroundVideoDurationKey)
        }
        vault.save(savedThemes, forKey: Self.savedThemesKey)
    }

    private func loadOrMigrateStoredVideoBackground() {
        let legacyVideoData = userBackgroundVideoData

        if let storageID = userBackgroundVideoStorageID,
           let storedData = loadStoredUserBackgroundVideo(storageID: storageID) {
            userBackgroundVideoData = storedData
            vault.remove(Self.userBackgroundVideoDataKey)
            return
        }

        userBackgroundVideoStorageID = nil
        vault.remove(Self.userBackgroundVideoStorageIDKey)

        if legacyVideoData != nil {
            userBackgroundVideoData = legacyVideoData
            persistLoadedUserBackgroundVideoToFile()
        }
    }

    private func persistLoadedUserBackgroundVideoToFile() {
        guard let userBackgroundVideoData = userBackgroundVideoData,
              let storageID = storeUserBackgroundVideo(userBackgroundVideoData) else {
            return
        }

        userBackgroundVideoStorageID = storageID
        vault.save(storageID, forKey: Self.userBackgroundVideoStorageIDKey)
        vault.remove(Self.userBackgroundVideoDataKey)
    }

    private func storeUserBackgroundVideo(_ data: Data) -> String? {
        let storageID = UUID().uuidString

        do {
            let encryptedData = try vault.encryptData(data)
            let fileURL = try Self.storedBackgroundVideoURL(for: storageID)
            try encryptedData.write(to: fileURL, options: [.atomic])
            return storageID
        } catch {
            return nil
        }
    }

    private func loadStoredUserBackgroundVideo(storageID: String) -> Data? {
        do {
            let fileURL = try Self.storedBackgroundVideoURL(for: storageID)
            let encryptedData = try Data(contentsOf: fileURL)
            return try vault.decryptData(encryptedData)
        } catch {
            return nil
        }
    }

    private func removeStoredUserBackgroundVideo(storageID explicitStorageID: String? = nil) {
        let storageID = explicitStorageID ?? userBackgroundVideoStorageID
        if let storageID,
           let fileURL = try? Self.storedBackgroundVideoURL(for: storageID) {
            try? FileManager.default.removeItem(at: fileURL)
        }

        if explicitStorageID == nil || explicitStorageID == userBackgroundVideoStorageID {
            userBackgroundVideoStorageID = nil
            vault.remove(Self.userBackgroundVideoStorageIDKey)
        }
    }

    private static func storedBackgroundVideoURL(for storageID: String) throws -> URL {
        let directory = try backgroundVideoDirectory()
        return directory
            .appendingPathComponent(storageID)
            .appendingPathExtension(backgroundVideoFileExtension)
    }

    private static func backgroundVideoDirectory() throws -> URL {
        let fileManager = FileManager.default
        let root = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ??
            fileManager.temporaryDirectory
        let directory = root.appendingPathComponent(backgroundVideoDirectoryName, isDirectory: true)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private static func videoMetadata(from data: Data, contentTypeIdentifier: String?) -> (duration: Double, posterData: Data?)? {
        let url = temporaryVideoURL(contentTypeIdentifier: contentTypeIdentifier)

        do {
            try data.write(to: url, options: [.atomic])
            defer { try? FileManager.default.removeItem(at: url) }

            let asset = AVURLAsset(url: url)
            let duration = CMTimeGetSeconds(asset.duration)
            guard duration.isFinite, duration > 0 else { return nil }

            let generator = AVAssetImageGenerator(asset: asset)
            generator.appliesPreferredTrackTransform = true
            generator.maximumSize = CGSize(width: 900, height: 900)
            let time = CMTime(seconds: min(max(duration * 0.12, 0.2), 2.0), preferredTimescale: 600)
            let image = try? generator.copyCGImage(at: time, actualTime: nil)
            let posterData = image.map { UIImage(cgImage: $0).jpegData(compressionQuality: 0.82) } ?? nil
            return (duration, posterData)
        } catch {
            try? FileManager.default.removeItem(at: url)
            return nil
        }
    }

    private static func temporaryVideoURL(contentTypeIdentifier: String?) -> URL {
        let contentType = contentTypeIdentifier.flatMap { UTType($0) } ?? .mpeg4Movie
        let pathExtension = contentType.preferredFilenameExtension ?? "mp4"
        return FileManager.default.temporaryDirectory
            .appendingPathComponent("GlideBackground-\(UUID().uuidString)")
            .appendingPathExtension(pathExtension)
    }

    private static func storageKey(for token: BrowserThemeToken) -> String {
        "\(storagePrefix)\(token.rawValue)"
    }

    private static func gradientStorageKey(for token: BrowserThemeToken) -> String {
        "\(storagePrefix)\(token.rawValue).gradient"
    }

    private static func clampedUnit(_ value: Double) -> Double {
        guard value.isFinite else { return 0.0 }
        return min(max(value, 0.0), 1.0)
    }

    private static func projectedGradientLocation(
        x: Double,
        y: Double,
        position: BrowserGradientPosition
    ) -> Double {
        let deltaX = position.endX - position.startX
        let deltaY = position.endY - position.startY
        let lengthSquared = (deltaX * deltaX) + (deltaY * deltaY)
        guard lengthSquared > 0.0001 else {
            return clampedUnit((x + y) * 0.5)
        }
        let projected = (((x - position.startX) * deltaX) + ((y - position.startY) * deltaY)) / lengthSquared
        return clampedUnit(projected)
    }

    private static func normalizedCustomColors(_ colors: [BrowserCustomThemeColor]) -> [BrowserCustomThemeColor] {
        var seenIDs = Set<UUID>()
        return colors.compactMap { rawColor in
            guard seenIDs.contains(rawColor.id) == false else { return nil }
            seenIDs.insert(rawColor.id)
            let fallbackName = "Custom Color \(seenIDs.count)"
            let name = rawColor.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? fallbackName
                : rawColor.name.trimmingCharacters(in: .whitespacesAndNewlines)
            let colorHex = Color.isValidHex(rawColor.colorHex) ? rawColor.colorHex : "#7DD3FC"
            let gradientHex = Color.isValidHex(rawColor.gradientHex) ? rawColor.gradientHex : "#C4B5FD"
            return BrowserCustomThemeColor(
                id: rawColor.id,
                name: name,
                colorHex: colorHex,
                gradientHex: gradientHex,
                location: clampedUnit(rawColor.location),
                gradientX: clampedUnit(rawColor.gradientX ?? rawColor.location),
                gradientY: clampedUnit(rawColor.gradientY ?? 0.5),
                intensity: clampedUnit(rawColor.intensity ?? 0.72)
            )
        }
        .prefix(24)
        .map { $0 }
    }

    private static func normalizedGradientPositions(
        _ positions: [String: BrowserGradientPosition],
        fallback: BrowserGradientPosition
    ) -> [String: BrowserGradientPosition] {
        Dictionary(uniqueKeysWithValues: BrowserThemeToken.allCases.map { token in
            let rawPosition = positions[token.rawValue] ?? fallback
            return (
                token.rawValue,
                BrowserGradientPosition(
                    startX: clampedUnit(rawPosition.startX),
                    startY: clampedUnit(rawPosition.startY),
                    endX: clampedUnit(rawPosition.endX),
                    endY: clampedUnit(rawPosition.endY)
                )
            )
        })
    }

    private static func defaultGradientCircles(
        fallbackGradientHexByToken: [BrowserThemeToken: String]
    ) -> [String: [BrowserThemeGradientCircle]] {
        Dictionary(uniqueKeysWithValues: BrowserThemeToken.allCases.map { token in
            (
                token.rawValue,
                [
                    BrowserThemeGradientCircle(
                        colorHex: fallbackGradientHexByToken[token] ?? token.defaultGradientHex,
                        intensity: 0.72,
                        x: 0.5,
                        y: 0.5
                    )
                ]
            )
        })
    }

    private static func normalizedGradientCircles(
        _ circlesByToken: [String: [BrowserThemeGradientCircle]],
        fallbackGradientHexByToken: [BrowserThemeToken: String]
    ) -> [String: [BrowserThemeGradientCircle]] {
        Dictionary(uniqueKeysWithValues: BrowserThemeToken.allCases.map { token in
            (
                token.rawValue,
                normalizedGradientCircleList(
                    circlesByToken[token.rawValue] ?? [],
                    fallbackHex: fallbackGradientHexByToken[token] ?? token.defaultGradientHex
                )
            )
        })
    }

    private static func normalizedGradientCircleList(
        _ circles: [BrowserThemeGradientCircle],
        fallbackHex: String
    ) -> [BrowserThemeGradientCircle] {
        var seenIDs = Set<UUID>()
        let normalized = circles.compactMap { circle -> BrowserThemeGradientCircle? in
            guard seenIDs.contains(circle.id) == false else { return nil }
            seenIDs.insert(circle.id)
            return BrowserThemeGradientCircle(
                id: circle.id,
                colorHex: Color.isValidHex(circle.colorHex) ? circle.colorHex : fallbackHex,
                intensity: clampedUnit(circle.intensity),
                x: clampedUnit(circle.x),
                y: clampedUnit(circle.y)
            )
        }
        .prefix(8)
        .map { $0 }

        if normalized.isEmpty {
            return [BrowserThemeGradientCircle(colorHex: fallbackHex, intensity: 0.72)]
        }
        return normalized
    }

    private static func defaultGradientCircleCoordinate(for index: Int) -> (x: Double, y: Double) {
        let points: [(Double, Double)] = [
            (0.5, 0.5),
            (0.28, 0.36),
            (0.72, 0.42),
            (0.42, 0.72),
            (0.82, 0.24),
            (0.18, 0.76),
            (0.55, 0.26),
            (0.76, 0.74)
        ]
        return points[index % points.count]
    }

    private static func safeThemeFilename(_ filename: String) -> String {
        let trimmed = filename.trimmingCharacters(in: .whitespacesAndNewlines)
        let fallback = trimmed.isEmpty ? "Glide Theme" : trimmed
        let illegal = CharacterSet(charactersIn: "/\\?%*|\"<>:")
        return fallback
            .components(separatedBy: illegal)
            .joined(separator: "-")
    }
}

extension Color {
    static func isValidHex(_ hex: String) -> Bool {
        let sanitized = hex
            .trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
            .uppercased()
        guard [3, 6, 8].contains(sanitized.count) else { return false }
        return sanitized.allSatisfy { $0.isHexDigit }
    }

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
