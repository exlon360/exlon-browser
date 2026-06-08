import Combine
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
    @Published var chromePlacement: BrowserChromePlacement {
        didSet {
            UserDefaults.standard.set(chromePlacement.rawValue, forKey: Self.StorageKey.chromePlacement)
        }
    }
    @Published var isFloatingSearchPresented = false
    @Published var isSettingsPresented = false
    @Published var isHistoryPresented = false
    @Published var isLocalAIImporterPresented = false
    @Published var isDarkReaderEnabled: Bool
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

    init() {
        let defaults = UserDefaults.standard
        let darkReaderEnabled = defaults.bool(forKey: Self.StorageKey.darkReaderEnabled)
        let placement = BrowserChromePlacement(rawValue: defaults.string(forKey: Self.StorageKey.chromePlacement) ?? "") ?? .left
        let selectedSearchEngine = BrowserSearchEngine(rawValue: defaults.string(forKey: Self.StorageKey.searchEngine) ?? "") ?? .duckDuckGo
        let savedCustomSearch = defaults.string(forKey: Self.StorageKey.customSearchTemplate) ?? BrowserSearchEngine.defaultCustomTemplate
        let savedHistory = Self.loadHistory()
        let restoredTabs = Self.loadTabs(isDarkReaderEnabled: darkReaderEnabled)

        self.chromePlacement = placement
        self.areSideTabsCollapsed = defaults.bool(forKey: Self.StorageKey.sideTabsCollapsed)
        self.searchEngine = selectedSearchEngine
        self.customSearchTemplate = savedCustomSearch
        self.history = savedHistory
        self.isDarkReaderEnabled = darkReaderEnabled
        self.localAIName = defaults.string(forKey: Self.StorageKey.localAIName) ?? "Local AI"
        self.localAIURLText = defaults.string(forKey: Self.StorageKey.localAIURLText) ?? ""
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

    var normalTabs: [BrowserTab] {
        tabs.filter { !$0.isPrivate }
    }

    var privateTabs: [BrowserTab] {
        tabs.filter { $0.isPrivate }
    }

    func select(_ tab: BrowserTab) {
        selectedTabID = tab.id
        persistOpenTabs()
    }

    func openTab(startURL: URL = BrowserTab.homeURL, private isPrivate: Bool = false) {
        let tab = BrowserTab(startURL: startURL, isPrivate: isPrivate, isDarkReaderEnabled: isDarkReaderEnabled)
        configure(tab)
        tabs.append(tab)
        selectedTabID = tab.id
        persistOpenTabs()
    }

    func openPrivateTab() {
        openTab(private: true)
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
        selectedTab?.webView.goBack()
    }

    func goForward() {
        selectedTab?.webView.goForward()
    }

    func reloadOrStop() {
        selectedTab?.reloadOrStop()
    }

    func submitAddress() {
        selectedTab?.submitAddress(searchEngine: searchEngine, customSearchTemplate: customSearchTemplate)
        isFloatingSearchPresented = false
    }

    func openFloatingSearch() {
        isFloatingSearchPresented = true
    }

    func setDarkReaderEnabled(_ enabled: Bool) {
        isDarkReaderEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: Self.StorageKey.darkReaderEnabled)
        for tab in tabs {
            tab.setDarkReaderEnabled(enabled)
        }
    }

    func toggleSideTabs() {
        areSideTabsCollapsed.toggle()
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

    func resetToDefaults() {
        chromePlacement = .left
        areSideTabsCollapsed = false
        searchEngine = .duckDuckGo
        customSearchTemplate = BrowserSearchEngine.defaultCustomTemplate
        localAIName = "Local AI"
        localAIURLText = ""
        setDarkReaderEnabled(false)
    }

    private func configure(_ tab: BrowserTab) {
        tab.onNavigationFinished = { [weak self] tab in
            self?.recordVisit(from: tab)
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

    private static func loadTabs(isDarkReaderEnabled: Bool) -> (tabs: [BrowserTab], selectedTabID: BrowserTab.ID?) {
        let defaults = UserDefaults.standard
        guard let data = defaults.data(forKey: StorageKey.openTabs),
              let savedTabs = try? JSONDecoder().decode([PersistedBrowserTab].self, from: data),
              savedTabs.isEmpty == false else {
            let firstTab = BrowserTab(isDarkReaderEnabled: isDarkReaderEnabled)
            return ([firstTab], firstTab.id)
        }

        var restoredTabs: [BrowserTab] = []
        var selectedID: BrowserTab.ID?

        for savedTab in savedTabs {
            guard let url = URL(string: savedTab.urlString) else { continue }
            let tab = BrowserTab(startURL: url, isDarkReaderEnabled: isDarkReaderEnabled)
            restoredTabs.append(tab)
            if savedTab.isSelected {
                selectedID = tab.id
            }
        }

        if restoredTabs.isEmpty {
            let firstTab = BrowserTab(isDarkReaderEnabled: isDarkReaderEnabled)
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
    }
}
