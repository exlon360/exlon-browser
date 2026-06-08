import Combine
import CoreGraphics
import Foundation

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

@MainActor
final class BrowserViewModel: ObservableObject {
    @Published var tabs: [BrowserTab]
    @Published var selectedTabID: BrowserTab.ID?
    @Published var containedTabs: [BrowserTab] = []
    @Published var selectedContainedTabID: BrowserTab.ID?
    @Published var isContainedBrowserPresented = false
    @Published var chromePlacement: BrowserChromePlacement {
        didSet {
            UserDefaults.standard.set(chromePlacement.rawValue, forKey: Self.StorageKey.chromePlacement)
        }
    }
    @Published var isFloatingSearchPresented = false
    @Published var floatingSearchText = ""
    @Published var shouldSelectFloatingSearchText = false
    @Published var isSettingsPresented = false
    @Published var isHistoryPresented = false
    @Published var isDownloadsPresented = false
    @Published var isVPNPresented = false
    @Published var isWebFileImporterPresented = false
    @Published var allowsMultipleWebFileImport = false
    @Published var isLocalAIImporterPresented = false
    @Published var isTutorialPresented: Bool
    @Published var isDarkReaderEnabled: Bool
    @Published var isAdBlockerEnabled: Bool
    @Published var areSideTabsCollapsed: Bool {
        didSet {
            UserDefaults.standard.set(areSideTabsCollapsed, forKey: Self.StorageKey.sideTabsCollapsed)
        }
    }
    @Published var searchEngine: BrowserSearchEngine {
        didSet {
            UserDefaults.standard.set(searchEngine.rawValue, forKey: Self.StorageKey.searchEngine)
        }
    }
    @Published var customSearchTemplate: String {
        didSet {
            UserDefaults.standard.set(customSearchTemplate, forKey: Self.StorageKey.customSearchTemplate)
        }
    }
    @Published var history: [BrowserHistoryItem]
    @Published var downloads: [BrowserDownloadItem]
    @Published var localAIName: String {
        didSet {
            UserDefaults.standard.set(localAIName, forKey: Self.StorageKey.localAIName)
        }
    }
    @Published var localAIURLText: String {
        didSet {
            UserDefaults.standard.set(localAIURLText, forKey: Self.StorageKey.localAIURLText)
        }
    }
    @Published var vpnProfile: CustomVPNProfile {
        didSet {
            persistVPNProfile()
        }
    }
    @Published var vpnStatusMessage = "Custom VPN profile not configured."
    private var pendingWebFileImportCompletion: (([URL]?) -> Void)?

    init() {
        let defaults = UserDefaults.standard
        let darkReaderEnabled = defaults.bool(forKey: Self.StorageKey.darkReaderEnabled)
        let adBlockerEnabled = defaults.object(forKey: Self.StorageKey.adBlockerEnabled) as? Bool ?? true
        let placement = BrowserChromePlacement(rawValue: defaults.string(forKey: Self.StorageKey.chromePlacement) ?? "") ?? .left
        let selectedSearchEngine = BrowserSearchEngine(rawValue: defaults.string(forKey: Self.StorageKey.searchEngine) ?? "") ?? .duckDuckGo
        let savedCustomSearch = defaults.string(forKey: Self.StorageKey.customSearchTemplate) ?? BrowserSearchEngine.defaultCustomTemplate
        let savedHistory = Self.loadHistory()
        let savedDownloads = Self.loadDownloads()
        let savedVPNProfile = Self.loadVPNProfile()
        let restoredTabs = Self.loadTabs(isDarkReaderEnabled: darkReaderEnabled, isAdBlockerEnabled: adBlockerEnabled)

        self.chromePlacement = placement
        self.areSideTabsCollapsed = defaults.bool(forKey: Self.StorageKey.sideTabsCollapsed)
        self.searchEngine = selectedSearchEngine
        self.customSearchTemplate = savedCustomSearch
        self.history = savedHistory
        self.downloads = savedDownloads
        self.isTutorialPresented = defaults.bool(forKey: Self.StorageKey.hasCompletedTutorial) == false
        self.isDarkReaderEnabled = darkReaderEnabled
        self.isAdBlockerEnabled = adBlockerEnabled
        self.localAIName = defaults.string(forKey: Self.StorageKey.localAIName) ?? "Local AI"
        self.localAIURLText = defaults.string(forKey: Self.StorageKey.localAIURLText) ?? ""
        self.vpnProfile = savedVPNProfile
        self.vpnStatusMessage = savedVPNProfile.isConfigured ? "Custom VPN profile saved." : "Custom VPN profile not configured."
        self.tabs = restoredTabs.tabs
        self.selectedTabID = restoredTabs.selectedTabID

        for tab in tabs {
            configure(tab)
        }
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

    @discardableResult
    func openTab(startURL: URL = BrowserDefaults.homeURL, private isPrivate: Bool = false) -> BrowserTab {
        let tab = BrowserTab(
            startURL: startURL,
            isPrivate: isPrivate,
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
    func openContainedTab(startURL: URL = BrowserDefaults.homeURL) -> BrowserTab {
        let tab = BrowserTab(
            startURL: startURL,
            usesPersistentStorage: false,
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
        UserDefaults.standard.set(enabled, forKey: Self.StorageKey.darkReaderEnabled)
        for tab in tabs {
            tab.setDarkReaderEnabled(enabled)
        }
        for tab in containedTabs {
            tab.setDarkReaderEnabled(enabled)
        }
    }

    func setAdBlockerEnabled(_ enabled: Bool) {
        isAdBlockerEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: Self.StorageKey.adBlockerEnabled)
        for tab in tabs {
            tab.setAdBlockerEnabled(enabled)
        }
        for tab in containedTabs {
            tab.setAdBlockerEnabled(enabled)
        }
    }

    func toggleSideTabs() {
        areSideTabsCollapsed.toggle()
    }

    func completeTutorial() {
        isTutorialPresented = false
        UserDefaults.standard.set(true, forKey: Self.StorageKey.hasCompletedTutorial)
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

    func clearHistory() {
        history = []
        saveHistory()
    }

    func clearDownloads() {
        downloads = []
        saveDownloads()
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
        searchEngine = .duckDuckGo
        customSearchTemplate = BrowserSearchEngine.defaultCustomTemplate
        localAIName = "Local AI"
        localAIURLText = ""
        setAdBlockerEnabled(true)
        setDarkReaderEnabled(false)
        saveVPNProfile(.empty)
    }

    private func configure(_ tab: BrowserTab) {
        tab.onNavigationFinished = { [weak self] tab in
            self?.recordVisit(from: tab)
        }
        tab.onDownloadUpdated = { [weak self] item in
            self?.updateDownload(item)
        }
        tab.onTwoFingerSwipe = { [weak self] in
            self?.toggleSideTabs()
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
        tab.onTwoFingerSwipe = { [weak self] in
            self?.toggleSideTabs()
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

        guard let data = try? JSONEncoder().encode(persistedTabs) else { return }
        UserDefaults.standard.set(data, forKey: Self.StorageKey.openTabs)
    }

    private func saveHistory() {
        guard let data = try? JSONEncoder().encode(history) else { return }
        UserDefaults.standard.set(data, forKey: Self.StorageKey.history)
    }

    private func updateDownload(_ item: BrowserDownloadItem) {
        downloads.removeAll { $0.id == item.id || $0.localPath == item.localPath }
        downloads.insert(item, at: 0)
        if downloads.count > 100 {
            downloads = Array(downloads.prefix(100))
        }
        saveDownloads()
    }

    private func saveDownloads() {
        guard let data = try? JSONEncoder().encode(downloads) else { return }
        UserDefaults.standard.set(data, forKey: Self.StorageKey.downloads)
    }

    private func persistVPNProfile() {
        guard let data = try? JSONEncoder().encode(vpnProfile) else { return }
        UserDefaults.standard.set(data, forKey: Self.StorageKey.vpnProfile)
    }

    private static func loadTabs(
        isDarkReaderEnabled: Bool,
        isAdBlockerEnabled: Bool
    ) -> (tabs: [BrowserTab], selectedTabID: BrowserTab.ID?) {
        let defaults = UserDefaults.standard
        guard let data = defaults.data(forKey: StorageKey.openTabs),
              let savedTabs = try? JSONDecoder().decode([PersistedBrowserTab].self, from: data),
              savedTabs.isEmpty == false else {
            let firstTab = BrowserTab(isDarkReaderEnabled: isDarkReaderEnabled, isAdBlockerEnabled: isAdBlockerEnabled)
            return ([firstTab], firstTab.id)
        }

        var restoredTabs: [BrowserTab] = []
        var selectedID: BrowserTab.ID?

        for savedTab in savedTabs {
            guard let url = URL(string: savedTab.urlString) else { continue }
            let tab = BrowserTab(
                startURL: url,
                isDarkReaderEnabled: isDarkReaderEnabled,
                isAdBlockerEnabled: isAdBlockerEnabled
            )
            restoredTabs.append(tab)
            if savedTab.isSelected {
                selectedID = tab.id
            }
        }

        if restoredTabs.isEmpty {
            let firstTab = BrowserTab(isDarkReaderEnabled: isDarkReaderEnabled, isAdBlockerEnabled: isAdBlockerEnabled)
            return ([firstTab], firstTab.id)
        }

        return (restoredTabs, selectedID ?? restoredTabs.first?.id)
    }

    private static func loadHistory() -> [BrowserHistoryItem] {
        guard let data = UserDefaults.standard.data(forKey: StorageKey.history),
              let history = try? JSONDecoder().decode([BrowserHistoryItem].self, from: data) else {
            return []
        }

        return history
    }

    private static func loadDownloads() -> [BrowserDownloadItem] {
        guard let data = UserDefaults.standard.data(forKey: StorageKey.downloads),
              let downloads = try? JSONDecoder().decode([BrowserDownloadItem].self, from: data) else {
            return []
        }

        return downloads
    }

    private static func loadVPNProfile() -> CustomVPNProfile {
        guard let data = UserDefaults.standard.data(forKey: StorageKey.vpnProfile),
              let profile = try? JSONDecoder().decode(CustomVPNProfile.self, from: data) else {
            return .empty
        }

        return profile
    }

    private static func shouldPersist(url: URL) -> Bool {
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
        static let searchEngine = "ZenFireBrowser.searchEngine"
        static let customSearchTemplate = "ZenFireBrowser.customSearchTemplate"
        static let history = "ZenFireBrowser.history"
        static let openTabs = "ZenFireBrowser.openTabs"
        static let localAIName = "ZenFireBrowser.localAIName"
        static let localAIURLText = "ZenFireBrowser.localAIURLText"
        static let adBlockerEnabled = "ZenFireBrowser.adBlockerEnabled"
        static let hasCompletedTutorial = "ZenFireBrowser.hasCompletedTutorial"
        static let downloads = "ZenFireBrowser.downloads"
        static let vpnProfile = "ZenFireBrowser.vpnProfile"
    }
}
