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
    @Published var chromePlacement: BrowserChromePlacement = .left
    @Published var isFloatingSearchPresented = false
    @Published var isSettingsPresented = false
    @Published var isDarkReaderEnabled: Bool

    init() {
        let darkReaderEnabled = UserDefaults.standard.bool(forKey: "ZenFireBrowser.darkReaderEnabled")
        let firstTab = BrowserTab(isDarkReaderEnabled: darkReaderEnabled)
        self.tabs = [firstTab]
        self.selectedTabID = firstTab.id
        self.isDarkReaderEnabled = darkReaderEnabled
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
    }

    func openTab(private isPrivate: Bool = false) {
        let tab = BrowserTab(isPrivate: isPrivate, isDarkReaderEnabled: isDarkReaderEnabled)
        tabs.append(tab)
        selectedTabID = tab.id
    }

    func openPrivateTab() {
        openTab(private: true)
    }

    func close(_ tab: BrowserTab) {
        guard tabs.count > 1 else {
            tab.load(BrowserTab.homeURL)
            return
        }

        let wasSelected = selectedTabID == tab.id
        tabs.removeAll { $0.id == tab.id }

        if wasSelected {
            selectedTabID = tabs.last?.id
        }
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
        selectedTab?.submitAddress()
        isFloatingSearchPresented = false
    }

    func openFloatingSearch() {
        isFloatingSearchPresented = true
    }

    func setDarkReaderEnabled(_ enabled: Bool) {
        isDarkReaderEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: "ZenFireBrowser.darkReaderEnabled")
        for tab in tabs {
            tab.setDarkReaderEnabled(enabled)
        }
    }
}
