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

extension UTType {
    static let glideTheme = UTType(exportedAs: "com.exlon360.glide.theme", conformingTo: .json)
}

@MainActor
final class BrowserTheme: ObservableObject {
    @Published private var colorHexByToken: [BrowserThemeToken: String]
    @Published private var gradientColorHexByToken: [BrowserThemeToken: String]
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
        self.colorHexByToken = values
        self.gradientColorHexByToken = gradientValues
        self.gradientStartX = Self.clampedUnit(vault.load(Double.self, forKey: Self.gradientStartXKey, default: 0.0))
        self.gradientStartY = Self.clampedUnit(vault.load(Double.self, forKey: Self.gradientStartYKey, default: 0.0))
        self.gradientEndX = Self.clampedUnit(vault.load(Double.self, forKey: Self.gradientEndXKey, default: 1.0))
        self.gradientEndY = Self.clampedUnit(vault.load(Double.self, forKey: Self.gradientEndYKey, default: 1.0))
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

    var tabBarOpacity: Double {
        isTabBarTransparencyEnabled ? max(0.0, 1.0 - tabBarTransparency) : 1.0
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

    func setColor(_ color: Color, for token: BrowserThemeToken) {
        let hex = color.hexString ?? token.defaultHex
        colorHexByToken[token] = hex
        vault.save(hex, forKey: Self.storageKey(for: token))
    }

    func setGradientColor(_ color: Color, for token: BrowserThemeToken) {
        let hex = color.hexString ?? token.defaultGradientHex
        gradientColorHexByToken[token] = hex
        vault.save(hex, forKey: Self.gradientStorageKey(for: token))
    }

    func updateGradientStart(x: Double, y: Double) {
        gradientStartX = x
        gradientStartY = y
    }

    func updateGradientEnd(x: Double, y: Double) {
        gradientEndX = x
        gradientEndY = y
    }

    func resetGradientMotion() {
        gradientStartX = 0.0
        gradientStartY = 0.0
        gradientEndX = 1.0
        gradientEndY = 1.0
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
