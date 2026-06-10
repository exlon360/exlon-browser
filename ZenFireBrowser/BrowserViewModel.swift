import Combine
import CoreGraphics
import Foundation
import SwiftUI
import UIKit

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

enum BrowserToolbarAction: String, CaseIterable, Identifiable {
    case forward
    case reload
    case tabFinder
    case containedTabs
    case downloadCurrent
    case history
    case downloads
    case placement
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .forward:
            return "Forward"
        case .reload:
            return "Reload / Stop"
        case .tabFinder:
            return "Tab Finder"
        case .containedTabs:
            return "Contained Tabs"
        case .downloadCurrent:
            return "Download Current Tab"
        case .history:
            return "History"
        case .downloads:
            return "Downloads"
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
        case .forward:
            return "chevron.right"
        case .reload:
            return "arrow.clockwise"
        case .tabFinder:
            return "square.grid.2x2"
        case .containedTabs:
            return "rectangle.on.rectangle"
        case .downloadCurrent:
            return "arrow.down.doc"
        case .history:
            return "clock.arrow.circlepath"
        case .downloads:
            return "arrow.down.circle"
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
    case forward
    case reload
    case tabFinder
    case downloadCurrent
    case downloads
    case history
    case placement
    case settings

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
        case .forward:
            return "Forward"
        case .reload:
            return "Reload"
        case .tabFinder:
            return "Tab Finder"
        case .downloadCurrent:
            return "Download Current"
        case .downloads:
            return "Downloads"
        case .history:
            return "History"
        case .placement:
            return "Placement"
        case .settings:
            return "Settings"
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
        case .forward:
            return "chevron.right"
        case .reload:
            return "arrow.clockwise"
        case .tabFinder:
            return "square.grid.2x2"
        case .downloadCurrent:
            return "arrow.down.doc"
        case .downloads:
            return "arrow.down.circle"
        case .history:
            return "clock.arrow.circlepath"
        case .placement:
            return "rectangle.split.2x1"
        case .settings:
            return "gearshape"
        }
    }
}

enum BrowserTopSearchBarPlacement: String, CaseIterable, Identifiable {
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

enum BrowserAddOnLibrary: String, CaseIterable, Identifiable {
    case firefox
    case brave

    var id: String { rawValue }

    var title: String {
        switch self {
        case .firefox:
            return "Firefox Add-ons"
        case .brave:
            return "Brave Add-ons"
        }
    }

    var subtitle: String {
        switch self {
        case .firefox:
            return "Browse Mozilla's extension and theme library."
        case .brave:
            return "Browse the Chrome Web Store used by Brave desktop."
        }
    }

    var symbolName: String {
        switch self {
        case .firefox:
            return "flame"
        case .brave:
            return "shield.lefthalf.filled"
        }
    }

    var url: URL {
        switch self {
        case .firefox:
            return URL(string: "https://addons.mozilla.org/firefox/")!
        case .brave:
            return URL(string: "https://chromewebstore.google.com/category/extensions")!
        }
    }
}

extension BrowserToolbarAction {
    var customIconSlot: BrowserCustomIconSlot {
        switch self {
        case .forward:
            return .forward
        case .reload:
            return .reload
        case .tabFinder:
            return .tabFinder
        case .containedTabs:
            return .containedTabs
        case .downloadCurrent:
            return .downloadCurrent
        case .history:
            return .history
        case .downloads:
            return .downloads
        case .placement:
            return .placement
        case .settings:
            return .settings
        }
    }
}

@MainActor
final class BrowserViewModel: ObservableObject {
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
    @Published var isTabFinderPresented = false
    @Published var isSettingsPresented = false
    @Published var isHistoryPresented = false
    @Published var isDownloadsPresented = false
    @Published var isVPNPresented = false
    @Published var isAddOnsPresented = false
    @Published var isAdvancedConfigPresented = false
    @Published var isCustomIconsPresented = false
    @Published var isWebFileImporterPresented = false
    @Published var allowsMultipleWebFileImport = false
    @Published var isLocalAIImporterPresented = false
    @Published var isTutorialPresented: Bool
    @Published var isDarkReaderEnabled: Bool
    @Published var isAdBlockerEnabled: Bool
    @Published var isTopSearchBarEnabled: Bool {
        didSet {
            vault.save(isTopSearchBarEnabled, forKey: Self.StorageKey.topSearchBarEnabled)
        }
    }
    @Published var topSearchBarPlacement: BrowserTopSearchBarPlacement {
        didSet {
            vault.save(topSearchBarPlacement.rawValue, forKey: Self.StorageKey.topSearchBarPlacement)
        }
    }
    @Published var areSideTabsCollapsed: Bool {
        didSet {
            vault.save(areSideTabsCollapsed, forKey: Self.StorageKey.sideTabsCollapsed)
        }
    }
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
    @Published var moreMenuActionIDs: Set<String> {
        didSet {
            vault.save(moreMenuActionIDs, forKey: Self.StorageKey.moreMenuActionIDs)
        }
    }
    @Published var customIconNames: [String: String] {
        didSet {
            vault.save(customIconNames, forKey: Self.StorageKey.customIconNames)
        }
    }
    @Published var history: [BrowserHistoryItem]
    @Published var essentials: [BrowserEssentialItem]
    @Published var downloads: [BrowserDownloadItem]
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
    @Published var vpnStatusMessage = "Custom VPN profile not configured."
    @Published var downloadStatusMessage = ""
    @Published private var customIconImageDataBySlot: [String: Data] {
        didSet {
            vault.save(customIconImageDataBySlot, forKey: Self.StorageKey.customIconImageDataBySlot)
        }
    }
    private let vault: SecureBrowserVault
    private var pendingWebFileImportCompletion: (([URL]?) -> Void)?

    init(vault: SecureBrowserVault) {
        self.vault = vault
        let darkReaderEnabled = vault.load(Bool.self, forKey: Self.StorageKey.darkReaderEnabled, default: false)
        let adBlockerEnabled = vault.load(Bool.self, forKey: Self.StorageKey.adBlockerEnabled, default: true)
        let placement = BrowserChromePlacement(rawValue: vault.load(String.self, forKey: Self.StorageKey.chromePlacement, default: "")) ?? .left
        let selectedSearchEngine = BrowserSearchEngine(rawValue: vault.load(String.self, forKey: Self.StorageKey.searchEngine, default: "")) ?? .duckDuckGo
        let savedCustomSearch = vault.load(String.self, forKey: Self.StorageKey.customSearchTemplate, default: BrowserSearchEngine.defaultCustomTemplate)
        let savedMoreMenuActionIDs = vault.load(Set<String>.self, forKey: Self.StorageKey.moreMenuActionIDs, default: [])
        let savedCustomIconNames = vault.load([String: String].self, forKey: Self.StorageKey.customIconNames, default: [:])
        let savedCustomIconImageData = vault.load([String: Data].self, forKey: Self.StorageKey.customIconImageDataBySlot, default: [:])
        let savedHistory = Self.loadHistory(vault: vault)
        let savedEssentials = Self.loadEssentials(vault: vault)
        let savedDownloads = Self.loadDownloads(vault: vault)
        let savedVPNProfile = Self.loadVPNProfile(vault: vault)
        let restoredTabs = Self.loadTabs(vault: vault, isDarkReaderEnabled: darkReaderEnabled, isAdBlockerEnabled: adBlockerEnabled)

        self.chromePlacement = placement
        self.areSideTabsCollapsed = vault.load(Bool.self, forKey: Self.StorageKey.sideTabsCollapsed, default: false)
        self.searchEngine = selectedSearchEngine
        self.customSearchTemplate = savedCustomSearch
        self.moreMenuActionIDs = savedMoreMenuActionIDs
        self.isTopSearchBarEnabled = vault.load(Bool.self, forKey: Self.StorageKey.topSearchBarEnabled, default: false)
        self.topSearchBarPlacement = BrowserTopSearchBarPlacement(
            rawValue: vault.load(String.self, forKey: Self.StorageKey.topSearchBarPlacement, default: "")
        ) ?? .top
        self.customIconNames = Self.sanitizedIconNames(savedCustomIconNames)
        self.customIconImageDataBySlot = Self.sanitizedIconImageData(savedCustomIconImageData)
        self.history = savedHistory
        self.essentials = savedEssentials
        self.downloads = savedDownloads
        self.isTutorialPresented = vault.load(Bool.self, forKey: Self.StorageKey.hasCompletedTutorial, default: false) == false
        self.isDarkReaderEnabled = darkReaderEnabled
        self.isAdBlockerEnabled = adBlockerEnabled
        self.localAIName = vault.load(String.self, forKey: Self.StorageKey.localAIName, default: "Local AI")
        self.localAIURLText = vault.load(String.self, forKey: Self.StorageKey.localAIURLText, default: "")
        self.vpnProfile = savedVPNProfile
        self.vpnStatusMessage = savedVPNProfile.isConfigured ? "Custom VPN profile saved." : "Custom VPN profile not configured."
        self.tabs = restoredTabs.tabs
        self.selectedTabID = restoredTabs.selectedTabID

        for tab in tabs {
            configure(tab)
        }
        migrateLoadedStateToEncryptedVault()
    }

    var selectedTab: BrowserTab? {
        guard let selectedTabID = selectedTabID else { return tabs.first }
        return tabs.first { $0.id == selectedTabID } ?? tabs.first
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

    func select(_ tab: BrowserTab) {
        selectedTabID = tab.id
        if isFloatingSearchPresented {
            floatingSearchText = tab.addressText
        }
        persistOpenTabs()
    }

    func selectFromFinder(_ tab: BrowserTab) {
        if containedTabs.contains(where: { $0.id == tab.id }) {
            selectedContainedTabID = tab.id
            isContainedBrowserPresented = true
        } else {
            select(tab)
        }
        isTabFinderPresented = false
    }

    @discardableResult
    func openTab(startURL: URL = BrowserDefaults.homeURL, private isPrivate: Bool = false) -> BrowserTab {
        let tab = BrowserTab(
            startURL: startURL,
            isPrivate: isPrivate,
            usesPersistentStorage: false,
            isDarkReaderEnabled: isDarkReaderEnabled,
            isAdBlockerEnabled: isAdBlockerEnabled
        )
        configure(tab)
        tabs.append(tab)
        selectedTabID = tab.id
        persistOpenTabs()
        return tab
    }

    func openNewTabAndSearch(private isPrivate: Bool = false) {
        let tab = openTab(private: isPrivate)
        floatingSearchText = tab.addressText
        shouldSelectFloatingSearchText = true
        isFloatingSearchPresented = true
    }

    func openPrivateTab() {
        openNewTabAndSearch(private: true)
    }

    @discardableResult
    func openContainedTab(startURL: URL = BrowserDefaults.containedBrowserStartURL) -> BrowserTab {
        let tab = BrowserTab(
            startURL: startURL,
            usesPersistentStorage: false,
            isContainedBrowser: true,
            isDarkReaderEnabled: isDarkReaderEnabled,
            isAdBlockerEnabled: isAdBlockerEnabled
        )
        configureContained(tab)
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
        selectedContainedTab?.submitAddress(searchEngine: searchEngine, customSearchTemplate: customSearchTemplate)
    }

    func close(_ tab: BrowserTab) {
        guard tabs.count > 1 else {
            tab.load(BrowserTab.homeURL)
            persistOpenTabs()
            return
        }

        let wasSelected = selectedTabID.map { $0 == tab.id } ?? false
        tabs.removeAll { $0.id == tab.id }

        if wasSelected {
            selectedTabID = tabs.last?.id
        }

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

    func submitAddress() {
        let submittedText = isFloatingSearchPresented ? floatingSearchText : selectedTab?.addressText ?? ""
        selectedTab?.addressText = submittedText
        selectedTab?.submitAddress(searchEngine: searchEngine, customSearchTemplate: customSearchTemplate)
        floatingSearchText = selectedTab?.addressText ?? submittedText
        shouldSelectFloatingSearchText = false
        isFloatingSearchPresented = false
    }

    func openFloatingSearch() {
        floatingSearchText = selectedTab?.addressText ?? ""
        shouldSelectFloatingSearchText = true
        isFloatingSearchPresented = true
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

    func setTabBarCollapsed(_ collapsed: Bool) {
        withAnimation(.spring(response: 0.28, dampingFraction: 0.84)) {
            areSideTabsCollapsed = collapsed
        }
    }

    func toggleSideTabs() {
        setTabBarCollapsed(!areSideTabsCollapsed)
    }

    func handleTwoFingerSwipe(deltaX: CGFloat) {
        if deltaX < 0 {
            setTabBarCollapsed(true)
        } else {
            setTabBarCollapsed(false)
        }
    }

    func completeTutorial() {
        isTutorialPresented = false
        vault.save(true, forKey: Self.StorageKey.hasCompletedTutorial)
    }

    func handleThreeFingerSwipe(deltaX: CGFloat) {
        if deltaX > 0 {
            goBack()
        } else {
            goForward()
        }
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
            urlString: url.absoluteString
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

    func removeEssential(_ item: BrowserEssentialItem) {
        essentials.removeAll { $0.id == item.id }
        saveEssentials()
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

    func isInMoreMenu(_ action: BrowserToolbarAction) -> Bool {
        moreMenuActionIDs.contains(action.rawValue)
    }

    func setMoreMenuAction(_ action: BrowserToolbarAction, enabled: Bool) {
        if enabled {
            moreMenuActionIDs.insert(action.rawValue)
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
        customIconImageDataBySlot = [:]
    }

    func advancedConfigJSON(theme: BrowserTheme) -> String {
        let config = BrowserAdvancedConfig(
            topSearchBarEnabled: isTopSearchBarEnabled,
            topSearchBarPlacement: topSearchBarPlacement.rawValue,
            chromePlacement: chromePlacement.rawValue,
            sideTabsCollapsed: areSideTabsCollapsed,
            searchEngine: searchEngine.rawValue,
            customSearchTemplate: customSearchTemplate,
            darkReaderEnabled: isDarkReaderEnabled,
            adBlockerEnabled: isAdBlockerEnabled,
            moreMenuActions: BrowserToolbarAction.allCases
                .map(\.rawValue)
                .filter { moreMenuActionIDs.contains($0) },
            customIcons: customIconNames,
            tabBarTransparencyEnabled: theme.isTabBarTransparencyEnabled,
            tabBarTransparency: theme.tabBarTransparency,
            userBackgroundEnabled: theme.isUserBackgroundEnabled,
            colors: theme.colorConfig
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
           let placement = BrowserTopSearchBarPlacement(rawValue: topSearchBarPlacementValue) {
            topSearchBarPlacement = placement
        }
        areSideTabsCollapsed = config.sideTabsCollapsed
        customSearchTemplate = config.customSearchTemplate
        moreMenuActionIDs = Set(config.moreMenuActions.filter { actionID in
            BrowserToolbarAction(rawValue: actionID) != nil
        })
        customIconNames = Self.sanitizedIconNames(config.customIcons)
        setDarkReaderEnabled(config.darkReaderEnabled)
        setAdBlockerEnabled(config.adBlockerEnabled)
        theme.applyAdvancedConfig(
            colors: config.colors,
            tabBarTransparencyEnabled: config.tabBarTransparencyEnabled,
            tabBarTransparency: config.tabBarTransparency,
            userBackgroundEnabled: config.userBackgroundEnabled
        )
    }

    func performToolbarAction(_ action: BrowserToolbarAction) {
        switch action {
        case .forward:
            goForward()
        case .reload:
            reloadOrStop()
        case .tabFinder:
            isTabFinderPresented = true
        case .containedTabs:
            showContainedTabs()
        case .downloadCurrent:
            downloadSelectedTab()
        case .history:
            isHistoryPresented = true
        case .downloads:
            isDownloadsPresented = true
        case .placement:
            break
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

        let destination = BrowserTab.destinationURL(
            from: query,
            searchEngine: searchEngine,
            customSearchTemplate: customSearchTemplate
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

    func openSearchResult(_ result: BrowserSearchResult) {
        floatingSearchText = result.url.absoluteString
        shouldSelectFloatingSearchText = false
        selectedTab?.addressText = result.url.absoluteString
        selectedTab?.load(result.url)
        isFloatingSearchPresented = false
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

    func importLocalAI(name: String, urlText: String) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        localAIName = trimmedName.isEmpty ? "Local AI" : trimmedName
        localAIURLText = urlText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func saveVPNProfile(_ profile: CustomVPNProfile) {
        vpnProfile = profile
        vpnStatusMessage = profile.isConfigured ? "Custom VPN profile saved." : "Custom VPN profile not configured."
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

    func resetToDefaults() {
        chromePlacement = .left
        areSideTabsCollapsed = false
        isTopSearchBarEnabled = false
        topSearchBarPlacement = .top
        searchEngine = .duckDuckGo
        customSearchTemplate = BrowserSearchEngine.defaultCustomTemplate
        moreMenuActionIDs = []
        resetCustomIcons()
        localAIName = "Local AI"
        localAIURLText = ""
        setAdBlockerEnabled(true)
        setDarkReaderEnabled(false)
        essentials = []
        saveEssentials()
        saveVPNProfile(.empty)
    }

    private func configure(_ tab: BrowserTab) {
        tab.onNavigationFinished = { [weak self] tab in
            self?.recordVisit(from: tab)
        }
        tab.onDownloadUpdated = { [weak self] item in
            self?.updateDownload(item)
        }
        tab.onTwoFingerSwipe = { [weak self] deltaX in
            self?.handleTwoFingerSwipe(deltaX: deltaX)
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
        tab.onTwoFingerSwipe = { [weak self] deltaX in
            self?.handleTwoFingerSwipe(deltaX: deltaX)
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

    private func recordVisit(from tab: BrowserTab) {
        guard tab.isPrivate == false,
              let url = tab.url,
              Self.shouldPersist(url: url) else {
            return
        }

        let title = tab.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let item = BrowserHistoryItem(
            title: title.isEmpty ? url.absoluteString : title,
            urlString: url.absoluteString
        )

        history.removeAll { $0.urlString == item.urlString }
        history.insert(item, at: 0)
        if history.count > 250 {
            history = Array(history.prefix(250))
        }

        saveHistory()
        persistOpenTabs()
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
                isSelected: selectedNormalID.map { $0 == tab.id } ?? false
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

    private func updateDownload(_ item: BrowserDownloadItem) {
        if item.state == .finished, item.isEncrypted == false {
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

            let plaintextData = try Data(contentsOf: plaintextURL)
            let encryptedData = try vault.encryptData(plaintextData)
            let encryptedURL = try encryptedDownloadURL(for: item)

            if FileManager.default.fileExists(atPath: encryptedURL.path) {
                try FileManager.default.removeItem(at: encryptedURL)
            }

            try encryptedData.write(to: encryptedURL, options: [.atomic])
            #if os(iOS)
            try? FileManager.default.setAttributes([.protectionKey: FileProtectionType.complete], ofItemAtPath: encryptedURL.path)
            #endif
            try? FileManager.default.removeItem(at: plaintextURL)

            let presentationURL = displayURL ?? (try? BrowserTab.downloadDestination(for: item.filename))
            finished.localPath = presentationURL?.path ?? item.localPath
            finished.state = .finished
            finished.errorMessage = nil
            finished.encryptedLocalPath = encryptedURL.path
            finished.originalByteCount = Int64(plaintextData.count)

            downloadStatusMessage = "Saved encrypted \(finished.filename)."
            upsertDownload(finished)
        } catch {
            try? FileManager.default.removeItem(at: plaintextURL)
            finished.state = .failed
            finished.errorMessage = "Download could not be encrypted: \(error.localizedDescription)"
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

    private static func safeDownloadFilename(_ filename: String) -> String {
        let trimmed = filename.trimmingCharacters(in: .whitespacesAndNewlines)
        let fallback = trimmed.isEmpty ? "download" : trimmed
        let illegal = CharacterSet(charactersIn: "/\\?%*|\"<>:")
        return fallback
            .components(separatedBy: illegal)
            .joined(separator: "-")
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

    private func persistVPNProfile() {
        vault.save(vpnProfile, forKey: Self.StorageKey.vpnProfile)
    }

    private func migrateLoadedStateToEncryptedVault() {
        vault.save(chromePlacement.rawValue, forKey: Self.StorageKey.chromePlacement)
        vault.save(areSideTabsCollapsed, forKey: Self.StorageKey.sideTabsCollapsed)
        vault.save(isTopSearchBarEnabled, forKey: Self.StorageKey.topSearchBarEnabled)
        vault.save(topSearchBarPlacement.rawValue, forKey: Self.StorageKey.topSearchBarPlacement)
        vault.save(searchEngine.rawValue, forKey: Self.StorageKey.searchEngine)
        vault.save(customSearchTemplate, forKey: Self.StorageKey.customSearchTemplate)
        vault.save(moreMenuActionIDs, forKey: Self.StorageKey.moreMenuActionIDs)
        vault.save(customIconNames, forKey: Self.StorageKey.customIconNames)
        vault.save(customIconImageDataBySlot, forKey: Self.StorageKey.customIconImageDataBySlot)
        vault.save(history, forKey: Self.StorageKey.history)
        vault.save(essentials, forKey: Self.StorageKey.essentials)
        vault.save(downloads, forKey: Self.StorageKey.downloads)
        vault.save(localAIName, forKey: Self.StorageKey.localAIName)
        vault.save(localAIURLText, forKey: Self.StorageKey.localAIURLText)
        vault.save(isAdBlockerEnabled, forKey: Self.StorageKey.adBlockerEnabled)
        vault.save(isDarkReaderEnabled, forKey: Self.StorageKey.darkReaderEnabled)
        vault.save(isTutorialPresented == false, forKey: Self.StorageKey.hasCompletedTutorial)
        vault.save(vpnProfile, forKey: Self.StorageKey.vpnProfile)
        persistOpenTabs()
    }

    private static func loadTabs(
        vault: SecureBrowserVault,
        isDarkReaderEnabled: Bool,
        isAdBlockerEnabled: Bool
    ) -> (tabs: [BrowserTab], selectedTabID: BrowserTab.ID?) {
        let savedTabs = vault.load([PersistedBrowserTab].self, forKey: StorageKey.openTabs, default: [])
        guard savedTabs.isEmpty == false else {
            let firstTab = BrowserTab(usesPersistentStorage: false, isDarkReaderEnabled: isDarkReaderEnabled, isAdBlockerEnabled: isAdBlockerEnabled)
            return ([firstTab], firstTab.id)
        }

        var restoredTabs: [BrowserTab] = []
        var selectedID: BrowserTab.ID?

        for savedTab in savedTabs {
            guard let url = URL(string: savedTab.urlString) else { continue }
            let tab = BrowserTab(
                startURL: url,
                usesPersistentStorage: false,
                isDarkReaderEnabled: isDarkReaderEnabled,
                isAdBlockerEnabled: isAdBlockerEnabled
            )
            restoredTabs.append(tab)
            if savedTab.isSelected {
                selectedID = tab.id
            }
        }

        if restoredTabs.isEmpty {
            let firstTab = BrowserTab(usesPersistentStorage: false, isDarkReaderEnabled: isDarkReaderEnabled, isAdBlockerEnabled: isAdBlockerEnabled)
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

    private static func loadEssentials(vault: SecureBrowserVault) -> [BrowserEssentialItem] {
        vault.load([BrowserEssentialItem].self, forKey: StorageKey.essentials, default: [])
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

    private enum StorageKey {
        static let darkReaderEnabled = "ZenFireBrowser.darkReaderEnabled"
        static let chromePlacement = "ZenFireBrowser.chromePlacement"
        static let sideTabsCollapsed = "ZenFireBrowser.sideTabsCollapsed"
        static let topSearchBarEnabled = "ZenFireBrowser.topSearchBarEnabled"
        static let topSearchBarPlacement = "ZenFireBrowser.topSearchBarPlacement"
        static let searchEngine = "ZenFireBrowser.searchEngine"
        static let customSearchTemplate = "ZenFireBrowser.customSearchTemplate"
        static let moreMenuActionIDs = "ZenFireBrowser.moreMenuActionIDs"
        static let customIconNames = "ZenFireBrowser.customIconNames"
        static let customIconImageDataBySlot = "ZenFireBrowser.customIconImageDataBySlot"
        static let history = "ZenFireBrowser.history"
        static let essentials = "ZenFireBrowser.essentials"
        static let openTabs = "ZenFireBrowser.openTabs"
        static let localAIName = "ZenFireBrowser.localAIName"
        static let localAIURLText = "ZenFireBrowser.localAIURLText"
        static let adBlockerEnabled = "ZenFireBrowser.adBlockerEnabled"
        static let hasCompletedTutorial = "ZenFireBrowser.hasCompletedTutorial"
        static let downloads = "ZenFireBrowser.downloads"
        static let vpnProfile = "ZenFireBrowser.vpnProfile"
    }
}
