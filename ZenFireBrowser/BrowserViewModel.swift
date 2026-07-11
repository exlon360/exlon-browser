import Combine
import AudioToolbox
import AVFoundation
import CoreGraphics
import Foundation
import SwiftUI
import UIKit
import WebKit

enum BrowserChromePlacement: String, CaseIterable, Identifiable {
    case top
    case bottom
    case left
    case right
    case floating

    var id: String { rawValue }

    var title: String {
        switch self {
        case .top:
            return "Top"
        case .bottom:
            return "Bottom"
        case .left:
            return "Left"
        case .right:
            return "Right"
        case .floating:
            return "Floating"
        }
    }

    var symbolName: String {
        switch self {
        case .top:
            return "rectangle.topthird.inset.filled"
        case .bottom:
            return "rectangle.bottomthird.inset.filled"
        case .left:
            return "sidebar.left"
        case .right:
            return "sidebar.right"
        case .floating:
            return "rectangle.center.inset.filled"
        }
    }
}

enum BrowserDeviceExperienceOverride: String, CaseIterable, Identifiable {
    case automatic
    case phone
    case iPad

    var id: String { rawValue }

    var title: String {
        switch self {
        case .automatic:
            return "Auto"
        case .phone:
            return "Glide for iPhone"
        case .iPad:
            return "Glide for iPad"
        }
    }

    var symbolName: String {
        switch self {
        case .automatic:
            return "wand.and.stars"
        case .phone:
            return "iphone"
        case .iPad:
            return "ipad"
        }
    }
}

enum BrowserResolutionPreset: String, CaseIterable, Identifiable, Codable {
    case automatic
    case custom
    case phone390x844
    case phone430x932
    case tablet1024x768
    case desktop1366x900

    static let minimumSliderWidth = 320.0
    static let maximumSliderWidth = 1600.0
    static let defaultSliderWidth = 430.0
    static let sliderStep = 10.0
    static let minimumScreenScale = 0.55
    static let maximumScreenScale = 1.35
    static let defaultScreenScale = 1.0
    static let screenScaleStep = 0.01
    static let buttonCases: [BrowserResolutionPreset] = [
        .automatic,
        .phone390x844,
        .phone430x932,
        .tablet1024x768,
        .desktop1366x900
    ]

    var id: String { rawValue }

    var title: String {
        switch self {
        case .automatic:
            return "Auto"
        case .custom:
            return "Custom"
        case .phone390x844:
            return "390 x 844"
        case .phone430x932:
            return "430 x 932"
        case .tablet1024x768:
            return "1024 x 768"
        case .desktop1366x900:
            return "1366 x 900"
        }
    }

    var detail: String {
        switch self {
        case .automatic:
            return "Device resolution"
        case .custom:
            return "Screen scale"
        case .phone390x844:
            return "Phone layout"
        case .phone430x932:
            return "Large phone layout"
        case .tablet1024x768:
            return "Tablet layout"
        case .desktop1366x900:
            return "Desktop layout"
        }
    }

    var symbolName: String {
        switch self {
        case .automatic:
            return "wand.and.stars"
        case .custom:
            return "slider.horizontal.3"
        case .phone390x844, .phone430x932:
            return "iphone"
        case .tablet1024x768:
            return "ipad"
        case .desktop1366x900:
            return "desktopcomputer"
        }
    }

    var websiteDisplayMode: BrowserWebsiteDisplayMode {
        switch self {
        case .automatic, .custom:
            return .automatic
        case .phone390x844, .phone430x932:
            return .mobile
        case .tablet1024x768, .desktop1366x900:
            return .desktop
        }
    }

    var viewportWidth: Int? {
        switch self {
        case .automatic, .custom:
            return nil
        case .phone390x844:
            return 390
        case .phone430x932:
            return 430
        case .tablet1024x768:
            return 1024
        case .desktop1366x900:
            return 1366
        }
    }

    var viewportHeight: Int? {
        switch self {
        case .automatic, .custom:
            return nil
        case .phone390x844:
            return 844
        case .phone430x932:
            return 932
        case .tablet1024x768:
            return 768
        case .desktop1366x900:
            return 900
        }
    }

    var deviceExperienceOverride: BrowserDeviceExperienceOverride {
        switch self {
        case .automatic, .custom:
            return .automatic
        case .phone390x844, .phone430x932:
            return .phone
        case .tablet1024x768, .desktop1366x900:
            return .iPad
        }
    }

    static func clampedSliderWidth(_ value: Double) -> Double {
        guard value.isFinite else { return defaultSliderWidth }
        let rounded = (value / sliderStep).rounded() * sliderStep
        return min(max(rounded, minimumSliderWidth), maximumSliderWidth)
    }

    static func clampedScreenScale(_ value: Double) -> Double {
        guard value.isFinite else { return defaultScreenScale }
        let rounded = (value / screenScaleStep).rounded() * screenScaleStep
        return min(max(rounded, minimumScreenScale), maximumScreenScale)
    }

    static func screenScaleLabel(for value: Double) -> String {
        "\(Int((clampedScreenScale(value) * 100).rounded()))%"
    }

    var screenScale: Double {
        switch self {
        case .automatic, .custom:
            return Self.defaultScreenScale
        case .phone390x844, .phone430x932:
            return Self.defaultScreenScale
        case .tablet1024x768:
            return 0.78
        case .desktop1366x900:
            return 0.64
        }
    }

    static func sliderHeight(forWidth rawWidth: Double) -> Double {
        let width = clampedSliderWidth(rawWidth)
        let points: [(width: Double, height: Double)] = [
            (minimumSliderWidth, 693),
            (390, 844),
            (430, 932),
            (1024, 768),
            (1366, 900),
            (maximumSliderWidth, 1000)
        ]

        guard width > points[0].width else { return points[0].height }
        guard width < points[points.count - 1].width else { return points[points.count - 1].height }

        for index in 1..<points.count {
            let lower = points[index - 1]
            let upper = points[index]
            guard width <= upper.width else { continue }

            let progress = (width - lower.width) / (upper.width - lower.width)
            return lower.height + ((upper.height - lower.height) * progress)
        }

        return points[points.count - 1].height
    }
}

struct BrowserProfile: Identifiable, Codable, Equatable {
    var id: String
    var name: String
    var symbolName: String
    var tintHex: String
    var storageScope: String?
    var isPrimary: Bool

    var tintColor: Color {
        Color(hex: tintHex)
    }

    static let main = BrowserProfile(
        id: "main",
        name: "Main Glide",
        symbolName: "sparkles.rectangle.stack",
        tintHex: "#D6E2FF",
        storageScope: nil,
        isPrimary: true
    )

    static let second = BrowserProfile(
        id: "second",
        name: "Alt Glide",
        symbolName: "person.crop.circle.badge.plus",
        tintHex: "#C4B5FD",
        storageScope: "profile.second",
        isPrimary: false
    )

    static let defaults: [BrowserProfile] = [.main, .second]
}

@MainActor
final class BrowserProfileManager: ObservableObject {
    @Published var profiles: [BrowserProfile] {
        didSet {
            vault.save(profiles, forKey: Self.profilesKey)
        }
    }
    @Published private(set) var activeProfileID: String {
        didSet {
            vault.save(activeProfileID, forKey: Self.activeProfileKey)
        }
    }
    @Published var isSwitchingProfiles = false
    @Published var statusMessage = ""

    private let vault: SecureBrowserVault
    private static let profilesKey = "ZenFireBrowser.global.profiles"
    private static let activeProfileKey = "ZenFireBrowser.global.activeProfile"
    private static let cookiesKey = "ZenFireBrowser.profile.cookies"
    private static let maximumProfiles = 12
    private static let profileSymbols = [
        "sparkles.rectangle.stack",
        "person.crop.circle.badge.plus",
        "circle.hexagongrid.fill",
        "bolt.shield.fill",
        "paintpalette.fill",
        "moon.stars.fill",
        "globe.americas.fill",
        "theatermasks.fill"
    ]
    private static let profileTints = [
        "#D6E2FF",
        "#C4B5FD",
        "#7DD3FC",
        "#A7F3D0",
        "#FDE68A",
        "#F9A8D4",
        "#FDBA74",
        "#93C5FD"
    ]

    init(vault: SecureBrowserVault) {
        self.vault = vault
        let savedProfiles = vault.load([BrowserProfile].self, forKey: Self.profilesKey, default: BrowserProfile.defaults)
        let normalizedProfiles = Self.normalizedProfiles(savedProfiles)
        self.profiles = normalizedProfiles
        let savedActiveID = vault.load(String.self, forKey: Self.activeProfileKey, default: BrowserProfile.main.id)
        self.activeProfileID = normalizedProfiles.contains(where: { $0.id == savedActiveID }) ? savedActiveID : BrowserProfile.main.id
        vault.save(normalizedProfiles, forKey: Self.profilesKey)
        vault.save(activeProfileID, forKey: Self.activeProfileKey)
    }

    var activeProfile: BrowserProfile {
        profile(withID: activeProfileID) ?? BrowserProfile.main
    }

    var activeVault: SecureBrowserVault {
        vault(for: activeProfile)
    }

    func vault(for profile: BrowserProfile) -> SecureBrowserVault {
        vault.scoped(to: profile.storageScope)
    }

    func isActive(_ profile: BrowserProfile) -> Bool {
        profile.id == activeProfileID
    }

    func rename(_ profile: BrowserProfile, to rawName: String) {
        guard let index = profiles.firstIndex(where: { $0.id == profile.id }) else { return }
        let trimmed = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return }
        profiles[index].name = trimmed
    }

    func setTint(_ color: Color, for profile: BrowserProfile) {
        guard let index = profiles.firstIndex(where: { $0.id == profile.id }) else { return }
        profiles[index].tintHex = color.hexString ?? profiles[index].tintHex
    }

    @discardableResult
    func createProfile(named rawName: String = "") -> BrowserProfile {
        let index = profiles.count
        let uuid = UUID().uuidString.lowercased()
        let id = "glider-\(uuid)"
        let trimmed = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        let profile = BrowserProfile(
            id: id,
            name: trimmed.isEmpty ? "Glider \(index + 1)" : trimmed,
            symbolName: Self.profileSymbols[index % Self.profileSymbols.count],
            tintHex: Self.profileTints[index % Self.profileTints.count],
            storageScope: "profile.\(id)",
            isPrimary: false
        )
        profiles.append(profile)
        statusMessage = "Created \(profile.name)."
        return profile
    }

    func delete(_ profile: BrowserProfile) {
        guard profile.isPrimary == false,
              profile.id != activeProfileID,
              profiles.count > 1 else { return }
        profiles.removeAll { $0.id == profile.id }
        statusMessage = "Removed \(profile.name)."
    }

    func switchTo(_ profile: BrowserProfile) {
        guard profile.id != activeProfileID, isSwitchingProfiles == false else { return }
        let currentProfile = activeProfile
        isSwitchingProfiles = true
        statusMessage = "Saving \(currentProfile.name)..."

        Task { [weak self] in
            guard let self else { return }
            await Self.saveCurrentCookies(to: self.vault(for: currentProfile))
            await Self.clearWebKitProfileData()
            let targetDomains = Self.websiteBlacklist(in: self.vault(for: profile))
            BrowserWebsitePrivacyController.shared.update(blockedDomains: targetDomains)
            await Self.restoreCookies(from: self.vault(for: profile))
            await MainActor.run {
                self.activeProfileID = profile.id
                self.statusMessage = "\(profile.name) is active."
                self.isSwitchingProfiles = false
            }
        }
    }

    private func profile(withID id: String) -> BrowserProfile? {
        profiles.first { $0.id == id }
    }

    private static func normalizedProfiles(_ rawProfiles: [BrowserProfile]) -> [BrowserProfile] {
        var values = rawProfiles.isEmpty ? BrowserProfile.defaults : rawProfiles
        if values.contains(where: { $0.id == BrowserProfile.main.id }) == false {
            values.insert(.main, at: 0)
        }

        var seenIDs = Set<String>()
        var normalized: [BrowserProfile] = []
        for (index, rawProfile) in values.enumerated() {
            let fallbackID = index == 0 ? BrowserProfile.main.id : "glider-\(UUID().uuidString.lowercased())"
            let cleanedID = sanitizedProfileID(rawProfile.id.isEmpty ? fallbackID : rawProfile.id)
            guard seenIDs.contains(cleanedID) == false else { continue }
            seenIDs.insert(cleanedID)

            var profile = rawProfile
            profile.id = cleanedID
            profile.isPrimary = cleanedID == BrowserProfile.main.id
            profile.storageScope = profile.isPrimary ? nil : (profile.storageScope ?? "profile.\(cleanedID)")
            if profile.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                profile.name = profile.isPrimary ? BrowserProfile.main.name : "Glider \(normalized.count + 1)"
            }
            if profile.symbolName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                profile.symbolName = profileSymbols[normalized.count % profileSymbols.count]
            }
            if Color.isValidHex(profile.tintHex) == false {
                profile.tintHex = profileTints[normalized.count % profileTints.count]
            }
            normalized.append(profile)
            if normalized.count >= maximumProfiles { break }
        }

        if let mainIndex = normalized.firstIndex(where: \.isPrimary), mainIndex != 0 {
            let main = normalized.remove(at: mainIndex)
            normalized.insert(main, at: 0)
        }
        return normalized
    }

    private static func sanitizedProfileID(_ rawID: String) -> String {
        let cleaned = rawID
            .lowercased()
            .map { character -> Character in
                character.isLetter || character.isNumber || character == "-" ? character : "-"
            }
        let value = String(cleaned).trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        return value.isEmpty ? "glider-\(UUID().uuidString.lowercased())" : value
    }

    private static func saveCurrentCookies(to vault: SecureBrowserVault) async {
        let blockedDomains = websiteBlacklist(in: vault)
        let cookies = await allCookies()
            .filter { BrowserWebsitePrivacyPolicy.matchesCookieDomain($0.domain, blockedDomains: blockedDomains) == false }
            .map(StoredBrowserCookie.init(cookie:))
        vault.save(cookies, forKey: cookiesKey)
    }

    private static func restoreCookies(from vault: SecureBrowserVault) async {
        let blockedDomains = websiteBlacklist(in: vault)
        let cookies = vault.load([StoredBrowserCookie].self, forKey: cookiesKey, default: [])
        for storedCookie in cookies where BrowserWebsitePrivacyPolicy.matchesCookieDomain(
            storedCookie.domain,
            blockedDomains: blockedDomains
        ) == false {
            guard let cookie = storedCookie.httpCookie else { continue }
            await setCookie(cookie)
        }
    }

    private static func websiteBlacklist(in vault: SecureBrowserVault) -> [String] {
        BrowserWebsitePrivacyPolicy.normalizedDomains(
            vault.load([String].self, forKey: BrowserWebsitePrivacyPolicy.storageKey, default: [])
        )
    }

    private static func allCookies() async -> [HTTPCookie] {
        await withCheckedContinuation { continuation in
            WKWebsiteDataStore.default().httpCookieStore.getAllCookies { cookies in
                continuation.resume(returning: cookies)
            }
        }
    }

    private static func setCookie(_ cookie: HTTPCookie) async {
        await withCheckedContinuation { continuation in
            WKWebsiteDataStore.default().httpCookieStore.setCookie(cookie) {
                continuation.resume()
            }
        }
    }

    private static func clearWebKitProfileData() async {
        await withCheckedContinuation { continuation in
            let dataStore = WKWebsiteDataStore.default()
            dataStore.fetchDataRecords(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes()) { records in
                dataStore.removeData(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(), for: records) {
                    URLCache.shared.removeAllCachedResponses()
                    continuation.resume()
                }
            }
        }
    }
}

final class BrowserWebsitePrivacyController: NSObject, WKHTTPCookieStoreObserver {
    static let shared = BrowserWebsitePrivacyController()

    private let lock = NSLock()
    private var blockedDomains = Set<String>()
    private var isPurgingCookies = false
    private var shouldPurgeAgain = false

    private override init() {
        super.init()
        WKWebsiteDataStore.default().httpCookieStore.add(self)
    }

    func update(blockedDomains domains: [String]) {
        let normalized = Set(BrowserWebsitePrivacyPolicy.normalizedDomains(domains))
        lock.lock()
        blockedDomains = normalized
        lock.unlock()
        purgeBlockedCookies()
    }

    func purgeWebsiteData(for domains: [String]) {
        let normalized = BrowserWebsitePrivacyPolicy.normalizedDomains(domains)
        guard normalized.isEmpty == false else { return }
        purgeBlockedCookies()

        let dataStore = WKWebsiteDataStore.default()
        let dataTypes = WKWebsiteDataStore.allWebsiteDataTypes()
        dataStore.fetchDataRecords(ofTypes: dataTypes) { records in
            let blockedRecords = records.filter { record in
                BrowserWebsitePrivacyPolicy.matches(
                    host: record.displayName,
                    blockedDomains: normalized
                )
            }
            guard blockedRecords.isEmpty == false else { return }
            dataStore.removeData(ofTypes: dataTypes, for: blockedRecords) {}
        }
    }

    func cookiesDidChange(in cookieStore: WKHTTPCookieStore) {
        purgeBlockedCookies(in: cookieStore)
    }

    private func purgeBlockedCookies(in cookieStore: WKHTTPCookieStore = WKWebsiteDataStore.default().httpCookieStore) {
        lock.lock()
        guard blockedDomains.isEmpty == false else {
            lock.unlock()
            return
        }
        if isPurgingCookies {
            shouldPurgeAgain = true
            lock.unlock()
            return
        }
        isPurgingCookies = true
        let domains = blockedDomains
        lock.unlock()

        cookieStore.getAllCookies { [weak self] cookies in
            guard let self else { return }
            let cookiesToDelete = cookies.filter { cookie in
                BrowserWebsitePrivacyPolicy.matchesCookieDomain(
                    cookie.domain,
                    blockedDomains: domains
                )
            }
            let group = DispatchGroup()
            for cookie in cookiesToDelete {
                group.enter()
                cookieStore.delete(cookie) {
                    group.leave()
                }
            }
            group.notify(queue: .main) { [weak self] in
                self?.finishedCookiePurge(cookieStore: cookieStore)
            }
        }
    }

    private func finishedCookiePurge(cookieStore: WKHTTPCookieStore) {
        lock.lock()
        let repeatPurge = shouldPurgeAgain
        shouldPurgeAgain = false
        isPurgingCookies = false
        lock.unlock()
        if repeatPurge {
            purgeBlockedCookies(in: cookieStore)
        }
    }
}

private struct StoredBrowserCookie: Codable, Equatable {
    var name: String
    var value: String
    var domain: String
    var path: String
    var expiresDate: Date?
    var isSecure: Bool
    var isHTTPOnly: Bool

    init(cookie: HTTPCookie) {
        name = cookie.name
        value = cookie.value
        domain = cookie.domain
        path = cookie.path
        expiresDate = cookie.expiresDate
        isSecure = cookie.isSecure
        isHTTPOnly = cookie.isHTTPOnly
    }

    var httpCookie: HTTPCookie? {
        var properties: [HTTPCookiePropertyKey: Any] = [
            .name: name,
            .value: value,
            .domain: domain,
            .path: path
        ]
        if let expiresDate {
            properties[.expires] = expiresDate
        }
        if isSecure {
            properties[.secure] = "TRUE"
        }
        if isHTTPOnly {
            properties[HTTPCookiePropertyKey("HttpOnly")] = "TRUE"
        }
        return HTTPCookie(properties: properties)
    }
}

enum BrowserToolbarAction: String, CaseIterable, Identifiable {
    case back
    case forward
    case reload
    case tabFinder
    case tabFolders
    case closeAllTabs
    case compact
    case containedTabs
    case downloadCurrent
    case history
    case downloads
    case browserMusic
    case websiteMode
    case vpnCountry
    case passwordManager
    case placement
    case settings

    var id: String { rawValue }

    static var customizationCases: [BrowserToolbarAction] {
        allCases.filter { $0.isLeanBuildUtility == false }
    }

    var isLeanBuildUtility: Bool {
        switch self {
        case .browserMusic, .containedTabs, .vpnCountry:
            return true
        default:
            return false
        }
    }

    var title: String {
        switch self {
        case .back:
            return "Back"
        case .forward:
            return "Forward"
        case .reload:
            return "Reload / Stop"
        case .tabFinder:
            return "All Tabs"
        case .tabFolders:
            return "Tab Folders"
        case .closeAllTabs:
            return "Close All Tabs"
        case .compact:
            return "Compact Mode"
        case .containedTabs:
            return "Contained Tabs"
        case .downloadCurrent:
            return "Download Current Tab"
        case .history:
            return "History"
        case .downloads:
            return "Downloads"
        case .browserMusic:
            return "Browser Music"
        case .websiteMode:
            return "Website Mode"
        case .vpnCountry:
            return "Change Country"
        case .passwordManager:
            return "Passwords"
        case .placement:
            return "Chrome Placement"
        case .settings:
            return "Settings"
        }
    }

    var menuTitle: String {
        switch self {
        case .downloadCurrent:
            return "Download Current Tab"
        case .reload:
            return "Reload / Stop"
        default:
            return title
        }
    }

    var symbolName: String {
        switch self {
        case .back:
            return "chevron.left"
        case .forward:
            return "chevron.right"
        case .reload:
            return "arrow.clockwise"
        case .tabFinder:
            return "square.grid.2x2"
        case .tabFolders:
            return "folder"
        case .closeAllTabs:
            return "xmark.square"
        case .compact:
            return "arrow.down.right.and.arrow.up.left"
        case .containedTabs:
            return "rectangle.on.rectangle"
        case .downloadCurrent:
            return "arrow.down.doc"
        case .history:
            return "clock.arrow.circlepath"
        case .downloads:
            return "arrow.down.circle"
        case .browserMusic:
            return "music.note"
        case .websiteMode:
            return "desktopcomputer.and.arrow.down"
        case .vpnCountry:
            return "globe.americas"
        case .passwordManager:
            return "key.fill"
        case .placement:
            return "rectangle.split.2x1"
        case .settings:
            return "gearshape"
        }
    }
}

enum BrowserCustomIconSlot: String, CaseIterable, Identifiable {
    case brand
    case search
    case go
    case newTab
    case normalTab
    case privateTab
    case containedTabs
    case essentials
    case ai
    case more
    case back
    case forward
    case reload
    case tabFinder
    case tabFolders
    case closeAllTabs
    case compact
    case downloadCurrent
    case downloads
    case history
    case browserMusic
    case websiteMode
    case vpnCountry
    case passwordManager
    case placement
    case settings
    case extensions
    case privacy

    var id: String { rawValue }

    var title: String {
        switch self {
        case .brand:
            return "Brand"
        case .search:
            return "Search"
        case .go:
            return "Go"
        case .newTab:
            return "New Tab"
        case .normalTab:
            return "Normal Tab"
        case .privateTab:
            return "Private Tab"
        case .containedTabs:
            return "Contained Tabs"
        case .essentials:
            return "Essentials"
        case .ai:
            return "AI"
        case .more:
            return "More"
        case .back:
            return "Back"
        case .forward:
            return "Forward"
        case .reload:
            return "Reload"
        case .tabFinder:
            return "All Tabs"
        case .tabFolders:
            return "Tab Folders"
        case .closeAllTabs:
            return "Close All Tabs"
        case .compact:
            return "Compact"
        case .downloadCurrent:
            return "Download Current"
        case .downloads:
            return "Downloads"
        case .history:
            return "History"
        case .browserMusic:
            return "Browser Music"
        case .websiteMode:
            return "Website Mode"
        case .vpnCountry:
            return "Change Country"
        case .passwordManager:
            return "Passwords"
        case .placement:
            return "Placement"
        case .settings:
            return "Settings"
        case .extensions:
            return "Extensions"
        case .privacy:
            return "Privacy Shield"
        }
    }

    var defaultSymbol: String {
        switch self {
        case .brand:
            return "globe"
        case .search:
            return "magnifyingglass"
        case .go:
            return "arrow.up.circle.fill"
        case .newTab:
            return "plus.circle.fill"
        case .normalTab:
            return "globe"
        case .privateTab:
            return "theatermasks"
        case .containedTabs:
            return "rectangle.on.rectangle"
        case .essentials:
            return "sparkle"
        case .ai:
            return "sparkles"
        case .more:
            return "ellipsis"
        case .back:
            return "chevron.left"
        case .forward:
            return "chevron.right"
        case .reload:
            return "arrow.clockwise"
        case .tabFinder:
            return "square.grid.2x2"
        case .tabFolders:
            return "folder"
        case .closeAllTabs:
            return "xmark.square"
        case .compact:
            return "arrow.down.right.and.arrow.up.left"
        case .downloadCurrent:
            return "arrow.down.doc"
        case .downloads:
            return "arrow.down.circle"
        case .history:
            return "clock.arrow.circlepath"
        case .browserMusic:
            return "music.note"
        case .websiteMode:
            return "desktopcomputer.and.arrow.down"
        case .vpnCountry:
            return "globe.americas"
        case .passwordManager:
            return "key.fill"
        case .placement:
            return "rectangle.split.2x1"
        case .settings:
            return "gearshape"
        case .extensions:
            return "puzzlepiece"
        case .privacy:
            return "shield.checkered"
        }
    }
}

enum BrowserToolbarPlacement: String, CaseIterable, Identifiable {
    case top
    case center
    case bottom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .top:
            return "Top"
        case .center:
            return "Center"
        case .bottom:
            return "Bottom"
        }
    }

    var symbolName: String {
        switch self {
        case .top:
            return "rectangle.topthird.inset.filled"
        case .center:
            return "rectangle.center.inset.filled"
        case .bottom:
            return "rectangle.bottomthird.inset.filled"
        }
    }
}

enum BrowserToolLocation: String, CaseIterable, Identifiable {
    case toolbar
    case menu
    case hidden

    var id: String { rawValue }

    var title: String {
        switch self {
        case .toolbar:
            return "Toolbar"
        case .menu:
            return "3-Dot"
        case .hidden:
            return "Hidden"
        }
    }
}

enum BrowserPrivateModeAuthAction: Equatable {
    case enter
    case exit

    var title: String {
        switch self {
        case .enter:
            return "Unlock Private Mode"
        case .exit:
            return "Close Private Mode"
        }
    }

    var prompt: String {
        switch self {
        case .enter:
            return "Enter your Glide PIN to hide normal tabs and open Private Mode."
        case .exit:
            return "Close Private Mode and hide private tabs until Private Mode is unlocked again."
        }
    }

    var buttonTitle: String {
        switch self {
        case .enter:
            return "Enter Private Mode"
        case .exit:
            return "Close Private Mode"
        }
    }
}

enum BrowserAddOnLibrary: String, CaseIterable, Identifiable {
    case firefox
    case chrome
    case brave

    var id: String { rawValue }

    var title: String {
        switch self {
        case .firefox:
            return "Firefox Add-ons"
        case .chrome:
            return "Chrome Web Store"
        case .brave:
            return "Brave Extensions"
        }
    }

    var subtitle: String {
        switch self {
        case .firefox:
            return "Browse Mozilla's extension and theme library."
        case .chrome:
            return "Browse Chromium WebExtension packages."
        case .brave:
            return "Brave uses Chrome Web Store extensions."
        }
    }

    var symbolName: String {
        switch self {
        case .firefox:
            return "flame"
        case .chrome:
            return "circle.hexagongrid"
        case .brave:
            return "shield.lefthalf.filled"
        }
    }

    var url: URL {
        switch self {
        case .firefox:
            return URL(string: "https://addons.mozilla.org/firefox/")!
        case .chrome:
            return URL(string: "https://chromewebstore.google.com/category/extensions")!
        case .brave:
            return URL(string: "https://chromewebstore.google.com/category/extensions")!
        }
    }
}

extension BrowserToolbarAction {
    var customIconSlot: BrowserCustomIconSlot {
        switch self {
        case .back:
            return .back
        case .forward:
            return .forward
        case .reload:
            return .reload
        case .tabFinder:
            return .tabFinder
        case .tabFolders:
            return .tabFolders
        case .closeAllTabs:
            return .closeAllTabs
        case .compact:
            return .compact
        case .containedTabs:
            return .containedTabs
        case .downloadCurrent:
            return .downloadCurrent
        case .history:
            return .history
        case .downloads:
            return .downloads
        case .browserMusic:
            return .browserMusic
        case .websiteMode:
            return .websiteMode
        case .vpnCountry:
            return .vpnCountry
        case .passwordManager:
            return .passwordManager
        case .placement:
            return .placement
        case .settings:
            return .settings
        }
    }
}

final class BrowserMusicPlayer {
    private struct Parameters {
        var baseFrequency: Double
        var harmonyRatio: Double
        var shimmerFrequency: Double
        var pulseSpeed: Double
        var noiseLevel: Float
        var toneLevel: Float
        var shimmerLevel: Float
    }

    private let engine = AVAudioEngine()
    private var filePlayer: AVPlayer?
    private var fileEndObserver: NSObjectProtocol?
    private var currentFileURL: URL?
    private var sourceNode: AVAudioSourceNode?
    private var sampleTime = 0.0
    private var noiseSeed: UInt64 = 0x1234ABCD
    private var filteredNoise: Float = 0
    private var currentTrack: BrowserMusicTrack = .focus
    private var currentVolume: Float = 0.32
    private var parameters = Parameters(
        baseFrequency: 92,
        harmonyRatio: 1.5,
        shimmerFrequency: 440,
        pulseSpeed: 0.07,
        noiseLevel: 0.01,
        toneLevel: 0.18,
        shimmerLevel: 0.015
    )

    deinit {
        stop()
    }

    func update(isEnabled: Bool, track: BrowserMusicTrack, volume: Double, importedAudioURL: URL?) {
        currentVolume = Float(max(0, min(1, volume)))
        engine.mainMixerNode.outputVolume = currentVolume
        filePlayer?.volume = currentVolume

        if track == .imported, let importedAudioURL {
            stopEngineOnly()
            updateFilePlayer(url: importedAudioURL, isEnabled: isEnabled)
            return
        }

        stopFilePlayer()

        if track != currentTrack || sourceNode == nil {
            let wasRunning = engine.isRunning
            stopEngineOnly()
            let generatedTrack = track == .imported ? .focus : track
            currentTrack = generatedTrack
            parameters = Self.parameters(for: generatedTrack)
            configureSourceNode()
            if wasRunning || isEnabled {
                start()
            }
            return
        }

        if isEnabled {
            start()
        } else {
            stop()
        }
    }

    func stop() {
        stopFilePlayer()
        stopEngineOnly()
        try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
    }

    private func start() {
        if sourceNode == nil {
            configureSourceNode()
        }

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)

            if engine.isRunning == false {
                engine.prepare()
                try engine.start()
            }
        } catch {
            stopEngineOnly()
        }
    }

    private func stopEngineOnly() {
        if engine.isRunning {
            engine.stop()
        }

        if let sourceNode {
            engine.disconnectNodeOutput(sourceNode)
            engine.detach(sourceNode)
        }

        sourceNode = nil
    }

    private func updateFilePlayer(url: URL, isEnabled: Bool) {
        if currentFileURL != url || filePlayer == nil {
            configureFilePlayer(url: url)
        }

        guard isEnabled else {
            filePlayer?.pause()
            return
        }

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
            filePlayer?.play()
        } catch {
            stopFilePlayer()
        }
    }

    private func configureFilePlayer(url: URL) {
        stopFilePlayer()
        let item = AVPlayerItem(url: url)
        let player = AVPlayer(playerItem: item)
        player.volume = currentVolume
        player.actionAtItemEnd = .none
        fileEndObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            self?.filePlayer?.seek(to: .zero)
            self?.filePlayer?.play()
        }
        filePlayer = player
        currentFileURL = url
    }

    private func stopFilePlayer() {
        filePlayer?.pause()
        filePlayer = nil
        currentFileURL = nil
        if let fileEndObserver {
            NotificationCenter.default.removeObserver(fileEndObserver)
        }
        fileEndObserver = nil
    }

    private func configureSourceNode() {
        let sampleRate = 44_100.0
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2) else { return }

        sampleTime = 0
        filteredNoise = 0

        let node = AVAudioSourceNode(format: format) { [weak self] _, _, frameCount, audioBufferList -> OSStatus in
            guard let self else { return noErr }
            self.render(frameCount: frameCount, audioBufferList: audioBufferList, sampleRate: sampleRate)
            return noErr
        }

        engine.attach(node)
        engine.connect(node, to: engine.mainMixerNode, format: format)
        engine.mainMixerNode.outputVolume = currentVolume
        sourceNode = node
    }

    private func render(
        frameCount: AVAudioFrameCount,
        audioBufferList: UnsafeMutablePointer<AudioBufferList>,
        sampleRate: Double
    ) {
        guard let buffersOffset = MemoryLayout<AudioBufferList>.offset(of: \.mBuffers) else { return }
        let bufferCount = Int(audioBufferList.pointee.mNumberBuffers)
        let buffers = UnsafeMutableRawPointer(audioBufferList)
            .advanced(by: buffersOffset)
            .assumingMemoryBound(to: AudioBuffer.self)
        let frameTotal = Int(frameCount)
        let twoPi = Double.pi * 2

        for frame in 0..<frameTotal {
            let time = sampleTime / sampleRate
            let pulse = 0.55 + 0.45 * sin(twoPi * parameters.pulseSpeed * time)
            let fundamental = sin(twoPi * parameters.baseFrequency * time)
            let harmony = sin(twoPi * parameters.baseFrequency * parameters.harmonyRatio * time + 0.4)
            let sub = sin(twoPi * parameters.baseFrequency * 0.5 * time + 1.2)
            let shimmerMod = sin(twoPi * 0.045 * time) * 0.8
            let shimmer = sin(twoPi * parameters.shimmerFrequency * time + shimmerMod)

            noiseSeed = noiseSeed &* 2862933555777941757 &+ 3037000493
            let white = Float(Double(noiseSeed & 0xFFFF) / 32768.0 - 1.0)
            filteredNoise = filteredNoise * 0.985 + white * 0.015

            let tone = Float((fundamental * 0.52 + harmony * 0.32 + sub * 0.16) * pulse)
            let mixed = tone * parameters.toneLevel +
                Float(shimmer) * parameters.shimmerLevel +
                filteredNoise * parameters.noiseLevel
            let sample = max(-0.8, min(0.8, mixed))

            for bufferIndex in 0..<bufferCount {
                guard let data = buffers[bufferIndex].mData else { continue }
                let samples = data.bindMemory(to: Float.self, capacity: frameTotal)
                samples[frame] = bufferIndex == 0 ? sample : sample * 0.92
            }

            sampleTime += 1
        }
    }

    private static func parameters(for track: BrowserMusicTrack) -> Parameters {
        switch track {
        case .focus:
            return Parameters(
                baseFrequency: 96,
                harmonyRatio: 1.5,
                shimmerFrequency: 384,
                pulseSpeed: 0.08,
                noiseLevel: 0.006,
                toneLevel: 0.18,
                shimmerLevel: 0.012
            )
        case .rain:
            return Parameters(
                baseFrequency: 74,
                harmonyRatio: 1.33,
                shimmerFrequency: 296,
                pulseSpeed: 0.045,
                noiseLevel: 0.052,
                toneLevel: 0.09,
                shimmerLevel: 0.006
            )
        case .midnight:
            return Parameters(
                baseFrequency: 58,
                harmonyRatio: 2.0,
                shimmerFrequency: 232,
                pulseSpeed: 0.032,
                noiseLevel: 0.012,
                toneLevel: 0.22,
                shimmerLevel: 0.018
            )
        case .drift:
            return Parameters(
                baseFrequency: 112,
                harmonyRatio: 1.25,
                shimmerFrequency: 512,
                pulseSpeed: 0.055,
                noiseLevel: 0.01,
                toneLevel: 0.12,
                shimmerLevel: 0.026
            )
        case .imported:
            return parameters(for: .focus)
        }
    }
}

enum BrowserAllTabsLayout: String, CaseIterable, Identifiable {
    case grid
    case list

    var id: String { rawValue }
    var title: String { self == .grid ? "Grid" : "List" }
    var symbolName: String { self == .grid ? "square.grid.2x2" : "list.bullet" }
}

enum BrowserAllTabsDensity: String, CaseIterable, Identifiable {
    case compact
    case comfortable

    var id: String { rawValue }
    var title: String { self == .compact ? "Compact" : "Comfortable" }
}

enum BrowserAllTabsSortOrder: String, CaseIterable, Identifiable {
    case browserOrder
    case title
    case website

    var id: String { rawValue }

    var title: String {
        switch self {
        case .browserOrder: return "Browser order"
        case .title: return "Tab title"
        case .website: return "Website"
        }
    }
}

@MainActor
final class BrowserViewModel: ObservableObject {
    static let minimumForcedFPS = 15.0
    static let maximumFiniteForcedFPS = 240.0
    static let infiniteForcedFPSValue = 241.0
    static let minimumWebsiteResolutionScale = 0.86
    static let maximumWebsiteResolutionScale = 1.14
    static let currentFeatureUpdateVersion = 6
    static let defaultToolbarActionIDs = [
        BrowserToolbarAction.back.rawValue,
        BrowserToolbarAction.forward.rawValue,
        BrowserToolbarAction.reload.rawValue
    ]
    static let defaultMoreMenuActionIDs = Set([
        BrowserToolbarAction.compact.rawValue,
        BrowserToolbarAction.downloadCurrent.rawValue,
        BrowserToolbarAction.websiteMode.rawValue
    ])
    private static let firstToolbarUpgradeMenuActionIDs = Set([
        BrowserToolbarAction.tabFinder.rawValue,
        BrowserToolbarAction.tabFolders.rawValue,
        BrowserToolbarAction.closeAllTabs.rawValue,
        BrowserToolbarAction.compact.rawValue,
        BrowserToolbarAction.downloadCurrent.rawValue,
        BrowserToolbarAction.history.rawValue,
        BrowserToolbarAction.downloads.rawValue,
        BrowserToolbarAction.websiteMode.rawValue,
        BrowserToolbarAction.passwordManager.rawValue,
        BrowserToolbarAction.placement.rawValue,
        BrowserToolbarAction.settings.rawValue
    ])
    static var supportsDesktopZenMode: Bool {
        #if targetEnvironment(macCatalyst)
        return true
        #else
        return false
        #endif
    }

    @Published var tabs: [BrowserTab]
    @Published var selectedTabID: BrowserTab.ID?
    @Published var containedTabs: [BrowserTab] = []
    @Published var selectedContainedTabID: BrowserTab.ID?
    @Published var isContainedBrowserPresented = false
    @Published var chromePlacement: BrowserChromePlacement {
        didSet {
            vault.save(chromePlacement.rawValue, forKey: Self.StorageKey.chromePlacement)
        }
    }
    @Published var isFloatingSearchPresented = false
    @Published var floatingSearchText = ""
    @Published var shouldSelectFloatingSearchText = false
    @Published private(set) var isPhoneExperienceActive = UIDevice.current.userInterfaceIdiom == .phone
    @Published var isTabFinderPresented = false
    @Published var allTabsLayout: BrowserAllTabsLayout {
        didSet { vault.save(allTabsLayout.rawValue, forKey: Self.StorageKey.allTabsLayout) }
    }
    @Published var allTabsDensity: BrowserAllTabsDensity {
        didSet { vault.save(allTabsDensity.rawValue, forKey: Self.StorageKey.allTabsDensity) }
    }
    @Published var allTabsSortOrder: BrowserAllTabsSortOrder {
        didSet { vault.save(allTabsSortOrder.rawValue, forKey: Self.StorageKey.allTabsSortOrder) }
    }
    @Published var allTabsShowsContainedTabs: Bool {
        didSet { vault.save(allTabsShowsContainedTabs, forKey: Self.StorageKey.allTabsShowsContainedTabs) }
    }
    @Published var allTabsShowsPrivateSummary: Bool {
        didSet { vault.save(allTabsShowsPrivateSummary, forKey: Self.StorageKey.allTabsShowsPrivateSummary) }
    }
    @Published var isSettingsPresented = false
    @Published var isHistoryPresented = false
    @Published var isDownloadsPresented = false
    @Published var isTabFoldersPresented = false
    @Published var isVPNPresented = false
    @Published var isPasswordManagerPresented = false
    @Published var isAddOnsPresented = false
    @Published var isAIPanelPresented = false
    @Published var aiPromptText = ""
    @Published var aiStatusMessage = ""
    @Published var installedWebExtensions: [BrowserWebExtension] {
        didSet {
            vault.save(installedWebExtensions, forKey: Self.StorageKey.webExtensions)
            applyWebExtensionsToTabs(reloadAfterChange: true)
        }
    }
    @Published var webExtensionImportMessage = ""
    @Published var isAdvancedConfigPresented = false
    @Published var isCustomIconsPresented = false
    @Published var isDeveloperModeEnabled: Bool {
        didSet {
            vault.save(isDeveloperModeEnabled, forKey: Self.StorageKey.developerModeEnabled)
            if isDeveloperModeEnabled == false {
                isWebInspectorEnabled = false
                isDevWebKitEnabled = false
                deviceExperienceOverride = .automatic
            }
            applyDeveloperOptionsToTabs()
        }
    }
    @Published var isWebInspectorEnabled: Bool {
        didSet {
            vault.save(isWebInspectorEnabled, forKey: Self.StorageKey.webInspectorEnabled)
            applyDeveloperOptionsToTabs()
        }
    }
    @Published var isDevWebKitEnabled: Bool {
        didSet {
            vault.save(isDevWebKitEnabled, forKey: Self.StorageKey.devWebKitEnabled)
            if isDevWebKitEnabled {
                devCustomEngineIdentifier = "com.exlon360.glide.devwebkit"
            }
        }
    }
    @Published var devCustomEngineIdentifier: String {
        didSet {
            vault.save(devCustomEngineIdentifier, forKey: Self.StorageKey.devCustomEngineIdentifier)
        }
    }
    @Published var deviceExperienceOverride: BrowserDeviceExperienceOverride {
        didSet {
            if isDeveloperModeEnabled == false && deviceExperienceOverride != .automatic {
                deviceExperienceOverride = .automatic
                return
            }
            vault.save(deviceExperienceOverride.rawValue, forKey: Self.StorageKey.deviceExperienceOverride)
        }
    }
    @Published var devModeStatusMessage = ""
    @Published var isPrivateModeEnabled = false
    @Published var isPrivateModeAuthPresented = false
    @Published var isCloseAllTabsWarningPresented = false
    @Published var privateModeAuthAction: BrowserPrivateModeAuthAction = .enter
    @Published var privateModeAuthMessage = ""
    @Published var isWebFileImporterPresented = false
    @Published var allowsMultipleWebFileImport = false
    @Published var isLocalAIImporterPresented = false
    @Published var isTutorialPresented: Bool
    @Published var isFeatureUpdatePresented: Bool
    @Published var isDarkReaderEnabled: Bool
    @Published var darkReaderTheme: BrowserDarkReaderTheme {
        didSet {
            vault.save(darkReaderTheme.rawValue, forKey: Self.StorageKey.darkReaderTheme)
            for tab in tabs {
                tab.setDarkReaderTheme(darkReaderTheme)
            }
            for tab in containedTabs {
                tab.setDarkReaderTheme(darkReaderTheme)
            }
        }
    }
    @Published var isStylusCatppuccinEnabled: Bool {
        didSet {
            vault.save(isStylusCatppuccinEnabled, forKey: Self.StorageKey.stylusCatppuccinEnabled)
            for tab in tabs {
                tab.setStylusCatppuccinEnabled(isStylusCatppuccinEnabled)
            }
            for tab in containedTabs {
                tab.setStylusCatppuccinEnabled(isStylusCatppuccinEnabled)
            }
        }
    }
    @Published var isFPSForcerEnabled: Bool {
        didSet {
            vault.save(isFPSForcerEnabled, forKey: Self.StorageKey.fpsForcerEnabled)
            for tab in tabs {
                tab.setFPSForcerEnabled(isFPSForcerEnabled)
            }
            for tab in containedTabs {
                tab.setFPSForcerEnabled(isFPSForcerEnabled)
            }
        }
    }
    @Published var forcedFPS: Double {
        didSet {
            let clamped = Self.clampedForcedFPS(forcedFPS)
            if clamped != forcedFPS {
                forcedFPS = clamped
                return
            }
            vault.save(forcedFPS, forKey: Self.StorageKey.forcedFPS)
            for tab in tabs {
                tab.setForcedFPS(forcedFPS)
            }
            for tab in containedTabs {
                tab.setForcedFPS(forcedFPS)
            }
        }
    }
    @Published var websiteResolutionScale: Double {
        didSet {
            let clamped = Self.clampedWebsiteResolutionScale(websiteResolutionScale)
            if clamped != websiteResolutionScale {
                websiteResolutionScale = clamped
                return
            }
            vault.save(websiteResolutionScale, forKey: Self.StorageKey.websiteResolutionScale)
            for tab in tabs {
                tab.setWebsiteResolutionScale(websiteResolutionScale)
            }
            for tab in containedTabs {
                tab.setWebsiteResolutionScale(websiteResolutionScale)
            }
        }
    }
    @Published var browserResolutionPreset: BrowserResolutionPreset {
        didSet {
            vault.save(browserResolutionPreset.rawValue, forKey: Self.StorageKey.browserResolutionPreset)
        }
    }
    @Published var browserResolutionWidth: Double {
        didSet {
            let clamped = BrowserResolutionPreset.clampedScreenScale(browserResolutionWidth)
            if clamped != browserResolutionWidth {
                browserResolutionWidth = clamped
                return
            }
            vault.save(browserResolutionWidth, forKey: Self.StorageKey.browserResolutionWidth)
        }
    }
    @Published var isAdBlockerEnabled: Bool
    @Published var trackerBlockingLevel: BrowserTrackerBlockingLevel {
        didSet {
            vault.save(trackerBlockingLevel.rawValue, forKey: Self.StorageKey.trackerBlockingLevel)
            for tab in tabs {
                tab.setTrackerBlockingLevel(trackerBlockingLevel)
            }
            for tab in containedTabs {
                tab.setTrackerBlockingLevel(trackerBlockingLevel)
            }
        }
    }
    @Published var isScriptBlockingEnabled: Bool {
        didSet {
            vault.save(isScriptBlockingEnabled, forKey: Self.StorageKey.scriptBlockingEnabled)
            for tab in tabs {
                tab.setScriptBlockingEnabled(isScriptBlockingEnabled)
            }
            for tab in containedTabs {
                tab.setScriptBlockingEnabled(isScriptBlockingEnabled)
            }
        }
    }
    @Published var isHTTPSUpgradeEnabled: Bool {
        didSet {
            vault.save(isHTTPSUpgradeEnabled, forKey: Self.StorageKey.httpsUpgradeEnabled)
            for tab in tabs {
                tab.setHTTPSUpgradeEnabled(isHTTPSUpgradeEnabled)
            }
            for tab in containedTabs {
                tab.setHTTPSUpgradeEnabled(isHTTPSUpgradeEnabled)
            }
        }
    }
    @Published var isFingerprintProtectionEnabled: Bool {
        didSet {
            vault.save(isFingerprintProtectionEnabled, forKey: Self.StorageKey.fingerprintProtectionEnabled)
            for tab in tabs {
                tab.setFingerprintProtectionEnabled(isFingerprintProtectionEnabled)
            }
            for tab in containedTabs {
                tab.setFingerprintProtectionEnabled(isFingerprintProtectionEnabled)
            }
        }
    }
    @Published var isSocialBlockingEnabled: Bool {
        didSet {
            vault.save(isSocialBlockingEnabled, forKey: Self.StorageKey.socialBlockingEnabled)
            for tab in tabs {
                tab.setSocialBlockingEnabled(isSocialBlockingEnabled)
            }
            for tab in containedTabs {
                tab.setSocialBlockingEnabled(isSocialBlockingEnabled)
            }
        }
    }
    @Published var isPopupBlockingEnabled: Bool {
        didSet {
            vault.save(isPopupBlockingEnabled, forKey: Self.StorageKey.popupBlockingEnabled)
            for tab in tabs {
                tab.setPopupBlockingEnabled(isPopupBlockingEnabled)
            }
            for tab in containedTabs {
                tab.setPopupBlockingEnabled(isPopupBlockingEnabled)
            }
        }
    }
    @Published var isTrackingParameterStrippingEnabled: Bool {
        didSet {
            vault.save(isTrackingParameterStrippingEnabled, forKey: Self.StorageKey.trackingParameterStrippingEnabled)
            for tab in tabs {
                tab.setTrackingParameterStrippingEnabled(isTrackingParameterStrippingEnabled)
            }
            for tab in containedTabs {
                tab.setTrackingParameterStrippingEnabled(isTrackingParameterStrippingEnabled)
            }
        }
    }
    @Published var isBounceTrackingProtectionEnabled: Bool {
        didSet {
            vault.save(isBounceTrackingProtectionEnabled, forKey: Self.StorageKey.bounceTrackingProtectionEnabled)
            for tab in tabs {
                tab.setBounceTrackingProtectionEnabled(isBounceTrackingProtectionEnabled)
            }
            for tab in containedTabs {
                tab.setBounceTrackingProtectionEnabled(isBounceTrackingProtectionEnabled)
            }
        }
    }
    @Published var isWebRTCProtectionEnabled: Bool {
        didSet {
            vault.save(isWebRTCProtectionEnabled, forKey: Self.StorageKey.webRTCProtectionEnabled)
            for tab in tabs {
                tab.setWebRTCProtectionEnabled(isWebRTCProtectionEnabled)
            }
            for tab in containedTabs {
                tab.setWebRTCProtectionEnabled(isWebRTCProtectionEnabled)
            }
        }
    }
    @Published var isRegionTricksEnabled: Bool {
        didSet {
            vault.save(isRegionTricksEnabled, forKey: Self.StorageKey.regionTricksEnabled)
            applyRegionTricksToTabs()
        }
    }
    @Published var regionTrickProfile: BrowserRegionTrickProfile {
        didSet {
            vault.save(regionTrickProfile.rawValue, forKey: Self.StorageKey.regionTrickProfile)
            applyRegionTricksToTabs()
        }
    }
    @Published var isBrowserMusicEnabled: Bool {
        didSet {
            vault.save(isBrowserMusicEnabled, forKey: Self.StorageKey.browserMusicEnabled)
            updateBrowserMusicPlayer()
        }
    }
    @Published var browserMusicTrack: BrowserMusicTrack {
        didSet {
            vault.save(browserMusicTrack.rawValue, forKey: Self.StorageKey.browserMusicTrack)
            updateBrowserMusicPlayer()
        }
    }
    @Published var browserMusicVolume: Double {
        didSet {
            let clamped = Self.clampedUnit(browserMusicVolume)
            if clamped != browserMusicVolume {
                browserMusicVolume = clamped
                return
            }
            vault.save(browserMusicVolume, forKey: Self.StorageKey.browserMusicVolume)
            updateBrowserMusicPlayer()
        }
    }
    @Published var importedBrowserMusicFilename: String {
        didSet {
            vault.save(importedBrowserMusicFilename, forKey: Self.StorageKey.importedBrowserMusicFilename)
            updateBrowserMusicPlayer()
        }
    }
    @Published var browserMusicImportMessage = ""
    @Published var newTabOpensSearch: Bool {
        didSet {
            vault.save(newTabOpensSearch, forKey: Self.StorageKey.newTabOpensSearch)
        }
    }
    @Published var autoCompactAfterSearchOnPhone: Bool {
        didSet {
            vault.save(autoCompactAfterSearchOnPhone, forKey: Self.StorageKey.autoCompactAfterSearchOnPhone)
        }
    }
    @Published var compactModeHidesTopSearchBar: Bool {
        didSet {
            vault.save(compactModeHidesTopSearchBar, forKey: Self.StorageKey.compactModeHidesTopSearchBar)
            if isCompactModeActive && compactModeHidesTopSearchBar {
                isTopSearchBarEnabled = false
            }
        }
    }
    @Published var compactModeRevealsTopSearchBar: Bool {
        didSet {
            vault.save(compactModeRevealsTopSearchBar, forKey: Self.StorageKey.compactModeRevealsTopSearchBar)
        }
    }
    @Published var isTopSearchBarEnabled: Bool {
        didSet {
            vault.save(isTopSearchBarEnabled, forKey: Self.StorageKey.topSearchBarEnabled)
        }
    }
    @Published var topSearchBarPlacement: BrowserToolbarPlacement {
        didSet {
            vault.save(topSearchBarPlacement.rawValue, forKey: Self.StorageKey.topSearchBarPlacement)
        }
    }
    @Published var topSearchBarPositionX: Double {
        didSet {
            let clamped = Self.clampedUnit(topSearchBarPositionX)
            if clamped != topSearchBarPositionX {
                topSearchBarPositionX = clamped
                return
            }
            vault.save(topSearchBarPositionX, forKey: Self.StorageKey.topSearchBarPositionX)
        }
    }
    @Published var topSearchBarPositionY: Double {
        didSet {
            let clamped = Self.clampedUnit(topSearchBarPositionY)
            if clamped != topSearchBarPositionY {
                topSearchBarPositionY = clamped
                return
            }
            vault.save(topSearchBarPositionY, forKey: Self.StorageKey.topSearchBarPositionY)
        }
    }
    @Published var isTopSearchBarMoveMode = false
    @Published var topSearchBarDraftX = 0.5
    @Published var topSearchBarDraftY = 0.0
    @Published var areSideTabsCollapsed: Bool {
        didSet {
            vault.save(areSideTabsCollapsed, forKey: Self.StorageKey.sideTabsCollapsed)
        }
    }
    @Published var isDesktopZenModeEnabled: Bool {
        didSet {
            vault.save(isDesktopZenModeEnabled, forKey: Self.StorageKey.desktopZenModeEnabled)
            if isDesktopZenModeEnabled {
                isTopSearchBarEnabled = true
                arePageControlsCollapsed = false
            }
        }
    }
    @Published var arePageControlsCollapsed: Bool {
        didSet {
            vault.save(arePageControlsCollapsed, forKey: Self.StorageKey.pageControlsCollapsed)
        }
    }
    @Published var compactModeHidesQuickControls: Bool {
        didSet {
            vault.save(compactModeHidesQuickControls, forKey: Self.StorageKey.compactModeHidesQuickControls)
            if isCompactModeActive {
                arePageControlsCollapsed = compactModeHidesQuickControls
            }
        }
    }
    @Published var isTwoFingerDoubleTapCompactEnabledOnIPad: Bool {
        didSet {
            vault.save(isTwoFingerDoubleTapCompactEnabledOnIPad, forKey: Self.StorageKey.twoFingerDoubleTapCompactOnIPad)
        }
    }
    @Published var sideChromeWidthFraction: Double {
        didSet {
            let clamped = Self.clampedSideChromeWidthFraction(sideChromeWidthFraction)
            if clamped != sideChromeWidthFraction {
                sideChromeWidthFraction = clamped
                return
            }
            vault.save(sideChromeWidthFraction, forKey: Self.StorageKey.sideChromeWidthFraction)
        }
    }
    @Published var pageControlsOffsetX: Double {
        didSet {
            let clamped = Self.clampedUnit(pageControlsOffsetX)
            if clamped != pageControlsOffsetX {
                pageControlsOffsetX = clamped
                return
            }
            vault.save(pageControlsOffsetX, forKey: Self.StorageKey.pageControlsOffsetX)
        }
    }
    @Published var pageControlsOffsetY: Double {
        didSet {
            let clamped = Self.clampedUnit(pageControlsOffsetY)
            if clamped != pageControlsOffsetY {
                pageControlsOffsetY = clamped
                return
            }
            vault.save(pageControlsOffsetY, forKey: Self.StorageKey.pageControlsOffsetY)
        }
    }
    @Published var isChromeWidthResizeMode = false
    @Published var isPageControlsMoveMode = false
    @Published var searchEngine: BrowserSearchEngine {
        didSet {
            vault.save(searchEngine.rawValue, forKey: Self.StorageKey.searchEngine)
        }
    }
    @Published var customSearchTemplate: String {
        didSet {
            vault.save(customSearchTemplate, forKey: Self.StorageKey.customSearchTemplate)
        }
    }
    @Published private(set) var bangs: [BrowserBang]
    @Published var bangStatusMessage = ""
    @Published var moreMenuActionIDs: Set<String> {
        didSet {
            vault.save(moreMenuActionIDs, forKey: Self.StorageKey.moreMenuActionIDs)
        }
    }
    @Published var toolbarActionIDs: [String] {
        didSet {
            vault.save(toolbarActionIDs, forKey: Self.StorageKey.toolbarActionIDs)
        }
    }
    @Published var customIconNames: [String: String] {
        didSet {
            vault.save(customIconNames, forKey: Self.StorageKey.customIconNames)
        }
    }
    @Published private(set) var customIconColorHexBySlot: [String: String] {
        didSet {
            vault.save(customIconColorHexBySlot, forKey: Self.StorageKey.customIconColorHexBySlot)
        }
    }
    @Published var history: [BrowserHistoryItem]
    @Published var essentials: [BrowserEssentialItem]
    @Published private(set) var websiteBlacklist: [String]
    @Published var websiteBlacklistStatusMessage = ""
    @Published private(set) var websiteProtectionWhitelist: [String]
    @Published var websiteProtectionWhitelistStatusMessage = ""
    @Published var tabFolders: [BrowserTabFolder] {
        didSet {
            saveTabFolders()
        }
    }
    @Published var collapsedTabFolderIDs: Set<UUID> {
        didSet {
            vault.save(collapsedTabFolderIDs, forKey: Self.StorageKey.collapsedTabFolderIDs)
        }
    }
    @Published var downloads: [BrowserDownloadItem]
    @Published var passwordEntries: [BrowserPasswordEntry] {
        didSet {
            savePasswordEntries()
        }
    }
    @Published var websiteDisplayMode: BrowserWebsiteDisplayMode {
        didSet {
            vault.save(websiteDisplayMode.rawValue, forKey: Self.StorageKey.websiteDisplayMode)
            for tab in tabs {
                tab.setWebsiteDisplayMode(websiteDisplayMode)
            }
            for tab in containedTabs {
                tab.setWebsiteDisplayMode(websiteDisplayMode)
            }
        }
    }
    @Published var localAIName: String {
        didSet {
            vault.save(localAIName, forKey: Self.StorageKey.localAIName)
        }
    }
    @Published var localAIURLText: String {
        didSet {
            vault.save(localAIURLText, forKey: Self.StorageKey.localAIURLText)
        }
    }
    @Published var vpnProfile: CustomVPNProfile {
        didSet {
            persistVPNProfile()
        }
    }
    @Published var selectedVPNCountry: String {
        didSet {
            vault.save(selectedVPNCountry, forKey: Self.StorageKey.selectedVPNCountry)
        }
    }
    @Published var vpnStatusMessage = "Custom VPN profile not configured."
    @Published var privacyStatusMessage = ""
    @Published var downloadStatusMessage = ""
    @Published var passwordStatusMessage = ""
    @Published var dismissedDownloadShelfID: UUID?
    @Published private var customIconImageDataBySlot: [String: Data] {
        didSet {
            vault.save(customIconImageDataBySlot, forKey: Self.StorageKey.customIconImageDataBySlot)
        }
    }
    private let vault: SecureBrowserVault
    private let browserMusicPlayer = BrowserMusicPlayer()
    private var pendingWebFileImportCompletion: (([URL]?) -> Void)?
    private var lastTwoFingerSwipeAt = Date.distantPast
    private var lastTwoFingerDoubleTapAt = Date.distantPast
    private var lastThreeFingerSwipeAt = Date.distantPast
    private var isApplyingBrowserResolutionPreset = false

    init(vault: SecureBrowserVault) {
        self.vault = vault
        let darkReaderEnabled = vault.load(Bool.self, forKey: Self.StorageKey.darkReaderEnabled, default: false)
        let savedDarkReaderTheme = BrowserDarkReaderTheme(
            rawValue: vault.load(String.self, forKey: Self.StorageKey.darkReaderTheme, default: "")
        ) ?? .zenCopy
        let stylusCatppuccinEnabled = vault.load(Bool.self, forKey: Self.StorageKey.stylusCatppuccinEnabled, default: false)
        let fpsForcerEnabled = vault.load(Bool.self, forKey: Self.StorageKey.fpsForcerEnabled, default: false)
        let savedForcedFPS = Self.clampedForcedFPS(
            vault.load(Double.self, forKey: Self.StorageKey.forcedFPS, default: 60)
        )
        let savedWebsiteResolutionScale = Self.clampedWebsiteResolutionScale(
            vault.load(Double.self, forKey: Self.StorageKey.websiteResolutionScale, default: 1.0)
        )
        let savedShieldEngineVersion = vault.load(Int.self, forKey: Self.StorageKey.shieldEngineVersion, default: 0)
        let shouldUpgradeShields = savedShieldEngineVersion < BrowserContentBlocker.engineVersion
        if shouldUpgradeShields {
            vault.save(true, forKey: Self.StorageKey.adBlockerEnabled)
            vault.save(BrowserTrackerBlockingLevel.aggressive.rawValue, forKey: Self.StorageKey.trackerBlockingLevel)
            vault.save(BrowserContentBlocker.engineVersion, forKey: Self.StorageKey.shieldEngineVersion)
            SecureBrowserVault.prepareLaunchPrivacy()
        }
        let adBlockerEnabled = shouldUpgradeShields ? true : vault.load(Bool.self, forKey: Self.StorageKey.adBlockerEnabled, default: true)
        let savedTrackerBlockingLevel: BrowserTrackerBlockingLevel = shouldUpgradeShields ? .aggressive : (
            BrowserTrackerBlockingLevel(
                rawValue: vault.load(String.self, forKey: Self.StorageKey.trackerBlockingLevel, default: "")
            ) ?? .aggressive
        )
        let scriptBlockingEnabled = vault.load(Bool.self, forKey: Self.StorageKey.scriptBlockingEnabled, default: false)
        let httpsUpgradeEnabled = vault.load(Bool.self, forKey: Self.StorageKey.httpsUpgradeEnabled, default: true)
        let fingerprintProtectionEnabled = vault.load(Bool.self, forKey: Self.StorageKey.fingerprintProtectionEnabled, default: true)
        let socialBlockingEnabled = vault.load(Bool.self, forKey: Self.StorageKey.socialBlockingEnabled, default: true)
        let popupBlockingEnabled = vault.load(Bool.self, forKey: Self.StorageKey.popupBlockingEnabled, default: true)
        let trackingParameterStrippingEnabled = vault.load(Bool.self, forKey: Self.StorageKey.trackingParameterStrippingEnabled, default: true)
        let bounceTrackingProtectionEnabled = vault.load(Bool.self, forKey: Self.StorageKey.bounceTrackingProtectionEnabled, default: true)
        let webRTCProtectionEnabled = vault.load(Bool.self, forKey: Self.StorageKey.webRTCProtectionEnabled, default: true)
        let regionTricksEnabled = vault.load(Bool.self, forKey: Self.StorageKey.regionTricksEnabled, default: false)
        let savedRegionTrickProfile = BrowserRegionTrickProfile(
            rawValue: vault.load(String.self, forKey: Self.StorageKey.regionTrickProfile, default: "")
        ) ?? .unitedStates
        let savedLeanProfileVersion = vault.load(Int.self, forKey: Self.StorageKey.leanProfileVersion, default: 0)
        let shouldApplyLeanProfile = savedLeanProfileVersion < 2
        let placement = shouldApplyLeanProfile
            ? BrowserChromePlacement.floating
            : (BrowserChromePlacement(rawValue: vault.load(String.self, forKey: Self.StorageKey.chromePlacement, default: "")) ?? .left)
        let selectedSearchEngine = BrowserSearchEngine(rawValue: vault.load(String.self, forKey: Self.StorageKey.searchEngine, default: "")) ?? .duckDuckGo
        let savedCustomSearch = vault.load(String.self, forKey: Self.StorageKey.customSearchTemplate, default: BrowserSearchEngine.defaultCustomTemplate)
        let savedBangs = BrowserBang.normalized(
            vault.load([BrowserBang].self, forKey: Self.StorageKey.bangs, default: BrowserBang.defaults)
        )
        let savedAllTabsLayout = BrowserAllTabsLayout(
            rawValue: vault.load(String.self, forKey: Self.StorageKey.allTabsLayout, default: "")
        ) ?? .grid
        let savedAllTabsDensity = BrowserAllTabsDensity(
            rawValue: vault.load(String.self, forKey: Self.StorageKey.allTabsDensity, default: "")
        ) ?? .comfortable
        let savedAllTabsSortOrder = BrowserAllTabsSortOrder(
            rawValue: vault.load(String.self, forKey: Self.StorageKey.allTabsSortOrder, default: "")
        ) ?? .browserOrder
        let savedToolbarUpgradeVersion = vault.load(Int.self, forKey: Self.StorageKey.toolbarUpgradeVersion, default: 0)
        let shouldApplyToolbarUpgrade = savedToolbarUpgradeVersion < 1
        let storedToolbarActionIDs = vault.load(
            [String].self,
            forKey: Self.StorageKey.toolbarActionIDs,
            default: Self.defaultToolbarActionIDs
        )
        let savedToolbarActionIDs = shouldApplyToolbarUpgrade
            ? Self.defaultToolbarActionIDs
            : Self.normalizedToolbarActionIDs(storedToolbarActionIDs)
        let storedMoreMenuActionIDs = vault.load(Set<String>.self, forKey: Self.StorageKey.moreMenuActionIDs, default: [])
        let upgradedMoreMenuActionIDs = shouldApplyToolbarUpgrade
            ? storedMoreMenuActionIDs.union(Self.defaultMoreMenuActionIDs)
            : (savedToolbarUpgradeVersion == 1
                ? storedMoreMenuActionIDs
                    .subtracting(Self.firstToolbarUpgradeMenuActionIDs)
                    .union(Self.defaultMoreMenuActionIDs)
                : storedMoreMenuActionIDs)
        let savedMoreMenuActionIDs = upgradedMoreMenuActionIDs
            .filter { BrowserToolbarAction(rawValue: $0)?.isLeanBuildUtility == false }
            .subtracting(savedToolbarActionIDs)
        let savedCustomIconNames = vault.load([String: String].self, forKey: Self.StorageKey.customIconNames, default: [:])
        let savedCustomIconColors = vault.load(
            [String: String].self,
            forKey: Self.StorageKey.customIconColorHexBySlot,
            default: [:]
        )
        let savedCustomIconImageData = vault.load([String: Data].self, forKey: Self.StorageKey.customIconImageDataBySlot, default: [:])
        let savedWebsiteBlacklist = BrowserWebsitePrivacyPolicy.normalizedDomains(
            vault.load([String].self, forKey: BrowserWebsitePrivacyPolicy.storageKey, default: [])
        )
        let savedWebsiteProtectionWhitelist = BrowserWebsitePrivacyPolicy.normalizedDomains(
            vault.load(
                [String].self,
                forKey: BrowserWebsitePrivacyPolicy.protectionWhitelistStorageKey,
                default: []
            )
        ).filter { domain in
            BrowserWebsitePrivacyPolicy.matches(host: domain, blockedDomains: savedWebsiteBlacklist) == false
        }
        let developerModeEnabled = vault.load(Bool.self, forKey: Self.StorageKey.developerModeEnabled, default: false)
        let webInspectorEnabled = developerModeEnabled && vault.load(Bool.self, forKey: Self.StorageKey.webInspectorEnabled, default: false)
        let devWebKitEnabled = developerModeEnabled && vault.load(Bool.self, forKey: Self.StorageKey.devWebKitEnabled, default: false)
        let savedDevCustomEngineIdentifier = vault.load(String.self, forKey: Self.StorageKey.devCustomEngineIdentifier, default: "")
        let savedDeviceExperienceOverride = developerModeEnabled ? (
            BrowserDeviceExperienceOverride(
                rawValue: vault.load(String.self, forKey: Self.StorageKey.deviceExperienceOverride, default: "")
            ) ?? .automatic
        ) : .automatic
        let savedHistory = Self.loadHistory(vault: vault).filter { item in
            BrowserWebsitePrivacyPolicy.matches(
                host: item.url?.host,
                blockedDomains: savedWebsiteBlacklist
            ) == false
        }
        let savedEssentials = Self.loadEssentials(vault: vault)
        let savedTabFolders = Self.loadTabFolders(vault: vault)
        let savedCollapsedTabFolderIDs = vault.load(
            Set<UUID>.self,
            forKey: Self.StorageKey.collapsedTabFolderIDs,
            default: []
        ).intersection(Set(savedTabFolders.map(\.id)))
        let savedDownloads = Self.loadDownloads(vault: vault)
        let savedPasswordEntries = Self.loadPasswordEntries(vault: vault)
        let savedVPNProfile = Self.loadVPNProfile(vault: vault)
        let savedWebExtensions = vault.load(
            [BrowserWebExtension].self,
            forKey: Self.StorageKey.webExtensions,
            default: []
        )
        let savedBrowserResolutionPreset = BrowserResolutionPreset(
            rawValue: vault.load(String.self, forKey: Self.StorageKey.browserResolutionPreset, default: "")
        ) ?? .automatic
        let rawBrowserResolutionScale = vault.load(
            Double.self,
            forKey: Self.StorageKey.browserResolutionWidth,
            default: savedBrowserResolutionPreset.screenScale
        )
        let savedBrowserResolutionWidth = BrowserResolutionPreset.clampedScreenScale(
            rawBrowserResolutionScale > 10 ? savedBrowserResolutionPreset.screenScale : rawBrowserResolutionScale
        )
        let savedWebsiteDisplayModeValue = BrowserWebsiteDisplayMode(
            rawValue: vault.load(String.self, forKey: Self.StorageKey.websiteDisplayMode, default: "")
        ) ?? .automatic
        let savedWebsiteDisplayMode = savedBrowserResolutionPreset == .automatic
            ? savedWebsiteDisplayModeValue
            : Self.websiteDisplayMode(forBrowserResolution: savedBrowserResolutionPreset, width: savedBrowserResolutionWidth)
        let hasCompletedTutorial = vault.load(Bool.self, forKey: Self.StorageKey.hasCompletedTutorial, default: false)
        let savedFeatureUpdateVersion = vault.load(Int.self, forKey: Self.StorageKey.featureUpdateVersion, default: 0)
        let savedVPNCountry = vault.load(String.self, forKey: Self.StorageKey.selectedVPNCountry, default: savedVPNProfile.countryName)
        let savedBrowserMusicTrack = BrowserMusicTrack(
            rawValue: vault.load(String.self, forKey: Self.StorageKey.browserMusicTrack, default: "")
        ) ?? .focus
        let restoredTabs = Self.loadTabs(
            vault: vault,
            isDarkReaderEnabled: darkReaderEnabled,
            darkReaderTheme: savedDarkReaderTheme,
            isStylusCatppuccinEnabled: stylusCatppuccinEnabled,
            isFPSForcerEnabled: fpsForcerEnabled,
            forcedFPS: savedForcedFPS,
            isAdBlockerEnabled: adBlockerEnabled,
            trackerBlockingLevel: savedTrackerBlockingLevel,
            isScriptBlockingEnabled: scriptBlockingEnabled,
            isHTTPSUpgradeEnabled: httpsUpgradeEnabled,
            isFingerprintProtectionEnabled: fingerprintProtectionEnabled,
            isSocialBlockingEnabled: socialBlockingEnabled,
            isPopupBlockingEnabled: popupBlockingEnabled,
            isTrackingParameterStrippingEnabled: trackingParameterStrippingEnabled,
            isBounceTrackingProtectionEnabled: bounceTrackingProtectionEnabled,
            isWebRTCProtectionEnabled: webRTCProtectionEnabled,
            isRegionTricksEnabled: regionTricksEnabled,
            regionTrickProfile: savedRegionTrickProfile,
            isDeveloperModeEnabled: developerModeEnabled,
            websiteResolutionScale: savedWebsiteResolutionScale,
            websiteDisplayMode: savedWebsiteDisplayMode,
            browserResolutionPreset: savedBrowserResolutionPreset,
            browserResolutionWidth: savedBrowserResolutionWidth,
            webExtensions: savedWebExtensions,
            websiteBlacklist: savedWebsiteBlacklist,
            websiteProtectionWhitelist: savedWebsiteProtectionWhitelist
        )
        let savedTopSearchBarPlacement = BrowserToolbarPlacement(
            rawValue: vault.load(String.self, forKey: Self.StorageKey.topSearchBarPlacement, default: "")
        ) ?? .top
        let savedTopSearchBarPositionX = Self.clampedUnit(
            vault.load(Double.self, forKey: Self.StorageKey.topSearchBarPositionX, default: 0.5)
        )
        let savedTopSearchBarPositionY = Self.clampedUnit(
            vault.load(
                Double.self,
                forKey: Self.StorageKey.topSearchBarPositionY,
                default: Self.defaultTopSearchBarY(for: savedTopSearchBarPlacement)
            )
        )

        self.chromePlacement = placement
        self.areSideTabsCollapsed = shouldApplyLeanProfile ? true : vault.load(Bool.self, forKey: Self.StorageKey.sideTabsCollapsed, default: false)
        self.isDesktopZenModeEnabled = shouldApplyLeanProfile ? false : vault.load(Bool.self, forKey: Self.StorageKey.desktopZenModeEnabled, default: false)
        self.arePageControlsCollapsed = vault.load(Bool.self, forKey: Self.StorageKey.pageControlsCollapsed, default: false)
        self.compactModeHidesQuickControls = vault.load(Bool.self, forKey: Self.StorageKey.compactModeHidesQuickControls, default: true)
        self.isTwoFingerDoubleTapCompactEnabledOnIPad = vault.load(Bool.self, forKey: Self.StorageKey.twoFingerDoubleTapCompactOnIPad, default: false)
        self.sideChromeWidthFraction = Self.clampedSideChromeWidthFraction(
            shouldApplyLeanProfile ? 0.34 : vault.load(Double.self, forKey: Self.StorageKey.sideChromeWidthFraction, default: 0.34)
        )
        self.pageControlsOffsetX = Self.clampedUnit(vault.load(Double.self, forKey: Self.StorageKey.pageControlsOffsetX, default: 0.0))
        self.pageControlsOffsetY = Self.clampedUnit(vault.load(Double.self, forKey: Self.StorageKey.pageControlsOffsetY, default: 0.0))
        self.searchEngine = selectedSearchEngine
        self.customSearchTemplate = savedCustomSearch
        self.bangs = savedBangs.isEmpty ? BrowserBang.defaults : savedBangs
        self.allTabsLayout = savedAllTabsLayout
        self.allTabsDensity = savedAllTabsDensity
        self.allTabsSortOrder = savedAllTabsSortOrder
        self.allTabsShowsContainedTabs = vault.load(Bool.self, forKey: Self.StorageKey.allTabsShowsContainedTabs, default: true)
        self.allTabsShowsPrivateSummary = vault.load(Bool.self, forKey: Self.StorageKey.allTabsShowsPrivateSummary, default: true)
        self.moreMenuActionIDs = savedMoreMenuActionIDs
        self.toolbarActionIDs = savedToolbarActionIDs
        self.isDeveloperModeEnabled = developerModeEnabled
        self.isWebInspectorEnabled = webInspectorEnabled
        self.isDevWebKitEnabled = devWebKitEnabled
        self.devCustomEngineIdentifier = savedDevCustomEngineIdentifier
        self.deviceExperienceOverride = savedDeviceExperienceOverride
        self.compactModeHidesTopSearchBar = vault.load(Bool.self, forKey: Self.StorageKey.compactModeHidesTopSearchBar, default: true)
        self.compactModeRevealsTopSearchBar = vault.load(Bool.self, forKey: Self.StorageKey.compactModeRevealsTopSearchBar, default: false)
        self.isTopSearchBarEnabled = shouldApplyToolbarUpgrade
            ? true
            : vault.load(Bool.self, forKey: Self.StorageKey.topSearchBarEnabled, default: true)
        self.topSearchBarPlacement = savedTopSearchBarPlacement
        self.topSearchBarPositionX = savedTopSearchBarPositionX
        self.topSearchBarPositionY = savedTopSearchBarPositionY
        self.topSearchBarDraftX = savedTopSearchBarPositionX
        self.topSearchBarDraftY = savedTopSearchBarPositionY
        self.customIconNames = Self.sanitizedIconNames(savedCustomIconNames)
        self.customIconColorHexBySlot = Self.sanitizedIconColors(savedCustomIconColors)
        self.customIconImageDataBySlot = Self.sanitizedIconImageData(savedCustomIconImageData)
        self.history = savedHistory
        self.essentials = savedEssentials
        self.websiteBlacklist = savedWebsiteBlacklist
        self.websiteProtectionWhitelist = savedWebsiteProtectionWhitelist
        self.tabFolders = savedTabFolders
        self.collapsedTabFolderIDs = savedCollapsedTabFolderIDs
        self.downloads = savedDownloads
        self.passwordEntries = savedPasswordEntries
        self.installedWebExtensions = savedWebExtensions
        self.webExtensionImportMessage = ""
        self.websiteDisplayMode = savedWebsiteDisplayMode
        self.browserResolutionPreset = savedBrowserResolutionPreset
        self.browserResolutionWidth = savedBrowserResolutionWidth
        self.isTutorialPresented = hasCompletedTutorial == false
        self.isFeatureUpdatePresented = hasCompletedTutorial && savedFeatureUpdateVersion < Self.currentFeatureUpdateVersion
        self.isDarkReaderEnabled = darkReaderEnabled
        self.darkReaderTheme = savedDarkReaderTheme
        self.isStylusCatppuccinEnabled = stylusCatppuccinEnabled
        self.isFPSForcerEnabled = fpsForcerEnabled
        self.forcedFPS = savedForcedFPS
        self.websiteResolutionScale = savedWebsiteResolutionScale
        self.isAdBlockerEnabled = adBlockerEnabled
        self.trackerBlockingLevel = savedTrackerBlockingLevel
        self.isScriptBlockingEnabled = scriptBlockingEnabled
        self.isHTTPSUpgradeEnabled = httpsUpgradeEnabled
        self.isFingerprintProtectionEnabled = fingerprintProtectionEnabled
        self.isSocialBlockingEnabled = socialBlockingEnabled
        self.isPopupBlockingEnabled = popupBlockingEnabled
        self.isTrackingParameterStrippingEnabled = trackingParameterStrippingEnabled
        self.isBounceTrackingProtectionEnabled = bounceTrackingProtectionEnabled
        self.isWebRTCProtectionEnabled = webRTCProtectionEnabled
        self.isRegionTricksEnabled = regionTricksEnabled
        self.regionTrickProfile = savedRegionTrickProfile
        self.isBrowserMusicEnabled = false
        self.browserMusicTrack = savedBrowserMusicTrack
        self.browserMusicVolume = Self.clampedUnit(vault.load(Double.self, forKey: Self.StorageKey.browserMusicVolume, default: 0.34))
        self.importedBrowserMusicFilename = vault.load(String.self, forKey: Self.StorageKey.importedBrowserMusicFilename, default: "")
        self.newTabOpensSearch = vault.load(Bool.self, forKey: Self.StorageKey.newTabOpensSearch, default: true)
        self.autoCompactAfterSearchOnPhone = vault.load(Bool.self, forKey: Self.StorageKey.autoCompactAfterSearchOnPhone, default: true)
        self.localAIName = vault.load(String.self, forKey: Self.StorageKey.localAIName, default: "Local AI")
        self.localAIURLText = vault.load(String.self, forKey: Self.StorageKey.localAIURLText, default: "")
        self.vpnProfile = savedVPNProfile
        self.selectedVPNCountry = savedVPNCountry.isEmpty ? savedVPNProfile.countryName : savedVPNCountry
        self.vpnStatusMessage = savedVPNProfile.isConfigured ? "Custom VPN profile saved." : "Custom VPN profile not configured."
        self.tabs = restoredTabs.tabs
        self.selectedTabID = restoredTabs.selectedTabID
        if isDesktopZenModeEnabled {
            isTopSearchBarEnabled = true
        }

        for tab in tabs {
            configure(tab)
        }
        BrowserWebsitePrivacyController.shared.update(blockedDomains: websiteBlacklist)
        applyDeveloperOptionsToTabs()
        migrateLoadedStateToEncryptedVault()
        updateBrowserMusicPlayer()
        vault.save(false, forKey: Self.StorageKey.browserMusicEnabled)
        vault.save(2, forKey: Self.StorageKey.leanProfileVersion)
        vault.save(2, forKey: Self.StorageKey.toolbarUpgradeVersion)
    }

    var forcedFPSLabel: String {
        forcedFPS >= Self.infiniteForcedFPSValue ? "Infinite" : "\(Int(forcedFPS.rounded())) FPS"
    }

    var websiteResolutionLabel: String {
        "\(Int((websiteResolutionScale * 100).rounded()))%"
    }

    var browserResolutionLabel: String {
        if browserResolutionPreset == .automatic {
            return "Auto"
        }
        return BrowserResolutionPreset.screenScaleLabel(for: browserResolutionWidth)
    }

    func browserResolutionLabel(forWidth width: Double) -> String {
        BrowserResolutionPreset.screenScaleLabel(for: width)
    }

    var effectiveDeviceExperienceOverride: BrowserDeviceExperienceOverride {
        if browserResolutionPreset == .custom {
            return .automatic
        }

        let resolutionOverride = browserResolutionPreset.deviceExperienceOverride
        if resolutionOverride != .automatic {
            return resolutionOverride
        }

        return isDeveloperModeEnabled ? deviceExperienceOverride : .automatic
    }

    var selectedTab: BrowserTab? {
        let visibleTabs = isPrivateModeEnabled ? privateTabs : normalTabs
        guard let selectedTabID = selectedTabID else { return visibleTabs.first }
        return visibleTabs.first { $0.id == selectedTabID } ?? visibleTabs.first
    }

    var selectedContainedTab: BrowserTab? {
        guard let selectedContainedTabID = selectedContainedTabID else { return containedTabs.first }
        return containedTabs.first { $0.id == selectedContainedTabID } ?? containedTabs.first
    }

    var normalTabs: [BrowserTab] {
        tabs.filter { !$0.isPrivate }
    }

    var privateTabs: [BrowserTab] {
        tabs.filter { $0.isPrivate }
    }

    var chromeTabs: [BrowserTab] {
        isPrivateModeEnabled ? privateTabs : normalTabs
    }

    var visibleNormalTabs: [BrowserTab] {
        isPrivateModeEnabled ? [] : normalTabs
    }

    var visiblePrivateTabs: [BrowserTab] {
        isPrivateModeEnabled ? privateTabs : []
    }

    var visibleEssentials: [BrowserEssentialItem] {
        isPrivateModeEnabled ? [] : essentials
    }

    var visibleContainedTabs: [BrowserTab] {
        isPrivateModeEnabled ? [] : containedTabs
    }

    var unfiledNormalTabs: [BrowserTab] {
        normalTabs.filter { $0.folderID == nil }
    }

    func tabs(in folder: BrowserTabFolder) -> [BrowserTab] {
        normalTabs.filter { $0.folderID == folder.id }
    }

    func folderName(for tab: BrowserTab) -> String? {
        guard let folderID = tab.folderID else { return nil }
        return tabFolders.first { $0.id == folderID }?.name
    }

    var closeAllTabsWarningMessage: String {
        let summary = [
            Self.countLabel(normalTabs.count, singular: "normal tab"),
            Self.countLabel(privateTabs.count, singular: "private tab"),
            Self.countLabel(containedTabs.count, singular: "contained tab")
        ].joined(separator: ", ")
        let replacementKind = isPrivateModeEnabled ? "private" : "normal"
        return "This will close \(summary). History, downloads, saved themes, and settings will stay. A fresh \(replacementKind) tab will open."
    }

    func select(_ tab: BrowserTab) {
        if isPrivateModeEnabled {
            guard tab.isPrivate else { return }
        } else {
            guard tab.isPrivate == false else { return }
        }

        selectedTabID = tab.id
        if isFloatingSearchPresented {
            floatingSearchText = tab.addressText
        }
        persistOpenTabs()
    }

    func selectFromFinder(_ tab: BrowserTab) {
        if containedTabs.contains(where: { $0.id == tab.id }) {
            guard isPrivateModeEnabled == false else { return }
            selectedContainedTabID = tab.id
            isContainedBrowserPresented = true
        } else {
            select(tab)
        }
        isTabFinderPresented = false
    }

    func showAllTabs() {
        isFloatingSearchPresented = false
        isContainedBrowserPresented = false
        isTabFinderPresented = true
    }

    @discardableResult
    func createTabFolder(named rawName: String = "") -> BrowserTabFolder {
        let trimmedName = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        let fallbackName = "Folder \(tabFolders.count + 1)"
        let folder = BrowserTabFolder(name: trimmedName.isEmpty ? fallbackName : trimmedName)
        tabFolders.append(folder)
        return folder
    }

    func createFolderFromSelectedTab() {
        guard let tab = selectedTab, tab.isPrivate == false else {
            showZenFolders()
            return
        }

        createFolder(from: tab)
    }

    func createFolder(from tab: BrowserTab) {
        guard tab.isPrivate == false else {
            showZenFolders()
            return
        }

        let folder = createTabFolder(named: tab.url?.host ?? "Saved Tabs")
        assign(tab, to: folder)
        collapsedTabFolderIDs.remove(folder.id)
        showZenFolders()
    }

    func showZenFolders() {
        isTabFoldersPresented = false
        if chromePlacement != .left && chromePlacement != .right {
            chromePlacement = .left
        }
        areSideTabsCollapsed = false
    }

    func isFolderCollapsed(_ folder: BrowserTabFolder) -> Bool {
        collapsedTabFolderIDs.contains(folder.id)
    }

    func toggleFolderCollapsed(_ folder: BrowserTabFolder) {
        if collapsedTabFolderIDs.contains(folder.id) {
            collapsedTabFolderIDs.remove(folder.id)
        } else {
            collapsedTabFolderIDs.insert(folder.id)
        }
    }

    func assign(_ tab: BrowserTab, to folder: BrowserTabFolder) {
        guard tab.isPrivate == false,
              tabFolders.contains(where: { $0.id == folder.id }) else { return }
        tab.folderID = folder.id
        persistOpenTabs()
    }

    func removeFromFolder(_ tab: BrowserTab) {
        guard tab.isPrivate == false else { return }
        tab.folderID = nil
        persistOpenTabs()
    }

    func rename(_ folder: BrowserTabFolder, to rawName: String) {
        let trimmedName = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedName.isEmpty == false,
              let index = tabFolders.firstIndex(where: { $0.id == folder.id }) else { return }
        tabFolders[index].name = trimmedName
    }

    func delete(_ folder: BrowserTabFolder) {
        tabFolders.removeAll { $0.id == folder.id }
        collapsedTabFolderIDs.remove(folder.id)
        for tab in normalTabs where tab.folderID == folder.id {
            tab.folderID = nil
        }
        persistOpenTabs()
    }

    func moveTab(withID sourceID: UUID, before targetID: UUID) {
        guard sourceID != targetID,
              let sourceIndex = tabs.firstIndex(where: { $0.id == sourceID }),
              let targetIndex = tabs.firstIndex(where: { $0.id == targetID }) else { return }

        let movedTab = tabs.remove(at: sourceIndex)
        let adjustedTargetIndex = sourceIndex < targetIndex ? targetIndex - 1 : targetIndex
        tabs.insert(movedTab, at: max(0, min(adjustedTargetIndex, tabs.count)))
        selectedTabID = movedTab.id
        persistOpenTabs()
    }

    @discardableResult
    func openTab(startURL: URL = BrowserDefaults.homeURL, private isPrivate: Bool = false, devWebKit: Bool? = nil) -> BrowserTab {
        let shouldOpenPrivate = isPrivate || isPrivateModeEnabled
        let shouldUseDevWebKit = isDeveloperModeEnabled && shouldOpenPrivate == false && (devWebKit ?? isDevWebKitEnabled)
        let tab = BrowserTab(
            startURL: startURL,
            isPrivate: shouldOpenPrivate,
            usesPersistentStorage: shouldOpenPrivate == false,
            isDarkReaderEnabled: isDarkReaderEnabled,
            darkReaderTheme: darkReaderTheme,
            isStylusCatppuccinEnabled: isStylusCatppuccinEnabled,
            isAdBlockerEnabled: isAdBlockerEnabled,
            trackerBlockingLevel: trackerBlockingLevel,
            isScriptBlockingEnabled: isScriptBlockingEnabled,
            isHTTPSUpgradeEnabled: isHTTPSUpgradeEnabled,
            isFingerprintProtectionEnabled: isFingerprintProtectionEnabled,
            isSocialBlockingEnabled: isSocialBlockingEnabled,
            isPopupBlockingEnabled: isPopupBlockingEnabled,
            isTrackingParameterStrippingEnabled: isTrackingParameterStrippingEnabled,
            isBounceTrackingProtectionEnabled: isBounceTrackingProtectionEnabled,
            isWebRTCProtectionEnabled: isWebRTCProtectionEnabled,
            isRegionTricksEnabled: isRegionTricksEnabled,
            regionTrickProfile: regionTrickProfile,
            isFPSForcerEnabled: isFPSForcerEnabled,
            forcedFPS: forcedFPS,
            websiteResolutionScale: websiteResolutionScale,
            websiteDisplayMode: websiteDisplayMode,
            browserResolutionPreset: browserResolutionPreset,
            browserResolutionWidth: browserResolutionWidth,
            webExtensions: installedWebExtensions,
            websiteBlacklist: websiteBlacklist,
            websiteProtectionWhitelist: websiteProtectionWhitelist,
            webKitProfile: shouldUseDevWebKit ? .dev : .standard
        )
        configure(tab)
        applyDeveloperOptions(to: tab)
        tabs.append(tab)
        selectedTabID = tab.id
        persistOpenTabs()
        return tab
    }

    func openNewTabAndSearch(private isPrivate: Bool = false) {
        let tab = openTab(private: isPrivate || isPrivateModeEnabled)
        floatingSearchText = tab.addressText
        shouldSelectFloatingSearchText = true
        isFloatingSearchPresented = newTabOpensSearch
    }

    func openDevWebKitTab() {
        guard isDeveloperModeEnabled else {
            devModeStatusMessage = "Turn on Dev Mode before creating a Dev WebKit tab."
            return
        }

        let tab = openTab(devWebKit: true)
        floatingSearchText = tab.addressText
        shouldSelectFloatingSearchText = true
        isFloatingSearchPresented = newTabOpensSearch
        devModeStatusMessage = "Opened a Dev WebKit tab. Shields and the ad blocker are still active."
    }

    func openPrivateTab() {
        guard isPrivateModeEnabled else {
            requestPrivateModeToggle()
            return
        }

        openNewTabAndSearch(private: true)
    }

    @discardableResult
    func openContainedTab(startURL: URL = BrowserDefaults.containedBrowserStartURL) -> BrowserTab {
        let shouldUseDevWebKit = isDeveloperModeEnabled && isDevWebKitEnabled
        let tab = BrowserTab(
            startURL: startURL,
            usesPersistentStorage: false,
            isContainedBrowser: true,
            isDarkReaderEnabled: isDarkReaderEnabled,
            darkReaderTheme: darkReaderTheme,
            isStylusCatppuccinEnabled: isStylusCatppuccinEnabled,
            isAdBlockerEnabled: isAdBlockerEnabled,
            trackerBlockingLevel: trackerBlockingLevel,
            isScriptBlockingEnabled: isScriptBlockingEnabled,
            isHTTPSUpgradeEnabled: isHTTPSUpgradeEnabled,
            isFingerprintProtectionEnabled: isFingerprintProtectionEnabled,
            isSocialBlockingEnabled: isSocialBlockingEnabled,
            isPopupBlockingEnabled: isPopupBlockingEnabled,
            isTrackingParameterStrippingEnabled: isTrackingParameterStrippingEnabled,
            isBounceTrackingProtectionEnabled: isBounceTrackingProtectionEnabled,
            isWebRTCProtectionEnabled: isWebRTCProtectionEnabled,
            isRegionTricksEnabled: isRegionTricksEnabled,
            regionTrickProfile: regionTrickProfile,
            isFPSForcerEnabled: isFPSForcerEnabled,
            forcedFPS: forcedFPS,
            websiteResolutionScale: websiteResolutionScale,
            websiteDisplayMode: websiteDisplayMode,
            browserResolutionPreset: browserResolutionPreset,
            browserResolutionWidth: browserResolutionWidth,
            webExtensions: installedWebExtensions,
            websiteBlacklist: websiteBlacklist,
            websiteProtectionWhitelist: websiteProtectionWhitelist,
            webKitProfile: shouldUseDevWebKit ? .dev : .standard
        )
        configureContained(tab)
        applyDeveloperOptions(to: tab)
        containedTabs.append(tab)
        selectedContainedTabID = tab.id
        isContainedBrowserPresented = true
        return tab
    }

    func showContainedTabs() {
        if containedTabs.isEmpty {
            openContainedTab()
        } else {
            isContainedBrowserPresented = true
        }
    }

    func selectContained(_ tab: BrowserTab) {
        selectedContainedTabID = tab.id
    }

    func closeContainedBrowser() {
        isContainedBrowserPresented = false
    }

    func closeContained(_ tab: BrowserTab) {
        containedTabs.removeAll { $0.id == tab.id }

        if containedTabs.isEmpty {
            selectedContainedTabID = nil
            isContainedBrowserPresented = false
            return
        }

        if selectedContainedTabID == tab.id {
            selectedContainedTabID = containedTabs.last?.id
        }
    }

    func closeFromFinder(_ tab: BrowserTab) {
        if containedTabs.contains(where: { $0.id == tab.id }) {
            closeContained(tab)
        } else {
            close(tab)
        }
    }

    func submitContainedAddress() {
        selectedContainedTab?.submitAddress(
            searchEngine: searchEngine,
            customSearchTemplate: customSearchTemplate,
            bangs: bangs
        )
    }

    func close(_ tab: BrowserTab) {
        if isPrivateModeEnabled, tab.isPrivate, privateTabs.count <= 1 {
            tab.load(BrowserTab.homeURL)
            selectedTabID = tab.id
            persistOpenTabs()
            return
        }

        guard tabs.count > 1 else {
            tab.load(BrowserTab.homeURL)
            persistOpenTabs()
            return
        }

        let wasSelected = selectedTabID.map { $0 == tab.id } ?? false
        tabs.removeAll { $0.id == tab.id }

        if wasSelected {
            if isPrivateModeEnabled {
                selectedTabID = privateTabs.last?.id
            } else if let normalTab = normalTabs.last {
                selectedTabID = normalTab.id
            } else {
                selectedTabID = openTab().id
            }
        }

        if isPrivateModeEnabled, privateTabs.isEmpty {
            openTab(private: true)
        }

        persistOpenTabs()
    }

    func closeSelectedTab() {
        guard let tab = selectedTab else { return }
        close(tab)
    }

    func selectNextTab() {
        selectAdjacentTab(offset: 1)
    }

    func selectPreviousTab() {
        selectAdjacentTab(offset: -1)
    }

    private func selectAdjacentTab(offset: Int) {
        let visibleTabs = isPrivateModeEnabled ? privateTabs : normalTabs
        guard visibleTabs.isEmpty == false else { return }

        let currentIndex = selectedTabID.flatMap { id in
            visibleTabs.firstIndex { $0.id == id }
        } ?? 0
        let nextIndex = (currentIndex + offset + visibleTabs.count) % visibleTabs.count
        select(visibleTabs[nextIndex])
    }

    func requestCloseAllTabs() {
        isCloseAllTabsWarningPresented = true
    }

    func closeAllTabs() {
        isCloseAllTabsWarningPresented = false
        isFloatingSearchPresented = false
        isContainedBrowserPresented = false
        isTabFinderPresented = false
        selectedContainedTabID = nil
        containedTabs.removeAll()
        tabs.removeAll()
        selectedTabID = nil

        let replacement = openTab(private: isPrivateModeEnabled)
        floatingSearchText = replacement.addressText
        shouldSelectFloatingSearchText = false
        persistOpenTabs()
    }

    func goBack() {
        selectedTab?.goBack()
    }

    func goForward() {
        selectedTab?.goForward()
    }

    func reloadOrStop() {
        selectedTab?.reloadOrStop()
    }

    func submitAddress(autoCompactChrome: Bool = false) {
        let submittedText = isFloatingSearchPresented ? floatingSearchText : selectedTab?.addressText ?? ""
        selectedTab?.addressText = submittedText
        selectedTab?.submitAddress(
            searchEngine: searchEngine,
            customSearchTemplate: customSearchTemplate,
            bangs: bangs
        )
        floatingSearchText = selectedTab?.addressText ?? submittedText
        shouldSelectFloatingSearchText = false
        isFloatingSearchPresented = false
        if shouldCompactAfterSearch(autoCompactChrome: autoCompactChrome) {
            enterCompactMode()
        }
    }

    func setPhoneExperienceActive(_ isActive: Bool) {
        guard isPhoneExperienceActive != isActive else { return }
        isPhoneExperienceActive = isActive
    }

    func setDesktopZenModeEnabled(_ enabled: Bool) {
        guard Self.supportsDesktopZenMode else {
            isDesktopZenModeEnabled = false
            return
        }

        withAnimation(.spring(response: 0.24, dampingFraction: 0.88)) {
            isDesktopZenModeEnabled = enabled
            if enabled {
                isTopSearchBarEnabled = true
                isFloatingSearchPresented = false
            }
        }
    }

    func openFloatingSearch() {
        floatingSearchText = selectedTab?.addressText ?? ""
        shouldSelectFloatingSearchText = true
        isFloatingSearchPresented = true
    }

    func enterFullscreenBrowsing() {
        withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
            areSideTabsCollapsed = true
            isTopSearchBarEnabled = false
            isDesktopZenModeEnabled = false
            compactModeHidesQuickControls = true
            arePageControlsCollapsed = true
            isFloatingSearchPresented = false
        }
    }

    func openAIPanel(action: BrowserAIAction = .summarize) {
        isAIPanelPresented = true
        prepareAI(action)
    }

    func prepareAI(_ action: BrowserAIAction) {
        guard let tab = selectedTab else {
            aiPromptText = action.instruction
            aiStatusMessage = "Open a page first."
            return
        }

        aiStatusMessage = "Reading page context..."
        let title = tab.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let urlText = tab.url?.absoluteString ?? tab.addressText
        tab.extractReadablePageText { [weak self] pageText in
            guard let self else { return }
            self.aiPromptText = self.aiPrompt(
                action: action,
                title: title.isEmpty ? "Current page" : title,
                urlText: urlText,
                pageText: pageText
            )
            self.aiStatusMessage = pageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? "Prompt ready. Page text was limited, so URL and title were used."
                : "Prompt ready with page context."
        }
    }

    func copyAIPrompt() {
        UIPasteboard.general.string = aiPromptText
        aiStatusMessage = "Copied AI prompt."
    }

    func openAIAssistantWithPrompt(_ assistant: AIAssistant) {
        copyAIPrompt()
        openAIShortcut(assistant)
    }

    func setDarkReaderEnabled(_ enabled: Bool) {
        isDarkReaderEnabled = enabled
        vault.save(enabled, forKey: Self.StorageKey.darkReaderEnabled)
        for tab in tabs {
            tab.setDarkReaderEnabled(enabled)
        }
        for tab in containedTabs {
            tab.setDarkReaderEnabled(enabled)
        }
    }

    func setDarkReaderTheme(_ theme: BrowserDarkReaderTheme) {
        darkReaderTheme = theme
    }

    func setStylusCatppuccinEnabled(_ enabled: Bool) {
        isStylusCatppuccinEnabled = enabled
    }

    func setFPSForcerEnabled(_ enabled: Bool) {
        isFPSForcerEnabled = enabled
    }

    func setForcedFPS(_ fps: Double) {
        forcedFPS = fps
    }

    func setWebsiteResolutionScale(_ scale: Double) {
        websiteResolutionScale = scale
    }

    func setBrowserResolutionPreset(_ preset: BrowserResolutionPreset) {
        let resolvedScale = preset == .custom ? browserResolutionWidth : preset.screenScale
        browserResolutionWidth = BrowserResolutionPreset.clampedScreenScale(resolvedScale)
        browserResolutionPreset = preset
        applyBrowserResolution(
            preset: preset,
            width: browserResolutionWidth,
            reloadAfterChange: true
        )
    }

    func setBrowserResolutionWidth(_ width: Double) {
        let clampedWidth = BrowserResolutionPreset.clampedScreenScale(width)
        browserResolutionWidth = clampedWidth
        browserResolutionPreset = .custom
        applyBrowserResolution(
            preset: .custom,
            width: clampedWidth,
            reloadAfterChange: true
        )
    }

    func previewBrowserResolutionWidth(_ width: Double) {
        let clampedWidth = BrowserResolutionPreset.clampedScreenScale(width)
        browserResolutionWidth = clampedWidth
        browserResolutionPreset = .custom
        if clampedWidth <= 0.65 {
            areSideTabsCollapsed = false
        }
    }

    private func applyBrowserResolution(
        preset: BrowserResolutionPreset,
        width: Double,
        reloadAfterChange: Bool
    ) {
        isApplyingBrowserResolutionPreset = true
        defer { isApplyingBrowserResolutionPreset = false }

        websiteResolutionScale = 1.0
        let displayMode = Self.websiteDisplayMode(forBrowserResolution: preset, width: width)
        let shouldLetDisplayModeReload = websiteDisplayMode != displayMode
        for tab in tabs {
            tab.setBrowserResolution(
                preset: preset,
                width: width,
                reloadAfterChange: reloadAfterChange && shouldLetDisplayModeReload == false
            )
        }
        for tab in containedTabs {
            tab.setBrowserResolution(
                preset: preset,
                width: width,
                reloadAfterChange: reloadAfterChange && shouldLetDisplayModeReload == false
            )
        }
        if shouldLetDisplayModeReload {
            websiteDisplayMode = displayMode
        }

        if preset.deviceExperienceOverride == .iPad || (preset == .custom && width <= 0.65) {
            areSideTabsCollapsed = false
        }
    }

    func setAdBlockerEnabled(_ enabled: Bool) {
        isAdBlockerEnabled = enabled
        vault.save(enabled, forKey: Self.StorageKey.adBlockerEnabled)
        for tab in tabs {
            tab.setAdBlockerEnabled(enabled)
        }
        for tab in containedTabs {
            tab.setAdBlockerEnabled(enabled)
        }
    }

    private func applyRegionTricksToTabs() {
        for tab in tabs {
            tab.setRegionTricks(enabled: isRegionTricksEnabled, profile: regionTrickProfile)
        }
        for tab in containedTabs {
            tab.setRegionTricks(enabled: isRegionTricksEnabled, profile: regionTrickProfile)
        }
    }

    func setBrowserMusicEnabled(_ enabled: Bool) {
        isBrowserMusicEnabled = enabled
    }

    func toggleBrowserMusic() {
        isBrowserMusicEnabled.toggle()
    }

    var hasImportedBrowserMusic: Bool {
        importedBrowserMusicURL != nil
    }

    var importedBrowserMusicDisplayName: String {
        Self.displayName(forImportedBrowserMusicFilename: importedBrowserMusicFilename)
    }

    var selectedBrowserMusicTitle: String {
        if browserMusicTrack == .imported {
            return hasImportedBrowserMusic ? importedBrowserMusicDisplayName : "Imported Audio"
        }
        return browserMusicTrack.title
    }

    func importBrowserMusic(from result: Result<[URL], Error>) {
        do {
            guard let sourceURL = try result.get().first else { return }
            browserMusicImportMessage = "Importing \(sourceURL.lastPathComponent)..."
            Task {
                do {
                    let filename = try await Task.detached(priority: .utility) {
                        try Self.copyImportedBrowserMusicFile(from: sourceURL)
                    }.value
                    let previousFilename = importedBrowserMusicFilename
                    importedBrowserMusicFilename = filename
                    browserMusicTrack = .imported
                    isBrowserMusicEnabled = true
                    browserMusicImportMessage = "Imported \(Self.displayName(forImportedBrowserMusicFilename: filename))."
                    Self.removeImportedBrowserMusicFile(named: previousFilename)
                } catch {
                    browserMusicImportMessage = error.localizedDescription
                }
            }
        } catch {
            browserMusicImportMessage = error.localizedDescription
        }
    }

    func clearImportedBrowserMusic() {
        let previousFilename = importedBrowserMusicFilename
        importedBrowserMusicFilename = ""
        if browserMusicTrack == .imported {
            browserMusicTrack = .focus
        }
        Self.removeImportedBrowserMusicFile(named: previousFilename)
        browserMusicImportMessage = "Imported audio cleared."
    }

    private func updateBrowserMusicPlayer() {
        browserMusicPlayer.update(
            isEnabled: isBrowserMusicEnabled,
            track: browserMusicTrack,
            volume: browserMusicVolume,
            importedAudioURL: importedBrowserMusicURL
        )
    }

    func setDeveloperModeEnabled(_ enabled: Bool) {
        isDeveloperModeEnabled = enabled
        if enabled {
            devModeStatusMessage = "Dev Mode enabled. Debug options can make pages slower or harder to use."
        } else {
            devModeStatusMessage = ""
            devCustomEngineIdentifier = ""
        }
    }

    func setWebInspectorEnabled(_ enabled: Bool) {
        guard isDeveloperModeEnabled else {
            isWebInspectorEnabled = false
            return
        }
        isWebInspectorEnabled = enabled
    }

    func setDevWebKitEnabled(_ enabled: Bool) {
        guard isDeveloperModeEnabled else {
            isDevWebKitEnabled = false
            return
        }
        isDevWebKitEnabled = enabled
        devModeStatusMessage = enabled
            ? "Dev WebKit will be used for new tabs. Shields and the ad blocker stay active."
            : "New tabs will use the standard WKWebView profile."
    }

    func setDeviceExperienceOverride(_ override: BrowserDeviceExperienceOverride) {
        guard isDeveloperModeEnabled else {
            deviceExperienceOverride = .automatic
            devModeStatusMessage = "Turn on Dev Mode before changing the app experience."
            return
        }

        isTopSearchBarMoveMode = false
        isChromeWidthResizeMode = false
        isPageControlsMoveMode = false
        deviceExperienceOverride = override
        devModeStatusMessage = override == .automatic
            ? "Experience follows the current screen size."
            : "Experience forced to \(override.title) until Dev Mode is turned off."
    }

    func requestWKEscapeMode() {
        devModeStatusMessage = "\(BrowserEngineBuild.engineSummary) \(BrowserEngineBuild.geckoReadinessMessage)"
    }

    private var importedBrowserMusicURL: URL? {
        Self.importedBrowserMusicURL(for: importedBrowserMusicFilename)
    }

    var isCompactModeActive: Bool {
        areSideTabsCollapsed && (compactModeHidesTopSearchBar == false || isTopSearchBarEnabled == false)
    }

    func setTabBarCollapsed(_ collapsed: Bool) {
        withAnimation(.spring(response: 0.28, dampingFraction: 0.84)) {
            areSideTabsCollapsed = collapsed
        }
    }

    func toggleSideTabs() {
        setTabBarCollapsed(!areSideTabsCollapsed)
    }

    func enterCompactMode() {
        withAnimation(.spring(response: 0.28, dampingFraction: 0.84)) {
            isFloatingSearchPresented = false
            if compactModeHidesTopSearchBar {
                isTopSearchBarEnabled = false
            }
            areSideTabsCollapsed = true
            arePageControlsCollapsed = compactModeHidesQuickControls
        }
    }

    func revealCompactMode() {
        withAnimation(.spring(response: 0.28, dampingFraction: 0.84)) {
            isFloatingSearchPresented = false
            if compactModeRevealsTopSearchBar {
                isTopSearchBarEnabled = true
            }
            areSideTabsCollapsed = false
            arePageControlsCollapsed = false
        }
    }

    func toggleCompactMode() {
        if isCompactModeActive {
            revealCompactMode()
        } else {
            enterCompactMode()
        }
    }

    func togglePageControlsCollapsed() {
        withAnimation(.spring(response: 0.26, dampingFraction: 0.86)) {
            arePageControlsCollapsed.toggle()
        }
    }

    func beginChromeWidthResize() {
        isFloatingSearchPresented = false
        isPageControlsMoveMode = false
        if chromePlacement != .left && chromePlacement != .right {
            chromePlacement = .left
        }
        areSideTabsCollapsed = false
        isChromeWidthResizeMode = true
    }

    func endChromeWidthResize() {
        isChromeWidthResizeMode = false
    }

    func resetChromeWidth() {
        sideChromeWidthFraction = 0.3
    }

    func updateSideChromeWidth(_ width: CGFloat, containerWidth: CGFloat) {
        guard containerWidth > 0 else { return }
        sideChromeWidthFraction = Double(width / containerWidth)
    }

    func beginPageControlsMove() {
        isFloatingSearchPresented = false
        isChromeWidthResizeMode = false
        isPageControlsMoveMode = true
    }

    func endPageControlsMove() {
        isPageControlsMoveMode = false
    }

    func resetPageControlsPosition() {
        pageControlsOffsetX = 0
        pageControlsOffsetY = 0
        isPageControlsMoveMode = false
    }

    func updatePageControlsOffset(x: Double, y: Double) {
        pageControlsOffsetX = x
        pageControlsOffsetY = y
    }

    func handleTwoFingerSwipe(deltaX: CGFloat, deltaY: CGFloat) {
        guard shouldAcceptGestureEvent(lastAcceptedAt: &lastTwoFingerSwipeAt) else { return }

        if abs(deltaY) > abs(deltaX) {
            if deltaY < 0 {
                isTopSearchBarEnabled = false
            } else {
                isTopSearchBarEnabled = true
            }
            return
        }

        setTabBarCollapsed(deltaX < 0)
    }

    func handleTwoFingerDoubleTap() {
        guard shouldAcceptGestureEvent(lastAcceptedAt: &lastTwoFingerDoubleTapAt) else { return }
        toggleCompactMode()
    }

    func completeTutorial() {
        isTutorialPresented = false
        vault.save(true, forKey: Self.StorageKey.hasCompletedTutorial)
        vault.save(Self.currentFeatureUpdateVersion, forKey: Self.StorageKey.featureUpdateVersion)
    }

    func dismissFeatureUpdate() {
        isFeatureUpdatePresented = false
        vault.save(Self.currentFeatureUpdateVersion, forKey: Self.StorageKey.featureUpdateVersion)
    }

    func handleThreeFingerSwipe(deltaX: CGFloat) {
        guard shouldAcceptGestureEvent(lastAcceptedAt: &lastThreeFingerSwipeAt) else { return }

        if deltaX > 0 {
            goBack()
        } else {
            goForward()
        }
    }

    private func shouldAcceptGestureEvent(lastAcceptedAt: inout Date) -> Bool {
        let now = Date()
        guard now.timeIntervalSince(lastAcceptedAt) > 0.35 else { return false }
        lastAcceptedAt = now
        return true
    }

    func openHistoryItem(_ item: BrowserHistoryItem) {
        guard let url = item.url else { return }
        selectedTab?.load(url)
        isHistoryPresented = false
    }

    func addEssential(from tab: BrowserTab) {
        guard tab.isPrivate == false,
              let url = tab.url,
              Self.shouldPersist(url: url) else {
            return
        }

        let title = tab.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let item = BrowserEssentialItem(
            title: title.isEmpty ? (url.host ?? url.absoluteString) : title,
            urlString: url.absoluteString,
            faviconURLString: tab.pageIconURLString,
            accentColorHex: tab.pageThemeColorHex
        )

        essentials.removeAll { $0.urlString == item.urlString }
        essentials.insert(item, at: 0)
        if essentials.count > 16 {
            essentials = Array(essentials.prefix(16))
        }
        saveEssentials()
    }

    func openEssential(_ item: BrowserEssentialItem) {
        guard let url = item.url else { return }
        selectedTab?.load(url)
    }

    func openEssentialInNewTab(_ item: BrowserEssentialItem) {
        guard let url = item.url else { return }
        openTab(startURL: url)
    }

    func removeEssential(_ item: BrowserEssentialItem) {
        essentials.removeAll { $0.id == item.id }
        saveEssentials()
    }

    func isEssentialOpen(_ item: BrowserEssentialItem) -> Bool {
        guard let selectedHost = BrowserWebsitePrivacyPolicy.domain(for: selectedTab?.url),
              let essentialHost = BrowserWebsitePrivacyPolicy.domain(for: item.url) else {
            return false
        }
        return selectedHost == essentialHost
    }

    var currentWebsiteDomain: String? {
        guard let tab = selectedTab,
              tab.isPrivate == false,
              let url = tab.url,
              Self.shouldPersist(url: url) else { return nil }
        return BrowserWebsitePrivacyPolicy.domain(for: url)
    }

    var defaultProtectionScore: Int {
        var score = 0
        if isAdBlockerEnabled {
            score += 24
            if trackerBlockingLevel == .aggressive {
                score += 8
            }
        }
        if isHTTPSUpgradeEnabled { score += 12 }
        if isScriptBlockingEnabled { score += 10 }
        if isFingerprintProtectionEnabled { score += 14 }
        if isSocialBlockingEnabled { score += 6 }
        if isPopupBlockingEnabled { score += 8 }
        if isTrackingParameterStrippingEnabled { score += 6 }
        if isBounceTrackingProtectionEnabled { score += 6 }
        if isWebRTCProtectionEnabled { score += 6 }
        return min(score, 100)
    }

    var whitelistedProtectionScore: Int {
        isHTTPSUpgradeEnabled ? 12 : 0
    }

    var currentWebsiteProtectionScore: Int {
        isWebsiteProtectionWhitelisted(selectedTab?.url)
            ? whitelistedProtectionScore
            : defaultProtectionScore
    }

    func protectionScore(for domain: String) -> Int {
        BrowserWebsitePrivacyPolicy.matches(host: domain, blockedDomains: websiteProtectionWhitelist)
            ? whitelistedProtectionScore
            : defaultProtectionScore
    }

    func isWebsiteBlacklisted(_ url: URL?) -> Bool {
        BrowserWebsitePrivacyPolicy.matches(url: url, blockedDomains: websiteBlacklist)
    }

    func addCurrentWebsiteToBlacklist() {
        guard let domain = currentWebsiteDomain else {
            websiteBlacklistStatusMessage = "Open a website before adding it to the blacklist."
            return
        }
        addWebsiteToBlacklist(domain)
    }

    func addWebsiteToBlacklist(_ rawValue: String) {
        guard let domain = BrowserWebsitePrivacyPolicy.normalizedDomain(from: rawValue) else {
            websiteBlacklistStatusMessage = "Enter a valid website such as example.com."
            return
        }
        guard websiteBlacklist.contains(domain) == false else {
            websiteBlacklistStatusMessage = "\(domain) is already blacklisted."
            return
        }

        let conflictingWhitelist = websiteProtectionWhitelist.filter {
            Self.privacyDomainsConflict($0, domain)
        }
        if conflictingWhitelist.isEmpty == false {
            websiteProtectionWhitelist.removeAll { conflictingWhitelist.contains($0) }
            applyWebsiteProtectionWhitelist()
        }

        websiteBlacklist = BrowserWebsitePrivacyPolicy.normalizedDomains(websiteBlacklist + [domain])
        history.removeAll { item in
            BrowserWebsitePrivacyPolicy.matches(host: item.url?.host, blockedDomains: [domain])
        }
        saveHistory()
        applyWebsiteBlacklist(purging: [domain])
        websiteBlacklistStatusMessage = "\(domain) will not keep cookies or appear in History."
    }

    func removeWebsiteFromBlacklist(_ domain: String) {
        websiteBlacklist.removeAll { $0 == domain }
        applyWebsiteBlacklist()
        websiteBlacklistStatusMessage = "\(domain) can save site data again."
    }

    func clearWebsiteBlacklist() {
        websiteBlacklist = []
        applyWebsiteBlacklist()
        websiteBlacklistStatusMessage = "Website blacklist cleared."
    }

    func isWebsiteProtectionWhitelisted(_ url: URL?) -> Bool {
        BrowserWebsitePrivacyPolicy.matches(url: url, blockedDomains: websiteProtectionWhitelist)
    }

    func addCurrentWebsiteToProtectionWhitelist() {
        guard let domain = currentWebsiteDomain else {
            websiteProtectionWhitelistStatusMessage = "Open a website before adding it to the whitelist."
            return
        }
        addWebsiteToProtectionWhitelist(domain)
    }

    func addWebsiteToProtectionWhitelist(_ rawValue: String) {
        guard let domain = BrowserWebsitePrivacyPolicy.normalizedDomain(from: rawValue) else {
            websiteProtectionWhitelistStatusMessage = "Enter a valid website such as example.com."
            return
        }
        guard BrowserWebsitePrivacyPolicy.matches(host: domain, blockedDomains: websiteProtectionWhitelist) == false else {
            websiteProtectionWhitelistStatusMessage = "\(domain) is already covered by the whitelist."
            return
        }

        let conflictingBlacklist = websiteBlacklist.filter {
            Self.privacyDomainsConflict($0, domain)
        }
        if conflictingBlacklist.isEmpty == false {
            websiteBlacklist.removeAll { conflictingBlacklist.contains($0) }
            applyWebsiteBlacklist()
        }

        websiteProtectionWhitelist = BrowserWebsitePrivacyPolicy.normalizedDomains(
            websiteProtectionWhitelist + [domain]
        )
        applyWebsiteProtectionWhitelist()
        websiteProtectionWhitelistStatusMessage = "\(domain) now uses \(whitelistedProtectionScore)% compatibility protection."
    }

    func removeWebsiteFromProtectionWhitelist(_ domain: String) {
        websiteProtectionWhitelist.removeAll { $0 == domain }
        applyWebsiteProtectionWhitelist()
        websiteProtectionWhitelistStatusMessage = "\(domain) now uses \(defaultProtectionScore)% default protection."
    }

    func clearWebsiteProtectionWhitelist() {
        websiteProtectionWhitelist = []
        applyWebsiteProtectionWhitelist()
        websiteProtectionWhitelistStatusMessage = "Protection whitelist cleared."
    }

    func clearHistory() {
        history = []
        saveHistory()
    }

    func clearDownloads() {
        for item in downloads {
            deleteDownloadFiles(for: item)
        }
        downloads = []
        saveDownloads()
    }

    func deleteDownload(_ item: BrowserDownloadItem) {
        deleteDownloadFiles(for: item)
        downloads.removeAll { $0.id == item.id }
        saveDownloads()
    }

    func canExportDownload(_ item: BrowserDownloadItem) -> Bool {
        guard item.state == .finished else { return false }

        if let encryptedURL = item.encryptedLocalURL {
            return FileManager.default.fileExists(atPath: encryptedURL.path)
        }

        return FileManager.default.fileExists(atPath: item.localPath)
    }

    func prepareDownloadForExport(_ item: BrowserDownloadItem) throws -> URL {
        guard item.state == .finished else {
            throw Self.downloadError("That download has not finished yet.")
        }

        if FileManager.default.fileExists(atPath: item.localPath) {
            downloadStatusMessage = "Ready to open \(item.filename)."
            return item.localURL
        }

        let exportURL = try Self.temporaryExportURL(for: item.filename)
        if FileManager.default.fileExists(atPath: exportURL.path) {
            try FileManager.default.removeItem(at: exportURL)
        }

        if let encryptedURL = item.encryptedLocalURL {
            guard FileManager.default.fileExists(atPath: encryptedURL.path) else {
                throw Self.downloadError("The encrypted download file is missing.")
            }
            let encryptedData = try Data(contentsOf: encryptedURL)
            let plaintextData = try vault.decryptData(encryptedData)
            try plaintextData.write(to: exportURL, options: [.atomic])
            downloadStatusMessage = "Created a temporary decrypted copy of \(item.filename)."
            return exportURL
        }

        guard FileManager.default.fileExists(atPath: item.localPath) else {
            throw Self.downloadError("The downloaded file is missing.")
        }

        try FileManager.default.copyItem(at: item.localURL, to: exportURL)
        downloadStatusMessage = "Created a temporary export copy of \(item.filename)."
        return exportURL
    }

    func cleanupPreparedExport(at url: URL) {
        guard url.deletingLastPathComponent().lastPathComponent == Self.temporaryExportDirectoryName else { return }
        try? FileManager.default.removeItem(at: url)
    }

    func downloadSelectedTab() {
        guard let url = selectedTab?.url,
              Self.shouldPersist(url: url) else {
            downloadStatusMessage = "Nothing downloadable on the current tab."
            isDownloadsPresented = true
            return
        }

        download(url: url)
    }

    func retryDownload(_ item: BrowserDownloadItem) {
        guard let url = URL(string: item.sourceURLString), Self.shouldPersist(url: url) else {
            downloadStatusMessage = "That download does not have a retryable source URL."
            return
        }

        download(url: url, suggestedFilename: item.filename)
    }

    var latestDownloadShelfItem: BrowserDownloadItem? {
        guard let item = downloads.first,
              dismissedDownloadShelfID != item.id else { return nil }
        return item
    }

    func dismissDownloadShelf() {
        dismissedDownloadShelfID = downloads.first?.id
    }

    func cycleWebsiteDisplayMode() {
        setWebsiteDisplayMode(websiteDisplayMode == .desktop ? .mobile : .desktop)
    }

    func setWebsiteDisplayMode(_ mode: BrowserWebsiteDisplayMode) {
        if isApplyingBrowserResolutionPreset == false,
           browserResolutionPreset != .automatic {
            browserResolutionPreset = .automatic
            for tab in tabs {
                tab.setBrowserResolution(
                    preset: .automatic,
                    width: browserResolutionWidth,
                    reloadAfterChange: false
                )
            }
            for tab in containedTabs {
                tab.setBrowserResolution(
                    preset: .automatic,
                    width: browserResolutionWidth,
                    reloadAfterChange: false
                )
            }
        }
        websiteDisplayMode = mode
    }

    var currentPasswordHost: String {
        BrowserPasswordEntry.normalized(selectedTab?.url?.host ?? "")
    }

    func matchingPasswordEntriesForCurrentSite() -> [BrowserPasswordEntry] {
        let host = currentPasswordHost
        guard host.isEmpty == false else { return passwordEntries }
        return passwordEntries.filter { entry in
            let entryHost = entry.normalizedHost
            return host == entryHost || host.hasSuffix("." + entryHost) || entryHost.hasSuffix("." + host)
        }
    }

    func savePasswordEntry(title: String, host: String, username: String, password: String, notes: String = "") {
        let normalizedHost = BrowserPasswordEntry.normalized(host.isEmpty ? currentPasswordHost : host)
        let trimmedUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalizedHost.isEmpty == false,
              trimmedUsername.isEmpty == false,
              password.isEmpty == false else {
            passwordStatusMessage = "Add a site, username, and password first."
            return
        }

        let entryTitle = title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? normalizedHost : title.trimmingCharacters(in: .whitespacesAndNewlines)
        let entry = BrowserPasswordEntry(
            title: entryTitle,
            host: normalizedHost,
            username: trimmedUsername,
            password: password,
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines)
        )

        passwordEntries.removeAll {
            $0.normalizedHost == normalizedHost && $0.username.caseInsensitiveCompare(trimmedUsername) == .orderedSame
        }
        passwordEntries.insert(entry, at: 0)
        passwordStatusMessage = "Saved password for \(normalizedHost)."
    }

    func deletePasswordEntry(_ entry: BrowserPasswordEntry) {
        passwordEntries.removeAll { $0.id == entry.id }
        passwordStatusMessage = "Deleted password for \(entry.host)."
    }

    func fillPasswordEntry(_ entry: BrowserPasswordEntry) {
        selectedTab?.fillCredentials(username: entry.username, password: entry.password)
        passwordStatusMessage = "Filled \(entry.username) on this page."
        isPasswordManagerPresented = false
    }

    func prepareVPNCountry(_ country: String) {
        selectedVPNCountry = country
        var profile = vpnProfile
        profile.countryName = country
        vpnProfile = profile
        vpnStatusMessage = profile.isConfigured
            ? "Ready to change country to \(country)."
            : "Selected \(country). Add a real VPN server for that country, then tap Change Country."
    }

    func isInMoreMenu(_ action: BrowserToolbarAction) -> Bool {
        if action.isLeanBuildUtility {
            return true
        }
        return moreMenuActionIDs.contains(action.rawValue)
    }

    func isInToolbar(_ action: BrowserToolbarAction) -> Bool {
        toolbarActionIDs.contains(action.rawValue)
    }

    func isActionRelocated(_ action: BrowserToolbarAction) -> Bool {
        isInMoreMenu(action) || isInToolbar(action)
    }

    var toolbarActions: [BrowserToolbarAction] {
        toolbarActionIDs.compactMap(BrowserToolbarAction.init(rawValue:))
    }

    func toolLocation(for action: BrowserToolbarAction) -> BrowserToolLocation {
        if isInToolbar(action) { return .toolbar }
        if isInMoreMenu(action) { return .menu }
        return .hidden
    }

    func setToolLocation(_ location: BrowserToolLocation, for action: BrowserToolbarAction) {
        guard action.isLeanBuildUtility == false else { return }
        toolbarActionIDs.removeAll { $0 == action.rawValue }
        moreMenuActionIDs.remove(action.rawValue)

        switch location {
        case .toolbar:
            toolbarActionIDs.append(action.rawValue)
        case .menu:
            moreMenuActionIDs.insert(action.rawValue)
        case .hidden:
            break
        }
    }

    func moveToolbarAction(_ action: BrowserToolbarAction, offset: Int) {
        guard let currentIndex = toolbarActionIDs.firstIndex(of: action.rawValue) else { return }
        let destination = min(max(currentIndex + offset, 0), toolbarActionIDs.count - 1)
        guard destination != currentIndex else { return }
        let movedID = toolbarActionIDs.remove(at: currentIndex)
        toolbarActionIDs.insert(movedID, at: destination)
    }

    func moveToolbarAction(_ source: BrowserToolbarAction, before target: BrowserToolbarAction) {
        guard source != target,
              let sourceIndex = toolbarActionIDs.firstIndex(of: source.rawValue),
              let targetIndex = toolbarActionIDs.firstIndex(of: target.rawValue) else { return }
        let movedID = toolbarActionIDs.remove(at: sourceIndex)
        let adjustedTarget = sourceIndex < targetIndex ? targetIndex - 1 : targetIndex
        toolbarActionIDs.insert(movedID, at: max(0, min(adjustedTarget, toolbarActionIDs.count)))
    }

    func applyToolPreset(toolbar: [BrowserToolbarAction], menu: [BrowserToolbarAction]) {
        toolbarActionIDs = Self.normalizedToolbarActionIDs(toolbar.map(\.rawValue))
        let toolbarSet = Set(toolbarActionIDs)
        moreMenuActionIDs = Set(menu.map(\.rawValue)).subtracting(toolbarSet)
    }

    func setMoreMenuAction(_ action: BrowserToolbarAction, enabled: Bool) {
        guard action.isLeanBuildUtility == false else { return }
        if enabled {
            setToolLocation(.menu, for: action)
        } else {
            moreMenuActionIDs.remove(action.rawValue)
        }
        vault.save(moreMenuActionIDs, forKey: Self.StorageKey.moreMenuActionIDs)
    }

    func customIconName(for slot: BrowserCustomIconSlot) -> String {
        let value = customIconNames[slot.rawValue]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return value.isEmpty ? slot.defaultSymbol : value
    }

    func customIconName(for slot: BrowserCustomIconSlot?, fallback: String) -> String {
        guard let slot else { return fallback }
        let value = customIconNames[slot.rawValue]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return value.isEmpty ? fallback : value
    }

    func setCustomIconName(_ name: String, for slot: BrowserCustomIconSlot) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedName.isEmpty || trimmedName == slot.defaultSymbol {
            customIconNames.removeValue(forKey: slot.rawValue)
        } else {
            customIconNames[slot.rawValue] = trimmedName
        }
    }

    func customIconColor(for slot: BrowserCustomIconSlot?) -> Color? {
        guard let slot,
              let hex = customIconColorHexBySlot[slot.rawValue],
              Color.isValidHex(hex) else { return nil }
        return Color(hex: hex)
    }

    func setCustomIconColor(_ color: Color?, for slot: BrowserCustomIconSlot) {
        guard let color, let hex = color.hexString else {
            customIconColorHexBySlot.removeValue(forKey: slot.rawValue)
            return
        }
        customIconColorHexBySlot[slot.rawValue] = hex
    }

    func customIconImage(for slot: BrowserCustomIconSlot?) -> UIImage? {
        guard let slot,
              let data = customIconImageDataBySlot[slot.rawValue] else { return nil }
        return UIImage(data: data)
    }

    func hasCustomIconImage(for slot: BrowserCustomIconSlot) -> Bool {
        customIconImageDataBySlot[slot.rawValue] != nil
    }

    func setCustomIconImage(from url: URL, for slot: BrowserCustomIconSlot) {
        let didAccess = url.startAccessingSecurityScopedResource()
        defer {
            if didAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }

        guard let data = try? Data(contentsOf: url) else { return }
        setCustomIconImage(fromImageData: data, for: slot)
    }

    func setCustomIconImage(fromImageData rawData: Data, for slot: BrowserCustomIconSlot) {
        guard let data = Self.normalizedIconData(from: rawData) else { return }
        customIconImageDataBySlot[slot.rawValue] = data
    }

    func clearCustomIconImage(for slot: BrowserCustomIconSlot) {
        customIconImageDataBySlot.removeValue(forKey: slot.rawValue)
    }

    func resetCustomIcons() {
        customIconNames = [:]
        customIconColorHexBySlot = [:]
        customIconImageDataBySlot = [:]
    }

    func advancedConfigJSON(theme: BrowserTheme) -> String {
        let config = BrowserAdvancedConfig(
            topSearchBarEnabled: isTopSearchBarEnabled,
            topSearchBarPlacement: topSearchBarPlacement.rawValue,
            topSearchBarPositionX: topSearchBarPositionX,
            topSearchBarPositionY: topSearchBarPositionY,
            chromePlacement: chromePlacement.rawValue,
            sideTabsCollapsed: areSideTabsCollapsed,
            desktopZenModeEnabled: isDesktopZenModeEnabled,
            compactModeHidesQuickControls: compactModeHidesQuickControls,
            compactModeHidesTopSearchBar: compactModeHidesTopSearchBar,
            compactModeRevealsTopSearchBar: compactModeRevealsTopSearchBar,
            twoFingerDoubleTapCompactOnIPad: isTwoFingerDoubleTapCompactEnabledOnIPad,
            searchEngine: searchEngine.rawValue,
            customSearchTemplate: customSearchTemplate,
            bangs: bangs,
            newTabOpensSearch: newTabOpensSearch,
            autoCompactAfterSearchOnPhone: autoCompactAfterSearchOnPhone,
            darkReaderTheme: darkReaderTheme.rawValue,
            stylusCatppuccinEnabled: isStylusCatppuccinEnabled,
            fpsForcerEnabled: isFPSForcerEnabled,
            forcedFPS: forcedFPS,
            websiteResolutionScale: websiteResolutionScale,
            browserMusicEnabled: isBrowserMusicEnabled,
            browserMusicTrack: browserMusicTrack.rawValue,
            browserMusicVolume: browserMusicVolume,
            devExperienceOverride: isDeveloperModeEnabled ? deviceExperienceOverride.rawValue : BrowserDeviceExperienceOverride.automatic.rawValue,
            darkReaderEnabled: isDarkReaderEnabled,
            adBlockerEnabled: isAdBlockerEnabled,
            trackerBlockingLevel: trackerBlockingLevel.rawValue,
            blockScripts: isScriptBlockingEnabled,
            upgradeHTTPS: isHTTPSUpgradeEnabled,
            fingerprintProtection: isFingerprintProtectionEnabled,
            blockSocialMedia: isSocialBlockingEnabled,
            blockPopupAds: isPopupBlockingEnabled,
            stripTrackingParameters: isTrackingParameterStrippingEnabled,
            blockBounceTracking: isBounceTrackingProtectionEnabled,
            webRTCProtection: isWebRTCProtectionEnabled,
            websiteProtectionWhitelist: websiteProtectionWhitelist,
            regionTricksEnabled: isRegionTricksEnabled,
            regionTrickProfile: regionTrickProfile.rawValue,
            moreMenuActions: BrowserToolbarAction.allCases
                .filter { $0.isLeanBuildUtility == false }
                .map(\.rawValue)
                .filter { moreMenuActionIDs.contains($0) },
            toolbarActions: toolbarActionIDs,
            customIcons: customIconNames,
            customIconColors: customIconColorHexBySlot,
            tabBarTransparencyEnabled: theme.isTabBarTransparencyEnabled,
            tabBarTransparency: theme.tabBarTransparency,
            userBackgroundEnabled: theme.isUserBackgroundEnabled,
            colors: theme.colorConfig,
            gradientColors: theme.gradientColorConfig,
            gradientCoordinates: theme.gradientCoordinateConfig,
            gradientPositionsByToken: theme.gradientPositionConfigByToken,
            gradientCirclesByToken: theme.gradientCircleConfigByToken,
            customColors: theme.customColors
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        guard let data = try? encoder.encode(config),
              let text = String(data: data, encoding: .utf8) else {
            return "{}"
        }

        return text
    }

    func applyAdvancedConfigJSON(_ text: String, theme: BrowserTheme) throws {
        guard let data = text.data(using: .utf8) else {
            throw Self.configError("Config text is not valid UTF-8.")
        }

        let decoder = JSONDecoder()
        let config = try decoder.decode(BrowserAdvancedConfig.self, from: data)

        if let placement = BrowserChromePlacement(rawValue: config.chromePlacement) {
            chromePlacement = placement
        }

        if let selectedSearchEngine = BrowserSearchEngine(rawValue: config.searchEngine) {
            searchEngine = selectedSearchEngine
        }

        isTopSearchBarEnabled = config.topSearchBarEnabled
        if let topSearchBarPlacementValue = config.topSearchBarPlacement,
           let placement = BrowserToolbarPlacement(rawValue: topSearchBarPlacementValue) {
            topSearchBarPlacement = placement
        }
        if let topSearchBarPositionX = config.topSearchBarPositionX {
            self.topSearchBarPositionX = topSearchBarPositionX
            self.topSearchBarDraftX = Self.clampedUnit(topSearchBarPositionX)
        }
        if let topSearchBarPositionY = config.topSearchBarPositionY {
            self.topSearchBarPositionY = topSearchBarPositionY
            self.topSearchBarDraftY = Self.clampedUnit(topSearchBarPositionY)
            self.topSearchBarPlacement = Self.nearestTopSearchBarPlacement(for: topSearchBarPositionY)
        }
        areSideTabsCollapsed = config.sideTabsCollapsed
        isDesktopZenModeEnabled = config.desktopZenModeEnabled ?? false
        compactModeHidesQuickControls = config.compactModeHidesQuickControls ?? true
        compactModeHidesTopSearchBar = config.compactModeHidesTopSearchBar ?? true
        compactModeRevealsTopSearchBar = config.compactModeRevealsTopSearchBar ?? false
        isTwoFingerDoubleTapCompactEnabledOnIPad = config.twoFingerDoubleTapCompactOnIPad ?? false
        customSearchTemplate = config.customSearchTemplate
        if let importedBangs = config.bangs {
            bangs = BrowserBang.normalized(importedBangs)
            if bangs.isEmpty {
                bangs = BrowserBang.defaults
            }
            persistBangs()
        }
        newTabOpensSearch = config.newTabOpensSearch ?? true
        autoCompactAfterSearchOnPhone = config.autoCompactAfterSearchOnPhone ?? true
        if let darkReaderThemeValue = config.darkReaderTheme,
           let theme = BrowserDarkReaderTheme(rawValue: darkReaderThemeValue) {
            darkReaderTheme = theme
        }
        isStylusCatppuccinEnabled = config.stylusCatppuccinEnabled ?? false
        isFPSForcerEnabled = config.fpsForcerEnabled ?? false
        forcedFPS = Self.clampedForcedFPS(config.forcedFPS ?? 60)
        websiteResolutionScale = Self.clampedWebsiteResolutionScale(config.websiteResolutionScale ?? 1.0)
        isBrowserMusicEnabled = config.browserMusicEnabled ?? false
        if let browserMusicTrackValue = config.browserMusicTrack,
           let track = BrowserMusicTrack(rawValue: browserMusicTrackValue) {
            browserMusicTrack = track
        }
        browserMusicVolume = Self.clampedUnit(config.browserMusicVolume ?? 0.34)
        if isDeveloperModeEnabled,
           let devExperienceValue = config.devExperienceOverride,
           let override = BrowserDeviceExperienceOverride(rawValue: devExperienceValue) {
            setDeviceExperienceOverride(override)
        }
        if let trackerBlockingValue = config.trackerBlockingLevel,
           let level = BrowserTrackerBlockingLevel(rawValue: trackerBlockingValue) {
            trackerBlockingLevel = level
        }
        isScriptBlockingEnabled = config.blockScripts ?? false
        isHTTPSUpgradeEnabled = config.upgradeHTTPS ?? true
        isFingerprintProtectionEnabled = config.fingerprintProtection ?? true
        isSocialBlockingEnabled = config.blockSocialMedia ?? true
        isPopupBlockingEnabled = config.blockPopupAds ?? true
        isTrackingParameterStrippingEnabled = config.stripTrackingParameters ?? true
        isBounceTrackingProtectionEnabled = config.blockBounceTracking ?? true
        isWebRTCProtectionEnabled = config.webRTCProtection ?? true
        if let protectionWhitelist = config.websiteProtectionWhitelist {
            websiteProtectionWhitelist = BrowserWebsitePrivacyPolicy.normalizedDomains(protectionWhitelist)
                .filter { domain in
                    BrowserWebsitePrivacyPolicy.matches(host: domain, blockedDomains: websiteBlacklist) == false
                }
            applyWebsiteProtectionWhitelist()
        }
        if let regionProfileValue = config.regionTrickProfile,
           let profile = BrowserRegionTrickProfile(rawValue: regionProfileValue) {
            regionTrickProfile = profile
        }
        isRegionTricksEnabled = config.regionTricksEnabled ?? false
        toolbarActionIDs = Self.normalizedToolbarActionIDs(config.toolbarActions ?? Self.defaultToolbarActionIDs)
        moreMenuActionIDs = Set(config.moreMenuActions.filter { actionID in
            guard let action = BrowserToolbarAction(rawValue: actionID) else { return false }
            return action.isLeanBuildUtility == false
        }).subtracting(toolbarActionIDs)
        customIconNames = Self.sanitizedIconNames(config.customIcons)
        if let customIconColors = config.customIconColors {
            customIconColorHexBySlot = Self.sanitizedIconColors(customIconColors)
        }
        setDarkReaderEnabled(config.darkReaderEnabled)
        setAdBlockerEnabled(config.adBlockerEnabled)
        theme.applyAdvancedConfig(
            colors: config.colors,
            gradientColors: config.gradientColors,
            gradientCoordinates: config.gradientCoordinates,
            gradientPositionsByToken: config.gradientPositionsByToken,
            gradientCirclesByToken: config.gradientCirclesByToken,
            customColors: config.customColors,
            tabBarTransparencyEnabled: config.tabBarTransparencyEnabled,
            tabBarTransparency: config.tabBarTransparency,
            userBackgroundEnabled: config.userBackgroundEnabled
        )
    }

    func performToolbarAction(_ action: BrowserToolbarAction) {
        guard action.isLeanBuildUtility == false else { return }
        switch action {
        case .back:
            goBack()
        case .forward:
            goForward()
        case .reload:
            reloadOrStop()
        case .tabFinder:
            showAllTabs()
        case .tabFolders:
            showZenFolders()
        case .closeAllTabs:
            requestCloseAllTabs()
        case .compact:
            toggleCompactMode()
        case .containedTabs:
            showContainedTabs()
        case .downloadCurrent:
            downloadSelectedTab()
        case .history:
            isHistoryPresented = true
        case .downloads:
            isDownloadsPresented = true
        case .browserMusic:
            toggleBrowserMusic()
        case .websiteMode:
            cycleWebsiteDisplayMode()
        case .vpnCountry:
            isVPNPresented = true
        case .passwordManager:
            isPasswordManagerPresented = true
        case .placement:
            let placements = BrowserChromePlacement.allCases
            if let index = placements.firstIndex(of: chromePlacement) {
                chromePlacement = placements[(index + 1) % placements.count]
            }
        case .settings:
            isSettingsPresented = true
        }
    }

    func searchResults(for rawQuery: String) -> [BrowserSearchResult] {
        let query = rawQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        let canShowHistory = selectedTab?.isPrivate != true

        if query.isEmpty {
            guard canShowHistory else { return [] }
            return history.prefix(6).compactMap { item in
                guard let url = item.url else { return nil }
                return BrowserSearchResult(
                    title: item.title,
                    subtitle: item.urlString,
                    symbolName: "clock.arrow.circlepath",
                    url: url
                )
            }
        }

        var results: [BrowserSearchResult] = []

        func appendUnique(_ result: BrowserSearchResult) {
            if results.contains(where: { $0.url == result.url }) == false {
                results.append(result)
            }
        }

        if let resolvedBang = BrowserBang.resolvedDestination(for: query, bangs: bangs) {
            appendUnique(
                BrowserSearchResult(
                    title: resolvedBang.query.isEmpty
                        ? "Open \(resolvedBang.bang.name)"
                        : "Search \(resolvedBang.bang.name) for \(resolvedBang.query)",
                    subtitle: "\(resolvedBang.bang.displayShortcut)  \(resolvedBang.url.absoluteString)",
                    symbolName: "bolt.fill",
                    url: resolvedBang.url
                )
            )
        } else if query.hasPrefix("!") {
            let command = BrowserBang.sanitizedShortcut(String(query.dropFirst().split(whereSeparator: { $0.isWhitespace }).first ?? ""))
            for bang in bangs where command.isEmpty || bang.shortcut.hasPrefix(command) {
                guard let url = bang.searchURL(for: "") else { continue }
                appendUnique(
                    BrowserSearchResult(
                        title: "\(bang.displayShortcut)  \(bang.name)",
                        subtitle: "Type a search after \(bang.displayShortcut)",
                        symbolName: "bolt",
                        url: url
                    )
                )
            }
        }

        let destination = BrowserTab.destinationURL(
            from: query,
            searchEngine: searchEngine,
            customSearchTemplate: customSearchTemplate,
            bangs: bangs
        )
        let searchURL = searchEngine.searchURL(for: query, customTemplate: customSearchTemplate)

        appendUnique(
            BrowserSearchResult(
                title: "Search \(searchEngine.title) for \(query)",
                subtitle: searchURL.absoluteString,
                symbolName: "magnifyingglass",
                url: searchURL
            )
        )

        if destination != searchURL {
            appendUnique(
                BrowserSearchResult(
                    title: "Open \(destination.host ?? query)",
                    subtitle: destination.absoluteString,
                    symbolName: "arrow.up.right.square",
                    url: destination
                )
            )
        }

        let quickSearches = [
            ("Images", "photo", "\(query) images"),
            ("News", "newspaper", "\(query) news"),
            ("Videos", "play.rectangle", "\(query) videos"),
            ("Maps", "map", "\(query) map")
        ]

        for quickSearch in quickSearches {
            appendUnique(
                BrowserSearchResult(
                    title: "\(quickSearch.0) for \(query)",
                    subtitle: "Search \(searchEngine.title)",
                    symbolName: quickSearch.1,
                    url: searchEngine.searchURL(for: quickSearch.2, customTemplate: customSearchTemplate)
                )
            )
        }

        if canShowHistory {
            let lowercasedQuery = query.lowercased()
            for item in history where results.count < 12 {
                let titleMatches = item.title.lowercased().contains(lowercasedQuery)
                let urlMatches = item.urlString.lowercased().contains(lowercasedQuery)
                guard (titleMatches || urlMatches), let url = item.url else { continue }
                appendUnique(
                    BrowserSearchResult(
                        title: item.title,
                        subtitle: item.urlString,
                        symbolName: "clock.arrow.circlepath",
                        url: url
                    )
                )
            }
        }

        return Array(results.prefix(12))
    }

    func openSearchResult(_ result: BrowserSearchResult, autoCompactChrome: Bool = false) {
        floatingSearchText = result.url.absoluteString
        shouldSelectFloatingSearchText = false
        selectedTab?.addressText = result.url.absoluteString
        selectedTab?.load(result.url)
        isFloatingSearchPresented = false
        if shouldCompactAfterSearch(autoCompactChrome: autoCompactChrome) {
            enterCompactMode()
        }
    }

    private func shouldCompactAfterSearch(autoCompactChrome: Bool) -> Bool {
        autoCompactChrome || (isPhoneExperienceActive && autoCompactAfterSearchOnPhone)
    }

    func requestWebFileImport(allowsMultipleSelection: Bool, completion: @escaping ([URL]?) -> Void) {
        pendingWebFileImportCompletion?(nil)
        pendingWebFileImportCompletion = completion
        allowsMultipleWebFileImport = allowsMultipleSelection
        isWebFileImporterPresented = true
    }

    func completeWebFileImport(_ result: Result<[URL], Error>) {
        guard let completion = pendingWebFileImportCompletion else { return }
        pendingWebFileImportCompletion = nil
        allowsMultipleWebFileImport = false

        switch result {
        case .success(let urls):
            completion(urls)
        case .failure:
            completion(nil)
        }
    }

    func openAIShortcut(_ assistant: AIAssistant) {
        openTab(startURL: assistant.url)
    }

    private func aiPrompt(action: BrowserAIAction, title: String, urlText: String, pageText: String) -> String {
        let trimmedPageText = pageText.trimmingCharacters(in: .whitespacesAndNewlines)
        let context = trimmedPageText.isEmpty ? "No readable page text was available." : trimmedPageText
        return """
        You are Glide AI inside a private browser. \(action.instruction)

        Page title:
        \(title)

        Page URL:
        \(urlText)

        Page context:
        \(context)
        """
    }

    func openLocalAI() {
        guard let url = Self.normalizedURL(from: localAIURLText) else {
            isLocalAIImporterPresented = true
            return
        }

        openTab(startURL: url)
    }

    func openAddOnLibrary(_ library: BrowserAddOnLibrary) {
        openTab(startURL: library.url)
        isAddOnsPresented = false
    }

    func importWebExtension(from result: Result<[URL], Error>) {
        do {
            guard let sourceURL = try result.get().first else { return }
            webExtensionImportMessage = "Importing \(sourceURL.lastPathComponent)..."
            let didAccess = sourceURL.startAccessingSecurityScopedResource()
            defer {
                if didAccess {
                    sourceURL.stopAccessingSecurityScopedResource()
                }
            }

            let packageData = try Data(contentsOf: sourceURL)
            let sourceFilename = sourceURL.lastPathComponent
            Task {
                do {
                    let importedExtension = try await Task.detached(priority: .utility) {
                        try BrowserWebExtensionPackageReader.installableExtension(
                            from: packageData,
                            sourceFilename: sourceFilename
                        )
                    }.value

                    if let existingIndex = installedWebExtensions.firstIndex(where: {
                        $0.extensionIdentifier == importedExtension.extensionIdentifier
                    }) {
                        let wasEnabled = installedWebExtensions[existingIndex].isEnabled
                        var replacement = importedExtension
                        replacement.isEnabled = wasEnabled
                        installedWebExtensions[existingIndex] = replacement
                        webExtensionImportMessage = "Updated \(replacement.displayName)."
                    } else {
                        installedWebExtensions.insert(importedExtension, at: 0)
                        webExtensionImportMessage = "Installed \(importedExtension.displayName)."
                    }
                } catch {
                    webExtensionImportMessage = error.localizedDescription
                }
            }
        } catch {
            webExtensionImportMessage = error.localizedDescription
        }
    }

    func setWebExtension(_ extensionID: BrowserWebExtension.ID, enabled: Bool) {
        guard let index = installedWebExtensions.firstIndex(where: { $0.id == extensionID }) else { return }
        installedWebExtensions[index].isEnabled = enabled
        webExtensionImportMessage = enabled
            ? "Enabled \(installedWebExtensions[index].displayName)."
            : "Disabled \(installedWebExtensions[index].displayName)."
    }

    func deleteWebExtension(_ extensionID: BrowserWebExtension.ID) {
        guard let index = installedWebExtensions.firstIndex(where: { $0.id == extensionID }) else { return }
        let removed = installedWebExtensions.remove(at: index)
        webExtensionImportMessage = "Removed \(removed.displayName)."
    }

    func reloadWebExtensions() {
        applyWebExtensionsToTabs(reloadAfterChange: true)
        let enabledCount = installedWebExtensions.filter(\.isEnabled).count
        webExtensionImportMessage = enabledCount == 1
            ? "Reloaded 1 enabled extension."
            : "Reloaded \(enabledCount) enabled extensions."
    }

    func importLocalAI(name: String, urlText: String) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        localAIName = trimmedName.isEmpty ? "Local AI" : trimmedName
        localAIURLText = urlText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func saveVPNProfile(_ profile: CustomVPNProfile) {
        vpnProfile = profile
        selectedVPNCountry = profile.countryName
        vpnStatusMessage = profile.isConfigured ? "Custom VPN profile saved." : "Custom VPN profile not configured."
    }

    func changeVPNCountry(using profile: CustomVPNProfile) {
        var preparedProfile = profile
        if preparedProfile.countryName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            preparedProfile.countryName = selectedVPNCountry
        }
        preparedProfile.isEnabled = true
        saveVPNProfile(preparedProfile)

        guard preparedProfile.isConfigured else {
            vpnStatusMessage = "Add a real VPN server for \(preparedProfile.countryName.isEmpty ? "that country" : preparedProfile.countryName) before changing country."
            return
        }

        vpnStatusMessage = "Changing country to \(preparedProfile.countryName)..."
        Task { [weak self] in
            do {
                try await CustomVPNController.install(profile: preparedProfile)
                try await CustomVPNController.connect()
                await MainActor.run {
                    self?.vpnStatusMessage = "Country change requested for \(preparedProfile.countryName)."
                }
            } catch {
                await MainActor.run {
                    self?.vpnStatusMessage = "\(error.localizedDescription) Add the Personal VPN entitlement and a working server for this country."
                }
            }
        }
    }

    func installVPNProfile() {
        vpnStatusMessage = "Saving custom VPN profile to iOS..."
        let profile = vpnProfile

        Task {
            do {
                try await CustomVPNController.install(profile: profile)
                vpnStatusMessage = profile.isEnabled
                    ? "Custom VPN profile saved and enabled in iOS."
                    : "Custom VPN profile saved in iOS."
            } catch {
                vpnStatusMessage = "\(error.localizedDescription) Add the Personal VPN entitlement when signing if iOS rejects it."
            }
        }
    }

    func connectVPNProfile() {
        vpnStatusMessage = "Connecting custom VPN..."

        Task {
            do {
                try await CustomVPNController.connect()
                vpnStatusMessage = "Custom VPN connection requested."
            } catch {
                vpnStatusMessage = "\(error.localizedDescription) Make sure the VPN profile is saved, entitled, and points at a real server."
            }
        }
    }

    func disconnectVPNProfile() {
        CustomVPNController.disconnect()
        vpnStatusMessage = "Custom VPN disconnect requested."
    }

    func requestPrivateModeToggle() {
        privateModeAuthMessage = ""

        if isPrivateModeEnabled {
            leavePrivateMode()
            return
        }

        privateModeAuthAction = .enter
        isPrivateModeAuthPresented = true
    }

    func completePrivateModeAuthentication() {
        switch privateModeAuthAction {
        case .enter:
            enterPrivateMode()
        case .exit:
            leavePrivateMode()
        }
        privateModeAuthMessage = ""
        isPrivateModeAuthPresented = false
    }

    func enterPrivateMode() {
        isPrivateModeEnabled = true
        isHistoryPresented = false
        isContainedBrowserPresented = false
        isTabFinderPresented = false
        let shouldOpenSearchAfterEntry: Bool

        if privateTabs.isEmpty {
            openTab(private: true)
            shouldOpenSearchAfterEntry = newTabOpensSearch
        } else if selectedTab?.isPrivate != true {
            selectedTabID = privateTabs.last?.id
            shouldOpenSearchAfterEntry = false
        } else {
            shouldOpenSearchAfterEntry = false
        }

        floatingSearchText = selectedTab?.addressText ?? ""
        shouldSelectFloatingSearchText = shouldOpenSearchAfterEntry
        isFloatingSearchPresented = shouldOpenSearchAfterEntry
    }

    func leavePrivateMode() {
        isPrivateModeEnabled = false
        isFloatingSearchPresented = false
        isTabFinderPresented = false

        if selectedTab?.isPrivate == true {
            if let normalTab = normalTabs.last {
                selectedTabID = normalTab.id
            } else {
                selectedTabID = openTab().id
            }
        }

        floatingSearchText = selectedTab?.addressText ?? ""
    }

    func beginTopSearchBarMove() {
        isTopSearchBarEnabled = true
        topSearchBarDraftX = topSearchBarPositionX
        topSearchBarDraftY = topSearchBarPositionY
        isTopSearchBarMoveMode = true
    }

    func setTopSearchBarPlacement(_ placement: BrowserToolbarPlacement) {
        isTopSearchBarEnabled = true
        topSearchBarPlacement = placement
        topSearchBarPositionY = Self.defaultTopSearchBarY(for: placement)
        topSearchBarDraftX = topSearchBarPositionX
        topSearchBarDraftY = topSearchBarPositionY
    }

    func updateTopSearchBarDraft(x: Double, y: Double) {
        topSearchBarDraftX = Self.clampedUnit(x)
        topSearchBarDraftY = Self.clampedUnit(y)
    }

    func saveTopSearchBarMove() {
        topSearchBarPositionX = topSearchBarDraftX
        topSearchBarPositionY = topSearchBarDraftY
        topSearchBarPlacement = Self.nearestTopSearchBarPlacement(for: topSearchBarDraftY)
        isTopSearchBarMoveMode = false
    }

    func cancelTopSearchBarMove() {
        topSearchBarDraftX = topSearchBarPositionX
        topSearchBarDraftY = topSearchBarPositionY
        isTopSearchBarMoveMode = false
    }

    func resetTopSearchBarPosition() {
        topSearchBarDraftX = 0.5
        topSearchBarDraftY = 0.0
    }

    var displayedTopSearchBarX: Double {
        isTopSearchBarMoveMode ? topSearchBarDraftX : topSearchBarPositionX
    }

    var displayedTopSearchBarY: Double {
        isTopSearchBarMoveMode ? topSearchBarDraftY : topSearchBarPositionY
    }

    func resetPrivacySettings() {
        setAdBlockerEnabled(true)
        trackerBlockingLevel = .aggressive
        isScriptBlockingEnabled = false
        isHTTPSUpgradeEnabled = true
        isFingerprintProtectionEnabled = true
        isSocialBlockingEnabled = true
        isPopupBlockingEnabled = true
        isTrackingParameterStrippingEnabled = true
        isBounceTrackingProtectionEnabled = true
        isWebRTCProtectionEnabled = true
        isRegionTricksEnabled = false
        regionTrickProfile = .unitedStates
        saveVPNProfile(.empty)
        clearWebsiteBlacklist()
        clearWebsiteProtectionWhitelist()
    }

    func enableGlideMaxProtection() {
        setAdBlockerEnabled(true)
        trackerBlockingLevel = .aggressive
        isScriptBlockingEnabled = false
        isHTTPSUpgradeEnabled = true
        isFingerprintProtectionEnabled = true
        isSocialBlockingEnabled = true
        isPopupBlockingEnabled = true
        isTrackingParameterStrippingEnabled = true
        isBounceTrackingProtectionEnabled = true
        isWebRTCProtectionEnabled = true
    }

    func enableGlideGhostMode() {
        enableGlideMaxProtection()
        isScriptBlockingEnabled = true
        isRegionTricksEnabled = true
        regionTrickProfile = .germany
        privacyStatusMessage = "Ghost Mode enabled. Scripts are blocked, so some sites may need Shields Max instead."
    }

    func clearPrivateBrowsingData() {
        clearHistory()
        clearDownloads()
        SecureBrowserVault.clearWebsiteDataForPrivacy()
        privacyStatusMessage = "Cleared history, downloads, cookies, caches, and website data."
    }

    func resetLayoutSettings() {
        chromePlacement = .floating
        areSideTabsCollapsed = true
        isDesktopZenModeEnabled = false
        arePageControlsCollapsed = false
        compactModeHidesQuickControls = true
        compactModeHidesTopSearchBar = true
        compactModeRevealsTopSearchBar = false
        isTwoFingerDoubleTapCompactEnabledOnIPad = false
        sideChromeWidthFraction = 0.34
        pageControlsOffsetX = 0
        pageControlsOffsetY = 0
        isChromeWidthResizeMode = false
        isPageControlsMoveMode = false
        isTopSearchBarEnabled = true
        topSearchBarPlacement = .top
        topSearchBarPositionX = 0.5
        topSearchBarPositionY = 0.0
        topSearchBarDraftX = topSearchBarPositionX
        topSearchBarDraftY = topSearchBarPositionY
        isTopSearchBarMoveMode = false
        moreMenuActionIDs = Self.defaultMoreMenuActionIDs
        toolbarActionIDs = Self.defaultToolbarActionIDs
        allTabsLayout = .grid
        allTabsDensity = .comfortable
        allTabsSortOrder = .browserOrder
        allTabsShowsContainedTabs = true
        allTabsShowsPrivateSummary = true
    }

    func resetBrowsingSettings() {
        searchEngine = .duckDuckGo
        customSearchTemplate = BrowserSearchEngine.defaultCustomTemplate
        resetBangs()
        newTabOpensSearch = true
        autoCompactAfterSearchOnPhone = true
        setBrowserResolutionPreset(.automatic)
        websiteResolutionScale = 1.0
        localAIName = "Local AI"
        localAIURLText = ""
    }

    func addBang() {
        var suffix = bangs.count + 1
        var shortcut = "new"
        while bangs.contains(where: { $0.shortcut == shortcut }) {
            shortcut = "new\(suffix)"
            suffix += 1
        }
        bangs.append(
            BrowserBang(
                shortcut: shortcut,
                name: "New bang",
                urlTemplate: "https://example.com/search?q={query}"
            )
        )
        bangStatusMessage = "Added !\(shortcut)."
        persistBangs()
    }

    func updateBang(id: UUID, shortcut: String? = nil, name: String? = nil, urlTemplate: String? = nil) {
        guard let index = bangs.firstIndex(where: { $0.id == id }) else { return }
        let current = bangs[index]
        let updated = BrowserBang(
            id: current.id,
            shortcut: shortcut ?? current.shortcut,
            name: name ?? current.name,
            urlTemplate: urlTemplate ?? current.urlTemplate
        )
        bangs[index] = updated
        let duplicates = bangs.filter { $0.shortcut == updated.shortcut }.count
        bangStatusMessage = duplicates > 1
            ? "!\(updated.shortcut) is duplicated. The first match will be used."
            : "Saved \(updated.displayShortcut)."
        persistBangs()
    }

    func removeBang(id: UUID) {
        bangs.removeAll { $0.id == id }
        bangStatusMessage = "Bang removed."
        persistBangs()
    }

    func resetBangs() {
        bangs = BrowserBang.defaults
        bangStatusMessage = "Default bangs restored."
        persistBangs()
    }

    func resetGlideMods() {
        setDarkReaderEnabled(false)
        darkReaderTheme = .zenCopy
        isStylusCatppuccinEnabled = false
        isFPSForcerEnabled = false
        forcedFPS = 60
        isBrowserMusicEnabled = false
        browserMusicTrack = .focus
        browserMusicVolume = 0.34
        browserMusicImportMessage = ""
        setDeveloperModeEnabled(false)
        isAddOnsPresented = false
        isAdvancedConfigPresented = false
    }

    func resetFolders() {
        tabFolders = []
        collapsedTabFolderIDs = []
        for tab in normalTabs {
            tab.folderID = nil
        }
        persistOpenTabs()
    }

    func resetToDefaults() {
        resetLayoutSettings()
        resetBrowsingSettings()
        resetGlideMods()
        resetPrivacySettings()
        resetFolders()
        resetCustomIcons()
        essentials = []
        saveEssentials()
    }

    private func configure(_ tab: BrowserTab) {
        tab.onNavigationFinished = { [weak self] tab in
            self?.recordVisit(from: tab)
        }
        tab.onDownloadUpdated = { [weak self] item in
            self?.updateDownload(item)
        }
        tab.onTwoFingerSwipe = { [weak self] deltaX, deltaY in
            self?.handleTwoFingerSwipe(deltaX: deltaX, deltaY: deltaY)
        }
        tab.onThreeFingerSwipe = { [weak self] deltaX in
            self?.handleThreeFingerSwipe(deltaX: deltaX)
        }
        tab.onFilePickerRequested = { [weak self] allowsMultipleSelection, completion in
            self?.requestWebFileImport(allowsMultipleSelection: allowsMultipleSelection, completion: completion)
        }
    }

    private func configureContained(_ tab: BrowserTab) {
        tab.onDownloadUpdated = { [weak self] item in
            self?.updateDownload(item)
        }
        tab.onTwoFingerSwipe = { [weak self] deltaX, deltaY in
            self?.handleTwoFingerSwipe(deltaX: deltaX, deltaY: deltaY)
        }
        tab.onThreeFingerSwipe = { [weak tab] deltaX in
            if deltaX > 0 {
                tab?.goBack()
            } else {
                tab?.goForward()
            }
        }
        tab.onFilePickerRequested = { [weak self] allowsMultipleSelection, completion in
            self?.requestWebFileImport(allowsMultipleSelection: allowsMultipleSelection, completion: completion)
        }
    }

    private func applyDeveloperOptionsToTabs() {
        for tab in tabs {
            applyDeveloperOptions(to: tab)
        }
        for tab in containedTabs {
            applyDeveloperOptions(to: tab)
        }
    }

    private func applyDeveloperOptions(to tab: BrowserTab) {
        tab.setWebInspectorEnabled(isDeveloperModeEnabled && isWebInspectorEnabled)
    }

    private func applyWebExtensionsToTabs(reloadAfterChange: Bool) {
        for tab in tabs {
            tab.setWebExtensions(installedWebExtensions, reloadAfterChange: reloadAfterChange)
        }
        for tab in containedTabs {
            tab.setWebExtensions(installedWebExtensions, reloadAfterChange: reloadAfterChange)
        }
    }

    private func recordVisit(from tab: BrowserTab) {
        objectWillChange.send()
        guard tab.isPrivate == false,
              let url = tab.url,
              Self.shouldPersist(url: url) else {
            return
        }

        if isWebsiteBlacklisted(url) {
            let matchingDomains = websiteBlacklist.filter { domain in
                BrowserWebsitePrivacyPolicy.matches(host: url.host, blockedDomains: [domain])
            }
            BrowserWebsitePrivacyController.shared.purgeWebsiteData(for: matchingDomains)
            return
        }

        let title = tab.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let item = BrowserHistoryItem(
            title: title.isEmpty ? url.absoluteString : title,
            urlString: url.absoluteString,
            faviconURLString: tab.pageIconURLString,
            accentColorHex: tab.pageThemeColorHex
        )

        history.removeAll { $0.urlString == item.urlString }
        history.insert(item, at: 0)
        if history.count > 250 {
            history = Array(history.prefix(250))
        }

        var didRefreshEssential = false
        let visitedDomain = BrowserWebsitePrivacyPolicy.domain(for: url)
        for index in essentials.indices where BrowserWebsitePrivacyPolicy.domain(for: essentials[index].url) == visitedDomain {
            if let icon = tab.pageIconURLString, essentials[index].faviconURLString != icon {
                essentials[index].faviconURLString = icon
                didRefreshEssential = true
            }
            if let color = tab.pageThemeColorHex, essentials[index].accentColorHex != color {
                essentials[index].accentColorHex = color
                didRefreshEssential = true
            }
        }

        saveHistory()
        if didRefreshEssential {
            saveEssentials()
        }
        persistOpenTabs()
    }

    private func applyWebsiteBlacklist(purging domains: [String] = []) {
        vault.save(websiteBlacklist, forKey: BrowserWebsitePrivacyPolicy.storageKey)
        for tab in tabs {
            tab.setWebsiteBlacklist(websiteBlacklist)
        }
        for tab in containedTabs {
            tab.setWebsiteBlacklist(websiteBlacklist)
        }
        BrowserWebsitePrivacyController.shared.update(blockedDomains: websiteBlacklist)
        if domains.isEmpty == false {
            BrowserWebsitePrivacyController.shared.purgeWebsiteData(for: domains)
        }
    }

    private func applyWebsiteProtectionWhitelist() {
        vault.save(
            websiteProtectionWhitelist,
            forKey: BrowserWebsitePrivacyPolicy.protectionWhitelistStorageKey
        )
        for tab in tabs {
            tab.setWebsiteProtectionWhitelist(websiteProtectionWhitelist)
        }
        for tab in containedTabs {
            tab.setWebsiteProtectionWhitelist(websiteProtectionWhitelist)
        }
    }

    private static func privacyDomainsConflict(_ lhs: String, _ rhs: String) -> Bool {
        lhs == rhs || lhs.hasSuffix(".\(rhs)") || rhs.hasSuffix(".\(lhs)")
    }

    private func persistOpenTabs() {
        let normalTabs = tabs.filter { $0.isPrivate == false }
        let selectedNormalID: BrowserTab.ID?
        if let selectedTabID = selectedTabID,
           normalTabs.contains(where: { $0.id == selectedTabID }) {
            selectedNormalID = selectedTabID
        } else {
            selectedNormalID = normalTabs.first?.id
        }

        let persistedTabs = normalTabs.compactMap { tab -> PersistedBrowserTab? in
            guard let url = tab.url, Self.shouldPersist(url: url) else { return nil }
            return PersistedBrowserTab(
                title: tab.title,
                urlString: url.absoluteString,
                isSelected: selectedNormalID.map { $0 == tab.id } ?? false,
                folderID: tab.folderID,
                usesDevWebKitProfile: tab.usesDevWebKitProfile ? true : nil
            )
        }

        vault.save(persistedTabs, forKey: Self.StorageKey.openTabs)
    }

    private func saveHistory() {
        vault.save(history, forKey: Self.StorageKey.history)
    }

    private func saveEssentials() {
        vault.save(essentials, forKey: Self.StorageKey.essentials)
    }

    private func saveTabFolders() {
        vault.save(tabFolders, forKey: Self.StorageKey.tabFolders)
    }

    private func updateDownload(_ item: BrowserDownloadItem) {
        if item.state == .finished,
           item.isEncrypted == false,
           item.localURL.deletingLastPathComponent().lastPathComponent == "GlideIncomingDownloads" {
            finalizeDownloadedFile(item, plaintextURL: item.localURL)
            return
        }

        upsertDownload(item)
    }

    private func upsertDownload(_ item: BrowserDownloadItem) {
        downloads.removeAll { existing in
            existing.id == item.id
                || existing.localPath == item.localPath
                || (item.encryptedLocalPath != nil && existing.encryptedLocalPath == item.encryptedLocalPath)
        }
        downloads.insert(item, at: 0)
        if downloads.count > 100 {
            downloads = Array(downloads.prefix(100))
        }
        saveDownloads()
    }

    private func download(url: URL, suggestedFilename: String? = nil) {
        do {
            let destination = try BrowserTab.downloadDestination(for: BrowserTab.downloadFilename(for: url, suggestedFilename: suggestedFilename))
            let item = BrowserDownloadItem(
                filename: destination.lastPathComponent,
                sourceURLString: url.absoluteString,
                localPath: destination.path,
                state: .inProgress
            )
            updateDownload(item)
            downloadStatusMessage = "Downloading \(item.filename)..."
            isDownloadsPresented = true

            Task { [weak self] in
                do {
                    let (temporaryURL, _) = try await URLSession.shared.download(from: url)
                    await MainActor.run {
                        self?.finalizeDownloadedFile(item, plaintextURL: temporaryURL, displayURL: destination)
                    }
                } catch {
                    await MainActor.run {
                        var failed = item
                        failed.state = .failed
                        failed.errorMessage = error.localizedDescription
                        self?.downloadStatusMessage = error.localizedDescription
                        self?.updateDownload(failed)
                    }
                }
            }
        } catch {
            downloadStatusMessage = error.localizedDescription
            isDownloadsPresented = true
        }
    }

    private func finalizeDownloadedFile(_ item: BrowserDownloadItem, plaintextURL: URL, displayURL: URL? = nil) {
        var finished = item

        do {
            guard FileManager.default.fileExists(atPath: plaintextURL.path) else {
                throw Self.downloadError("The temporary download file is missing.")
            }

            let presentationURL: URL
            if let displayURL {
                presentationURL = displayURL
            } else {
                presentationURL = try BrowserTab.downloadDestination(for: item.filename)
            }
            if FileManager.default.fileExists(atPath: presentationURL.path) {
                try FileManager.default.removeItem(at: presentationURL)
            }
            try FileManager.default.moveItem(at: plaintextURL, to: presentationURL)
            #if os(iOS)
            try? FileManager.default.setAttributes([.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication], ofItemAtPath: presentationURL.path)
            #endif

            let attributes = try? FileManager.default.attributesOfItem(atPath: presentationURL.path)
            let byteCount = (attributes?[.size] as? NSNumber)?.int64Value
            finished.localPath = presentationURL.path
            finished.state = .finished
            finished.errorMessage = nil
            finished.originalByteCount = byteCount

            downloadStatusMessage = "Saved \(finished.filename) to Downloads."
            upsertDownload(finished)
        } catch {
            try? FileManager.default.removeItem(at: plaintextURL)
            finished.state = .failed
            finished.errorMessage = "Download could not be saved: \(error.localizedDescription)"
            downloadStatusMessage = finished.errorMessage ?? error.localizedDescription
            upsertDownload(finished)
        }
    }

    private func deleteDownloadFiles(for item: BrowserDownloadItem) {
        var paths = Set<String>()
        paths.insert(item.localPath)
        if let encryptedLocalPath = item.encryptedLocalPath {
            paths.insert(encryptedLocalPath)
        }

        for path in paths where path.isEmpty == false && FileManager.default.fileExists(atPath: path) {
            try? FileManager.default.removeItem(at: URL(fileURLWithPath: path))
        }
    }

    private func encryptedDownloadURL(for item: BrowserDownloadItem) throws -> URL {
        let directory = try Self.encryptedDownloadsDirectory()
        let filename = "\(item.id.uuidString)-\(Self.safeDownloadFilename(item.filename)).glidevault"
        return directory.appendingPathComponent(filename)
    }

    private static func encryptedDownloadsDirectory() throws -> URL {
        let applicationSupport = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directory = applicationSupport.appendingPathComponent("GlideEncryptedDownloads", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private static let temporaryExportDirectoryName = "GlideExportCopies"

    private static func temporaryExportURL(for filename: String) throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(temporaryExportDirectoryName, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent("\(UUID().uuidString)-\(safeDownloadFilename(filename))")
    }

    nonisolated private static func safeDownloadFilename(_ filename: String) -> String {
        let trimmed = filename.trimmingCharacters(in: .whitespacesAndNewlines)
        let fallback = trimmed.isEmpty ? "download" : trimmed
        let illegal = CharacterSet(charactersIn: "/\\?%*|\"<>:")
        return fallback
            .components(separatedBy: illegal)
            .joined(separator: "-")
    }

    nonisolated private static func importedBrowserMusicURL(for filename: String) -> URL? {
        let trimmed = filename.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false,
              let directory = try? browserMusicImportsDirectory() else { return nil }
        let url = directory.appendingPathComponent(trimmed, isDirectory: false)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    nonisolated private static func copyImportedBrowserMusicFile(from sourceURL: URL) throws -> String {
        let didAccess = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if didAccess {
                sourceURL.stopAccessingSecurityScopedResource()
            }
        }

        let directory = try browserMusicImportsDirectory()
        let fileManager = FileManager.default
        let baseName = safeDownloadFilename(sourceURL.deletingPathExtension().lastPathComponent)
        let extensionText = safeDownloadFilename(sourceURL.pathExtension)
        let filename = extensionText.isEmpty
            ? "\(UUID().uuidString)-\(baseName)"
            : "\(UUID().uuidString)-\(baseName).\(extensionText)"
        let destination = directory.appendingPathComponent(filename, isDirectory: false)

        if fileManager.fileExists(atPath: destination.path) {
            try fileManager.removeItem(at: destination)
        }
        try fileManager.copyItem(at: sourceURL, to: destination)
        return filename
    }

    nonisolated private static func removeImportedBrowserMusicFile(named filename: String) {
        guard let url = importedBrowserMusicURL(for: filename) else { return }
        try? FileManager.default.removeItem(at: url)
    }

    nonisolated private static func browserMusicImportsDirectory() throws -> URL {
        let fileManager = FileManager.default
        let root = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let directory = root.appendingPathComponent("BrowserMusic", isDirectory: true)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    nonisolated private static func displayName(forImportedBrowserMusicFilename filename: String) -> String {
        let trimmed = filename.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return "No imported audio" }
        return trimmed.replacingOccurrences(
            of: #"^[0-9A-Fa-f-]{36}-"#,
            with: "",
            options: .regularExpression
        )
    }

    private static func downloadError(_ message: String) -> NSError {
        NSError(domain: "GlideDownloads", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
    }

    private static func configError(_ message: String) -> NSError {
        NSError(domain: "GlideAdvancedConfig", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
    }

    private static func sanitizedIconNames(_ names: [String: String]) -> [String: String] {
        var values: [String: String] = [:]

        for slot in BrowserCustomIconSlot.allCases {
            let value = names[slot.rawValue]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if value.isEmpty == false, value != slot.defaultSymbol {
                values[slot.rawValue] = value
            }
        }

        return values
    }

    private static func sanitizedIconColors(_ colors: [String: String]) -> [String: String] {
        var values: [String: String] = [:]

        for slot in BrowserCustomIconSlot.allCases {
            guard let hex = colors[slot.rawValue],
                  Color.isValidHex(hex),
                  let normalizedHex = Color(hex: hex).hexString else { continue }
            values[slot.rawValue] = normalizedHex
        }

        return values
    }

    private static func sanitizedIconImageData(_ imageData: [String: Data]) -> [String: Data] {
        var values: [String: Data] = [:]

        for slot in BrowserCustomIconSlot.allCases {
            if let data = imageData[slot.rawValue], UIImage(data: data) != nil {
                values[slot.rawValue] = data
            }
        }

        return values
    }

    private static func normalizedIconData(from rawData: Data) -> Data? {
        guard let image = UIImage(data: rawData) else { return nil }

        let maxSide: CGFloat = 256
        let longestSide = max(image.size.width, image.size.height)
        let scale = longestSide > maxSide ? maxSide / longestSide : 1
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false

        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        let normalizedImage = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }

        return normalizedImage.pngData()
    }

    private func saveDownloads() {
        vault.save(downloads, forKey: Self.StorageKey.downloads)
    }

    private func savePasswordEntries() {
        vault.save(passwordEntries, forKey: Self.StorageKey.passwordEntries)
    }

    private func persistVPNProfile() {
        vault.save(vpnProfile, forKey: Self.StorageKey.vpnProfile)
    }

    private func migrateLoadedStateToEncryptedVault() {
        vault.save(chromePlacement.rawValue, forKey: Self.StorageKey.chromePlacement)
        vault.save(areSideTabsCollapsed, forKey: Self.StorageKey.sideTabsCollapsed)
        vault.save(isDesktopZenModeEnabled, forKey: Self.StorageKey.desktopZenModeEnabled)
        vault.save(arePageControlsCollapsed, forKey: Self.StorageKey.pageControlsCollapsed)
        vault.save(compactModeHidesQuickControls, forKey: Self.StorageKey.compactModeHidesQuickControls)
        vault.save(compactModeHidesTopSearchBar, forKey: Self.StorageKey.compactModeHidesTopSearchBar)
        vault.save(compactModeRevealsTopSearchBar, forKey: Self.StorageKey.compactModeRevealsTopSearchBar)
        vault.save(isTwoFingerDoubleTapCompactEnabledOnIPad, forKey: Self.StorageKey.twoFingerDoubleTapCompactOnIPad)
        vault.save(sideChromeWidthFraction, forKey: Self.StorageKey.sideChromeWidthFraction)
        vault.save(pageControlsOffsetX, forKey: Self.StorageKey.pageControlsOffsetX)
        vault.save(pageControlsOffsetY, forKey: Self.StorageKey.pageControlsOffsetY)
        vault.save(isTopSearchBarEnabled, forKey: Self.StorageKey.topSearchBarEnabled)
        vault.save(topSearchBarPlacement.rawValue, forKey: Self.StorageKey.topSearchBarPlacement)
        vault.save(topSearchBarPositionX, forKey: Self.StorageKey.topSearchBarPositionX)
        vault.save(topSearchBarPositionY, forKey: Self.StorageKey.topSearchBarPositionY)
        vault.save(searchEngine.rawValue, forKey: Self.StorageKey.searchEngine)
        vault.save(customSearchTemplate, forKey: Self.StorageKey.customSearchTemplate)
        vault.save(bangs, forKey: Self.StorageKey.bangs)
        vault.save(allTabsLayout.rawValue, forKey: Self.StorageKey.allTabsLayout)
        vault.save(allTabsDensity.rawValue, forKey: Self.StorageKey.allTabsDensity)
        vault.save(allTabsSortOrder.rawValue, forKey: Self.StorageKey.allTabsSortOrder)
        vault.save(allTabsShowsContainedTabs, forKey: Self.StorageKey.allTabsShowsContainedTabs)
        vault.save(allTabsShowsPrivateSummary, forKey: Self.StorageKey.allTabsShowsPrivateSummary)
        vault.save(moreMenuActionIDs, forKey: Self.StorageKey.moreMenuActionIDs)
        vault.save(toolbarActionIDs, forKey: Self.StorageKey.toolbarActionIDs)
        vault.save(isDeveloperModeEnabled, forKey: Self.StorageKey.developerModeEnabled)
        vault.save(isWebInspectorEnabled, forKey: Self.StorageKey.webInspectorEnabled)
        vault.save(isDevWebKitEnabled, forKey: Self.StorageKey.devWebKitEnabled)
        vault.save(devCustomEngineIdentifier, forKey: Self.StorageKey.devCustomEngineIdentifier)
        vault.save(deviceExperienceOverride.rawValue, forKey: Self.StorageKey.deviceExperienceOverride)
        vault.save(customIconNames, forKey: Self.StorageKey.customIconNames)
        vault.save(customIconColorHexBySlot, forKey: Self.StorageKey.customIconColorHexBySlot)
        vault.save(customIconImageDataBySlot, forKey: Self.StorageKey.customIconImageDataBySlot)
        vault.save(installedWebExtensions, forKey: Self.StorageKey.webExtensions)
        vault.save(history, forKey: Self.StorageKey.history)
        vault.save(essentials, forKey: Self.StorageKey.essentials)
        vault.save(websiteBlacklist, forKey: BrowserWebsitePrivacyPolicy.storageKey)
        vault.save(
            websiteProtectionWhitelist,
            forKey: BrowserWebsitePrivacyPolicy.protectionWhitelistStorageKey
        )
        vault.save(tabFolders, forKey: Self.StorageKey.tabFolders)
        vault.save(collapsedTabFolderIDs, forKey: Self.StorageKey.collapsedTabFolderIDs)
        vault.save(downloads, forKey: Self.StorageKey.downloads)
        vault.save(passwordEntries, forKey: Self.StorageKey.passwordEntries)
        vault.save(websiteDisplayMode.rawValue, forKey: Self.StorageKey.websiteDisplayMode)
        vault.save(localAIName, forKey: Self.StorageKey.localAIName)
        vault.save(localAIURLText, forKey: Self.StorageKey.localAIURLText)
        vault.save(isAdBlockerEnabled, forKey: Self.StorageKey.adBlockerEnabled)
        vault.save(trackerBlockingLevel.rawValue, forKey: Self.StorageKey.trackerBlockingLevel)
        vault.save(isScriptBlockingEnabled, forKey: Self.StorageKey.scriptBlockingEnabled)
        vault.save(isHTTPSUpgradeEnabled, forKey: Self.StorageKey.httpsUpgradeEnabled)
        vault.save(isFingerprintProtectionEnabled, forKey: Self.StorageKey.fingerprintProtectionEnabled)
        vault.save(isSocialBlockingEnabled, forKey: Self.StorageKey.socialBlockingEnabled)
        vault.save(isPopupBlockingEnabled, forKey: Self.StorageKey.popupBlockingEnabled)
        vault.save(isTrackingParameterStrippingEnabled, forKey: Self.StorageKey.trackingParameterStrippingEnabled)
        vault.save(isBounceTrackingProtectionEnabled, forKey: Self.StorageKey.bounceTrackingProtectionEnabled)
        vault.save(isWebRTCProtectionEnabled, forKey: Self.StorageKey.webRTCProtectionEnabled)
        vault.save(isRegionTricksEnabled, forKey: Self.StorageKey.regionTricksEnabled)
        vault.save(regionTrickProfile.rawValue, forKey: Self.StorageKey.regionTrickProfile)
        vault.save(isDarkReaderEnabled, forKey: Self.StorageKey.darkReaderEnabled)
        vault.save(darkReaderTheme.rawValue, forKey: Self.StorageKey.darkReaderTheme)
        vault.save(isStylusCatppuccinEnabled, forKey: Self.StorageKey.stylusCatppuccinEnabled)
        vault.save(isFPSForcerEnabled, forKey: Self.StorageKey.fpsForcerEnabled)
        vault.save(forcedFPS, forKey: Self.StorageKey.forcedFPS)
        vault.save(websiteResolutionScale, forKey: Self.StorageKey.websiteResolutionScale)
        vault.save(browserResolutionPreset.rawValue, forKey: Self.StorageKey.browserResolutionPreset)
        vault.save(browserResolutionWidth, forKey: Self.StorageKey.browserResolutionWidth)
        vault.save(isBrowserMusicEnabled, forKey: Self.StorageKey.browserMusicEnabled)
        vault.save(browserMusicTrack.rawValue, forKey: Self.StorageKey.browserMusicTrack)
        vault.save(browserMusicVolume, forKey: Self.StorageKey.browserMusicVolume)
        vault.save(importedBrowserMusicFilename, forKey: Self.StorageKey.importedBrowserMusicFilename)
        vault.save(newTabOpensSearch, forKey: Self.StorageKey.newTabOpensSearch)
        vault.save(autoCompactAfterSearchOnPhone, forKey: Self.StorageKey.autoCompactAfterSearchOnPhone)
        vault.save(BrowserContentBlocker.engineVersion, forKey: Self.StorageKey.shieldEngineVersion)
        vault.save(isTutorialPresented == false, forKey: Self.StorageKey.hasCompletedTutorial)
        vault.save(isFeatureUpdatePresented ? 0 : Self.currentFeatureUpdateVersion, forKey: Self.StorageKey.featureUpdateVersion)
        vault.save(selectedVPNCountry, forKey: Self.StorageKey.selectedVPNCountry)
        vault.save(vpnProfile, forKey: Self.StorageKey.vpnProfile)
        persistOpenTabs()
    }

    private static func loadTabs(
        vault: SecureBrowserVault,
        isDarkReaderEnabled: Bool,
        darkReaderTheme: BrowserDarkReaderTheme,
        isStylusCatppuccinEnabled: Bool,
        isFPSForcerEnabled: Bool,
        forcedFPS: Double,
        isAdBlockerEnabled: Bool,
        trackerBlockingLevel: BrowserTrackerBlockingLevel,
        isScriptBlockingEnabled: Bool,
        isHTTPSUpgradeEnabled: Bool,
        isFingerprintProtectionEnabled: Bool,
        isSocialBlockingEnabled: Bool,
        isPopupBlockingEnabled: Bool,
        isTrackingParameterStrippingEnabled: Bool,
        isBounceTrackingProtectionEnabled: Bool,
        isWebRTCProtectionEnabled: Bool,
        isRegionTricksEnabled: Bool,
        regionTrickProfile: BrowserRegionTrickProfile,
        isDeveloperModeEnabled: Bool,
        websiteResolutionScale: Double,
        websiteDisplayMode: BrowserWebsiteDisplayMode,
        browserResolutionPreset: BrowserResolutionPreset,
        browserResolutionWidth: Double,
        webExtensions: [BrowserWebExtension],
        websiteBlacklist: [String],
        websiteProtectionWhitelist: [String]
    ) -> (tabs: [BrowserTab], selectedTabID: BrowserTab.ID?) {
        let savedTabs = vault.load([PersistedBrowserTab].self, forKey: StorageKey.openTabs, default: [])
        guard savedTabs.isEmpty == false else {
            let firstTab = BrowserTab(
                usesPersistentStorage: true,
                isDarkReaderEnabled: isDarkReaderEnabled,
                darkReaderTheme: darkReaderTheme,
                isStylusCatppuccinEnabled: isStylusCatppuccinEnabled,
                isAdBlockerEnabled: isAdBlockerEnabled,
                trackerBlockingLevel: trackerBlockingLevel,
                isScriptBlockingEnabled: isScriptBlockingEnabled,
                isHTTPSUpgradeEnabled: isHTTPSUpgradeEnabled,
                isFingerprintProtectionEnabled: isFingerprintProtectionEnabled,
                isSocialBlockingEnabled: isSocialBlockingEnabled,
                isPopupBlockingEnabled: isPopupBlockingEnabled,
                isTrackingParameterStrippingEnabled: isTrackingParameterStrippingEnabled,
                isBounceTrackingProtectionEnabled: isBounceTrackingProtectionEnabled,
                isWebRTCProtectionEnabled: isWebRTCProtectionEnabled,
                isRegionTricksEnabled: isRegionTricksEnabled,
                regionTrickProfile: regionTrickProfile,
                isFPSForcerEnabled: isFPSForcerEnabled,
                forcedFPS: forcedFPS,
                websiteResolutionScale: websiteResolutionScale,
                websiteDisplayMode: websiteDisplayMode,
                browserResolutionPreset: browserResolutionPreset,
                browserResolutionWidth: browserResolutionWidth,
                webExtensions: webExtensions,
                websiteBlacklist: websiteBlacklist,
                websiteProtectionWhitelist: websiteProtectionWhitelist
            )
            return ([firstTab], firstTab.id)
        }

        var restoredTabs: [BrowserTab] = []
        var selectedID: BrowserTab.ID?

        for savedTab in savedTabs {
            guard let url = URL(string: savedTab.urlString) else { continue }
            let usesDevWebKitProfile = isDeveloperModeEnabled && savedTab.usesDevWebKitProfile == true
            let tab = BrowserTab(
                startURL: url,
                usesPersistentStorage: true,
                isDarkReaderEnabled: isDarkReaderEnabled,
                darkReaderTheme: darkReaderTheme,
                isStylusCatppuccinEnabled: isStylusCatppuccinEnabled,
                isAdBlockerEnabled: isAdBlockerEnabled,
                trackerBlockingLevel: trackerBlockingLevel,
                isScriptBlockingEnabled: isScriptBlockingEnabled,
                isHTTPSUpgradeEnabled: isHTTPSUpgradeEnabled,
                isFingerprintProtectionEnabled: isFingerprintProtectionEnabled,
                isSocialBlockingEnabled: isSocialBlockingEnabled,
                isPopupBlockingEnabled: isPopupBlockingEnabled,
                isTrackingParameterStrippingEnabled: isTrackingParameterStrippingEnabled,
                isBounceTrackingProtectionEnabled: isBounceTrackingProtectionEnabled,
                isWebRTCProtectionEnabled: isWebRTCProtectionEnabled,
                isRegionTricksEnabled: isRegionTricksEnabled,
                regionTrickProfile: regionTrickProfile,
                isFPSForcerEnabled: isFPSForcerEnabled,
                forcedFPS: forcedFPS,
                websiteResolutionScale: websiteResolutionScale,
                websiteDisplayMode: websiteDisplayMode,
                browserResolutionPreset: browserResolutionPreset,
                browserResolutionWidth: browserResolutionWidth,
                folderID: savedTab.folderID,
                webExtensions: webExtensions,
                websiteBlacklist: websiteBlacklist,
                websiteProtectionWhitelist: websiteProtectionWhitelist,
                webKitProfile: usesDevWebKitProfile ? .dev : .standard
            )
            tab.title = savedTab.title
            restoredTabs.append(tab)
            if savedTab.isSelected {
                selectedID = tab.id
            }
        }

        if restoredTabs.isEmpty {
            let firstTab = BrowserTab(
                usesPersistentStorage: true,
                isDarkReaderEnabled: isDarkReaderEnabled,
                darkReaderTheme: darkReaderTheme,
                isStylusCatppuccinEnabled: isStylusCatppuccinEnabled,
                isAdBlockerEnabled: isAdBlockerEnabled,
                trackerBlockingLevel: trackerBlockingLevel,
                isScriptBlockingEnabled: isScriptBlockingEnabled,
                isHTTPSUpgradeEnabled: isHTTPSUpgradeEnabled,
                isFingerprintProtectionEnabled: isFingerprintProtectionEnabled,
                isSocialBlockingEnabled: isSocialBlockingEnabled,
                isPopupBlockingEnabled: isPopupBlockingEnabled,
                isTrackingParameterStrippingEnabled: isTrackingParameterStrippingEnabled,
                isBounceTrackingProtectionEnabled: isBounceTrackingProtectionEnabled,
                isWebRTCProtectionEnabled: isWebRTCProtectionEnabled,
                isRegionTricksEnabled: isRegionTricksEnabled,
                regionTrickProfile: regionTrickProfile,
                isFPSForcerEnabled: isFPSForcerEnabled,
                forcedFPS: forcedFPS,
                websiteResolutionScale: websiteResolutionScale,
                websiteDisplayMode: websiteDisplayMode,
                browserResolutionPreset: browserResolutionPreset,
                browserResolutionWidth: browserResolutionWidth,
                webExtensions: webExtensions,
                websiteBlacklist: websiteBlacklist,
                websiteProtectionWhitelist: websiteProtectionWhitelist
            )
            return ([firstTab], firstTab.id)
        }

        return (restoredTabs, selectedID ?? restoredTabs.first?.id)
    }

    private static func loadHistory(vault: SecureBrowserVault) -> [BrowserHistoryItem] {
        vault.load([BrowserHistoryItem].self, forKey: StorageKey.history, default: [])
    }

    private static func loadDownloads(vault: SecureBrowserVault) -> [BrowserDownloadItem] {
        vault.load([BrowserDownloadItem].self, forKey: StorageKey.downloads, default: [])
    }

    private static func loadPasswordEntries(vault: SecureBrowserVault) -> [BrowserPasswordEntry] {
        vault.load([BrowserPasswordEntry].self, forKey: StorageKey.passwordEntries, default: [])
    }

    private static func loadEssentials(vault: SecureBrowserVault) -> [BrowserEssentialItem] {
        vault.load([BrowserEssentialItem].self, forKey: StorageKey.essentials, default: [])
    }

    private static func loadTabFolders(vault: SecureBrowserVault) -> [BrowserTabFolder] {
        vault.load([BrowserTabFolder].self, forKey: StorageKey.tabFolders, default: [])
    }

    private static func loadVPNProfile(vault: SecureBrowserVault) -> CustomVPNProfile {
        vault.load(CustomVPNProfile.self, forKey: StorageKey.vpnProfile, default: .empty)
    }

    private static func shouldPersist(url: URL) -> Bool {
        guard BrowserTab.isStartPageURL(url) == false,
              url.host != "browser.local" else {
            return false
        }
        guard let scheme = url.scheme?.lowercased() else { return false }
        return ["http", "https", "file"].contains(scheme)
    }

    private static func normalizedURL(from rawValue: String) -> URL? {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return nil }

        if let url = URL(string: trimmed),
           let scheme = url.scheme?.lowercased(),
           ["http", "https"].contains(scheme) {
            return url
        }

        return URL(string: "http://\(trimmed)")
    }

    private static func normalizedToolbarActionIDs(_ rawIDs: [String]) -> [String] {
        var seen = Set<String>()
        return rawIDs.compactMap { rawID in
            guard let action = BrowserToolbarAction(rawValue: rawID),
                  action.isLeanBuildUtility == false,
                  seen.insert(rawID).inserted else { return nil }
            return action.rawValue
        }
    }

    private static func clampedUnit(_ value: Double) -> Double {
        min(max(value, 0.0), 1.0)
    }

    private static func clampedSideChromeWidthFraction(_ value: Double) -> Double {
        min(max(value, 0.22), 0.58)
    }

    private static func clampedForcedFPS(_ value: Double) -> Double {
        guard value.isFinite else { return infiniteForcedFPSValue }
        return min(max(value.rounded(), minimumForcedFPS), infiniteForcedFPSValue)
    }

    private static func clampedWebsiteResolutionScale(_ value: Double) -> Double {
        guard value.isFinite else { return 1.0 }
        let rounded = (value * 100).rounded() / 100
        return min(max(rounded, minimumWebsiteResolutionScale), maximumWebsiteResolutionScale)
    }

    private static func websiteDisplayMode(
        forBrowserResolution preset: BrowserResolutionPreset,
        width: Double
    ) -> BrowserWebsiteDisplayMode {
        if preset == .custom {
            return .automatic
        }

        return preset.websiteDisplayMode
    }

    private static func deviceExperienceOverride(
        forBrowserResolution preset: BrowserResolutionPreset,
        width: Double
    ) -> BrowserDeviceExperienceOverride {
        if preset == .custom {
            return .automatic
        }

        return preset.deviceExperienceOverride
    }

    private static func deviceExperienceOverride(
        forBrowserResolutionWidth width: Double
    ) -> BrowserDeviceExperienceOverride {
        BrowserResolutionPreset.clampedScreenScale(width) <= 0.65 ? .iPad : .automatic
    }

    private static func countLabel(_ count: Int, singular: String) -> String {
        count == 1 ? "1 \(singular)" : "\(count) \(singular)s"
    }

    private static func defaultTopSearchBarY(for placement: BrowserToolbarPlacement) -> Double {
        switch placement {
        case .top:
            return 0.0
        case .center:
            return 0.5
        case .bottom:
            return 1.0
        }
    }

    private static func nearestTopSearchBarPlacement(for y: Double) -> BrowserToolbarPlacement {
        let clampedY = clampedUnit(y)
        if clampedY < 0.25 {
            return .top
        }
        if clampedY > 0.75 {
            return .bottom
        }
        return .center
    }

    private func persistBangs() {
        vault.save(bangs, forKey: Self.StorageKey.bangs)
    }

    private enum StorageKey {
        static let darkReaderEnabled = "ZenFireBrowser.darkReaderEnabled"
        static let chromePlacement = "ZenFireBrowser.chromePlacement"
        static let sideTabsCollapsed = "ZenFireBrowser.sideTabsCollapsed"
        static let desktopZenModeEnabled = "ZenFireBrowser.desktopZenModeEnabled"
        static let pageControlsCollapsed = "ZenFireBrowser.pageControlsCollapsed"
        static let sideChromeWidthFraction = "ZenFireBrowser.sideChromeWidthFraction"
        static let pageControlsOffsetX = "ZenFireBrowser.pageControlsOffsetX"
        static let pageControlsOffsetY = "ZenFireBrowser.pageControlsOffsetY"
        static let compactModeHidesQuickControls = "ZenFireBrowser.compactModeHidesQuickControls"
        static let compactModeHidesTopSearchBar = "ZenFireBrowser.compactModeHidesTopSearchBar"
        static let compactModeRevealsTopSearchBar = "ZenFireBrowser.compactModeRevealsTopSearchBar"
        static let twoFingerDoubleTapCompactOnIPad = "ZenFireBrowser.twoFingerDoubleTapCompactOnIPad"
        static let topSearchBarEnabled = "ZenFireBrowser.topSearchBarEnabled"
        static let topSearchBarPlacement = "ZenFireBrowser.topSearchBarPlacement"
        static let topSearchBarPositionX = "ZenFireBrowser.topSearchBarPositionX"
        static let topSearchBarPositionY = "ZenFireBrowser.topSearchBarPositionY"
        static let searchEngine = "ZenFireBrowser.searchEngine"
        static let customSearchTemplate = "ZenFireBrowser.customSearchTemplate"
        static let bangs = "ZenFireBrowser.bangs"
        static let allTabsLayout = "ZenFireBrowser.allTabsLayout"
        static let allTabsDensity = "ZenFireBrowser.allTabsDensity"
        static let allTabsSortOrder = "ZenFireBrowser.allTabsSortOrder"
        static let allTabsShowsContainedTabs = "ZenFireBrowser.allTabsShowsContainedTabs"
        static let allTabsShowsPrivateSummary = "ZenFireBrowser.allTabsShowsPrivateSummary"
        static let moreMenuActionIDs = "ZenFireBrowser.moreMenuActionIDs"
        static let toolbarActionIDs = "ZenFireBrowser.toolbarActionIDs"
        static let toolbarUpgradeVersion = "ZenFireBrowser.toolbarUpgradeVersion"
        static let developerModeEnabled = "ZenFireBrowser.developerModeEnabled"
        static let webInspectorEnabled = "ZenFireBrowser.webInspectorEnabled"
        static let devWebKitEnabled = "ZenFireBrowser.devWebKitEnabled"
        static let devCustomEngineIdentifier = "ZenFireBrowser.devCustomEngineIdentifier"
        static let deviceExperienceOverride = "ZenFireBrowser.deviceExperienceOverride"
        static let customIconNames = "ZenFireBrowser.customIconNames"
        static let customIconColorHexBySlot = "ZenFireBrowser.customIconColorHexBySlot"
        static let customIconImageDataBySlot = "ZenFireBrowser.customIconImageDataBySlot"
        static let webExtensions = "ZenFireBrowser.webExtensions"
        static let history = "ZenFireBrowser.history"
        static let essentials = "ZenFireBrowser.essentials"
        static let tabFolders = "ZenFireBrowser.tabFolders"
        static let collapsedTabFolderIDs = "ZenFireBrowser.collapsedTabFolderIDs"
        static let openTabs = "ZenFireBrowser.openTabs"
        static let localAIName = "ZenFireBrowser.localAIName"
        static let localAIURLText = "ZenFireBrowser.localAIURLText"
        static let adBlockerEnabled = "ZenFireBrowser.adBlockerEnabled"
        static let trackerBlockingLevel = "ZenFireBrowser.trackerBlockingLevel"
        static let shieldEngineVersion = "ZenFireBrowser.shieldEngineVersion"
        static let scriptBlockingEnabled = "ZenFireBrowser.scriptBlockingEnabled"
        static let httpsUpgradeEnabled = "ZenFireBrowser.httpsUpgradeEnabled"
        static let fingerprintProtectionEnabled = "ZenFireBrowser.fingerprintProtectionEnabled"
        static let socialBlockingEnabled = "ZenFireBrowser.socialBlockingEnabled"
        static let popupBlockingEnabled = "ZenFireBrowser.popupBlockingEnabled"
        static let trackingParameterStrippingEnabled = "ZenFireBrowser.trackingParameterStrippingEnabled"
        static let bounceTrackingProtectionEnabled = "ZenFireBrowser.bounceTrackingProtectionEnabled"
        static let webRTCProtectionEnabled = "ZenFireBrowser.webRTCProtectionEnabled"
        static let regionTricksEnabled = "ZenFireBrowser.regionTricksEnabled"
        static let regionTrickProfile = "ZenFireBrowser.regionTrickProfile"
        static let darkReaderTheme = "ZenFireBrowser.darkReaderTheme"
        static let stylusCatppuccinEnabled = "ZenFireBrowser.stylusCatppuccinEnabled"
        static let fpsForcerEnabled = "ZenFireBrowser.fpsForcerEnabled"
        static let forcedFPS = "ZenFireBrowser.forcedFPS"
        static let websiteResolutionScale = "ZenFireBrowser.websiteResolutionScale"
        static let browserResolutionPreset = "ZenFireBrowser.browserResolutionPreset"
        static let browserResolutionWidth = "ZenFireBrowser.browserResolutionWidth"
        static let browserMusicEnabled = "ZenFireBrowser.browserMusicEnabled"
        static let browserMusicTrack = "ZenFireBrowser.browserMusicTrack"
        static let browserMusicVolume = "ZenFireBrowser.browserMusicVolume"
        static let importedBrowserMusicFilename = "ZenFireBrowser.importedBrowserMusicFilename"
        static let newTabOpensSearch = "ZenFireBrowser.newTabOpensSearch"
        static let autoCompactAfterSearchOnPhone = "ZenFireBrowser.autoCompactAfterSearchOnPhone"
        static let hasCompletedTutorial = "ZenFireBrowser.hasCompletedTutorial"
        static let featureUpdateVersion = "ZenFireBrowser.featureUpdateVersion"
        static let downloads = "ZenFireBrowser.downloads"
        static let passwordEntries = "ZenFireBrowser.passwordEntries"
        static let websiteDisplayMode = "ZenFireBrowser.websiteDisplayMode"
        static let selectedVPNCountry = "ZenFireBrowser.selectedVPNCountry"
        static let vpnProfile = "ZenFireBrowser.vpnProfile"
        static let leanProfileVersion = "ZenFireBrowser.leanProfileVersion"
    }
}
