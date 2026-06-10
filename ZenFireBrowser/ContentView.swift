import SwiftUI
import PhotosUI
import QuickLook
import UIKit
import UniformTypeIdentifiers

struct ContentView: View {
    @StateObject private var security = AppSecurityModel()

    var body: some View {
        Group {
            if let vault = security.vault {
                BrowserUnlockedRoot(vault: vault)
                    .id("unlocked")
                    .transition(.opacity.combined(with: .scale(scale: 0.985)))
            } else {
                BrowserLockView()
                    .id("locked")
                    .transition(.opacity.combined(with: .scale(scale: 1.015)))
            }
        }
        .environmentObject(security)
        .animation(.spring(response: 0.32, dampingFraction: 0.88), value: security.isUnlocked)
        .preferredColorScheme(.dark)
    }
}

private struct BrowserUnlockedRoot: View {
    @StateObject private var model: BrowserViewModel
    @StateObject private var theme: BrowserTheme

    init(vault: SecureBrowserVault) {
        _model = StateObject(wrappedValue: BrowserViewModel(vault: vault))
        _theme = StateObject(wrappedValue: BrowserTheme(vault: vault))
    }

    var body: some View {
        BrowserShell()
            .environmentObject(model)
            .environmentObject(theme)
            .preferredColorScheme(.dark)
    }
}

private struct BrowserLockView: View {
    @EnvironmentObject private var security: AppSecurityModel
    @State private var pin = ""
    @State private var confirmation = ""
    @FocusState private var focusedField: LockField?

    private enum LockField {
        case pin
        case confirmation
    }

    var body: some View {
        ZStack {
            SecureLockBackground()

            VStack(spacing: 22) {
                Spacer(minLength: 18)

                VStack(spacing: 18) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(.ultraThinMaterial)
                            .overlay {
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .fill(Color(red: 0.08, green: 0.09, blue: 0.12).opacity(0.72))
                            }
                            .overlay {
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .stroke(Color.white.opacity(0.22), lineWidth: 1)
                            }

                        Image(systemName: security.isConfigured ? "lock.shield.fill" : "lock.badge.plus")
                            .font(.system(size: 30, weight: .black))
                            .foregroundStyle(Color(red: 0.84, green: 0.89, blue: 1.0))
                    }
                    .frame(width: 74, height: 74)
                    .shadow(color: Color.black.opacity(0.34), radius: 22, y: 14)

                    VStack(spacing: 8) {
                        Text(security.isConfigured ? "Glide is locked" : "Secure Glide")
                            .font(.system(size: 34, weight: .black))
                            .foregroundStyle(Color(red: 0.96, green: 0.98, blue: 1.0))
                            .multilineTextAlignment(.center)

                        Text(security.isConfigured ? "Enter your PIN to open the encrypted vault." : "Create a PIN for the encrypted browser vault.")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Color.white.opacity(0.66))
                            .multilineTextAlignment(.center)
                    }
                }
                .frame(maxWidth: 520)
                .padding(.horizontal, 24)

                VStack(spacing: 12) {
                    SecurePINField(
                        title: security.isConfigured ? "PIN" : "New PIN",
                        text: $pin
                    )
                    .focused($focusedField, equals: .pin)
                    .onSubmit(submit)

                    if security.isConfigured == false {
                        SecurePINField(title: "Confirm PIN", text: $confirmation)
                            .focused($focusedField, equals: .confirmation)
                            .onSubmit(submit)
                    }

                    if security.message.isEmpty == false {
                        Text(security.message)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color(red: 1.0, green: 0.64, blue: 0.64))
                            .multilineTextAlignment(.center)
                            .transition(.opacity)
                    }
                }
                .frame(maxWidth: 440)
                .padding(.horizontal, 24)

                VStack(spacing: 10) {
                    Button(action: submit) {
                        HStack(spacing: 10) {
                            Text(security.isConfigured ? "Unlock" : "Create PIN")
                                .font(.system(size: 16, weight: .bold))
                            Image(systemName: "arrow.right")
                                .font(.system(size: 14, weight: .black))
                        }
                        .frame(maxWidth: 440)
                        .frame(height: 54)
                        .foregroundStyle(Color(red: 0.05, green: 0.06, blue: 0.08))
                        .background(Color(red: 0.84, green: 0.89, blue: 1.0), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .disabled(canSubmit == false)
                    .opacity(canSubmit ? 1 : 0.48)
                    .accessibilityLabel(security.isConfigured ? "Unlock Glide" : "Create Glide PIN")

                    if security.isConfigured && security.isBiometricAvailable {
                        Button {
                            security.unlockWithBiometrics()
                        } label: {
                            Label("Use \(security.biometricTitle)", systemImage: "faceid")
                                .font(.system(size: 15, weight: .bold))
                                .frame(maxWidth: 440)
                                .frame(height: 48)
                                .foregroundStyle(Color.white.opacity(0.92))
                                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(Color.white.opacity(0.18), lineWidth: 1)
                                }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 24)

                Spacer(minLength: 18)
            }
        }
        .onAppear {
            security.refreshBiometricAvailability()
            focusedField = .pin
        }
        .onChange(of: pin) { _, value in
            let cleaned = sanitizedPIN(value)
            if cleaned != value {
                pin = cleaned
            }
        }
        .onChange(of: confirmation) { _, value in
            let cleaned = sanitizedPIN(value)
            if cleaned != value {
                confirmation = cleaned
            }
        }
    }

    private var canSubmit: Bool {
        if security.isConfigured {
            return pin.trimmingCharacters(in: .whitespacesAndNewlines).count >= 4
        }

        return pin.count >= 4 && confirmation.count >= 4
    }

    private func submit() {
        if security.isConfigured {
            security.unlock(pin: pin)
        } else {
            security.setup(pin: pin, confirmation: confirmation)
        }
    }

    private func sanitizedPIN(_ value: String) -> String {
        String(value.filter { $0.isNumber }.prefix(12))
    }
}

private struct SecurePINField: View {
    let title: String
    @Binding var text: String

    var body: some View {
        SecureField(title, text: $text)
            .textContentType(.oneTimeCode)
            .keyboardType(.numberPad)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .font(.system(size: 18, weight: .bold, design: .monospaced))
            .foregroundStyle(Color.white)
            .tint(Color(red: 0.84, green: 0.89, blue: 1.0))
            .padding(.horizontal, 16)
            .frame(height: 54)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.white.opacity(0.18), lineWidth: 1)
            }
            .privacySensitive()
    }
}

private struct SecureLockBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.03, green: 0.035, blue: 0.05),
                    Color(red: 0.08, green: 0.09, blue: 0.12),
                    Color(red: 0.02, green: 0.025, blue: 0.035)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            Rectangle()
                .fill(.ultraThinMaterial)
                .opacity(0.08)
                .ignoresSafeArea()
        }
    }
}

private struct BrowserShell: View {
    @EnvironmentObject private var model: BrowserViewModel
    @EnvironmentObject private var theme: BrowserTheme
    @EnvironmentObject private var security: AppSecurityModel

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                BrowserBackground()

                switch model.chromePlacement {
                case .left:
                    SideBrowserLayout(edge: .left, sideWidth: sideWidth(for: proxy))
                case .right:
                    SideBrowserLayout(edge: .right, sideWidth: sideWidth(for: proxy))
                case .top:
                    ZStack(alignment: .top) {
                        BrowserContent()
                        if model.areSideTabsCollapsed == false {
                            HorizontalChrome(edge: .top)
                                .transition(.move(edge: .top).combined(with: .opacity))
                        }
                    }
                case .bottom:
                    ZStack(alignment: .bottom) {
                        BrowserContent()
                        if model.areSideTabsCollapsed == false {
                            HorizontalChrome(edge: .bottom)
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                        }
                    }
                case .floating:
                    BrowserContent()
                    if model.areSideTabsCollapsed == false {
                        FloatingChrome()
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }

                BrowserPageControls()
                    .padding(.leading, pageControlsLeadingPadding(for: proxy))
                    .padding(.top, pageControlsTopPadding)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

                if model.isTopSearchBarEnabled {
                    BrowserTopSearchBar()
                        .padding(.top, topSearchBarTopPadding)
                        .padding(.horizontal, 16)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                if model.isContainedBrowserPresented {
                    ContainedBrowserOverlay()
                        .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .center)))
                }

                if model.isFloatingSearchPresented {
                    FloatingSearchOverlay()
                        .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .top)))
                }
            }
            .animation(.spring(response: 0.25, dampingFraction: 0.86), value: model.isFloatingSearchPresented)
            .animation(.spring(response: 0.27, dampingFraction: 0.86), value: model.isContainedBrowserPresented)
            .animation(.spring(response: 0.28, dampingFraction: 0.84), value: model.areSideTabsCollapsed)
            .ignoresSafeArea(.keyboard, edges: .bottom)
            .sheet(isPresented: $model.isSettingsPresented) {
                BrowserSettingsView()
                    .environmentObject(model)
                    .environmentObject(theme)
                    .environmentObject(security)
                    .preferredColorScheme(.dark)
            }
            .sheet(isPresented: $model.isTabFinderPresented) {
                BrowserTabFinderView()
                    .environmentObject(model)
                    .environmentObject(theme)
                    .preferredColorScheme(.dark)
            }
            .sheet(isPresented: $model.isHistoryPresented) {
                BrowserHistoryView()
                    .environmentObject(model)
                    .environmentObject(theme)
                    .preferredColorScheme(.dark)
            }
            .sheet(isPresented: $security.isCrashLogsPresented) {
                CrashLogsView()
                    .environmentObject(security)
                    .environmentObject(theme)
                    .preferredColorScheme(.dark)
            }
            .sheet(isPresented: $model.isDownloadsPresented) {
                BrowserDownloadsView()
                    .environmentObject(model)
                    .environmentObject(theme)
                    .preferredColorScheme(.dark)
            }
            .sheet(isPresented: $model.isVPNPresented) {
                CustomVPNView()
                    .environmentObject(model)
                    .environmentObject(theme)
                    .preferredColorScheme(.dark)
            }
            .sheet(isPresented: $model.isAddOnsPresented) {
                AddOnsLibraryView()
                    .environmentObject(model)
                    .environmentObject(theme)
                    .preferredColorScheme(.dark)
            }
            .sheet(isPresented: $model.isAdvancedConfigPresented) {
                AdvancedConfigView()
                    .environmentObject(model)
                    .environmentObject(theme)
                    .preferredColorScheme(.dark)
            }
            .sheet(isPresented: $model.isCustomIconsPresented) {
                CustomIconsView()
                    .environmentObject(model)
                    .environmentObject(theme)
                    .preferredColorScheme(.dark)
            }
            .sheet(isPresented: $model.isLocalAIImporterPresented) {
                LocalAIImportView()
                    .environmentObject(model)
                    .environmentObject(theme)
                    .preferredColorScheme(.dark)
            }
            .fullScreenCover(isPresented: $model.isTutorialPresented) {
                FirstRunTutorialView()
                    .environmentObject(model)
                    .environmentObject(theme)
                    .preferredColorScheme(.dark)
                    .interactiveDismissDisabled()
            }
            .fileImporter(
                isPresented: $model.isWebFileImporterPresented,
                allowedContentTypes: [.item],
                allowsMultipleSelection: model.allowsMultipleWebFileImport
            ) { result in
                model.completeWebFileImport(result)
            }
            .onAppear {
                security.presentCrashLogsIfNeeded()
            }
        }
        .tint(theme.color(.accent))
    }

    private func sideWidth(for proxy: GeometryProxy) -> CGFloat {
        min(max(proxy.size.width * 0.3, 286), 360)
    }

    private func pageControlsLeadingPadding(for proxy: GeometryProxy) -> CGFloat {
        if model.chromePlacement == .left && model.areSideTabsCollapsed == false {
            return sideWidth(for: proxy) + 18
        }
        return 14
    }

    private var pageControlsTopPadding: CGFloat {
        if model.isTopSearchBarEnabled {
            return topSearchBarTopPadding + 62
        }

        if model.chromePlacement == .top && model.areSideTabsCollapsed == false {
            return 118
        }
        return 14
    }

    private var topSearchBarTopPadding: CGFloat {
        if model.chromePlacement == .top && model.areSideTabsCollapsed == false {
            return 112
        }
        return 12
    }
}

private extension BrowserTheme {
    var chromeForegroundColor: Color {
        isUserBackgroundEnabled && hasUserBackground ? .white : color(.text)
    }

    var chromeSecondaryForegroundColor: Color {
        isUserBackgroundEnabled && hasUserBackground ? Color.white.opacity(0.72) : color(.mutedText)
    }
}

private struct BrowserContent: View {
    @EnvironmentObject private var model: BrowserViewModel
    @EnvironmentObject private var theme: BrowserTheme

    var body: some View {
        ZStack {
            theme.color(.canvas)
                .opacity(theme.isUserBackgroundEnabled && theme.hasUserBackground ? 0.18 : 1)

            if let tab = model.selectedTab {
                BrowserWebView(tab: tab)
                    .id(tab.id)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(alignment: .top) {
                        LoadingProgress(tab: tab)
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(theme.color(.border).opacity(0.5), lineWidth: 1)
                    }
                    .padding(browserPadding)
            }
        }
    }

    private var browserPadding: EdgeInsets {
        model.chromePlacement == .floating
            ? EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8)
            : EdgeInsets(top: 6, leading: 6, bottom: 6, trailing: 6)
    }
}

private struct LoadingProgress: View {
    @ObservedObject var tab: BrowserTab
    @EnvironmentObject private var theme: BrowserTheme

    var body: some View {
        GeometryReader { proxy in
            if tab.isLoading {
                Rectangle()
                    .fill(theme.color(.accent))
                    .frame(width: max(12, proxy.size.width * tab.estimatedProgress), height: 2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .animation(.easeOut(duration: 0.18), value: tab.estimatedProgress)
            }
        }
        .frame(height: 2)
    }
}

private enum SideChromeEdge {
    case left
    case right
}

private struct SideBrowserLayout: View {
    @EnvironmentObject private var model: BrowserViewModel
    let edge: SideChromeEdge
    let sideWidth: CGFloat

    var body: some View {
        ZStack(alignment: edge == .left ? .leading : .trailing) {
            BrowserContent()

            if model.areSideTabsCollapsed == false {
                SideChrome(edge: edge)
                    .frame(width: sideWidth)
                    .transition(chromeTransition)
            }
        }
        .animation(.spring(response: 0.24, dampingFraction: 0.88), value: model.areSideTabsCollapsed)
    }

    private var chromeTransition: AnyTransition {
        edge == .left
            ? .move(edge: .leading).combined(with: .opacity)
            : .move(edge: .trailing).combined(with: .opacity)
    }
}

private struct SideChrome: View {
    @EnvironmentObject private var model: BrowserViewModel
    @EnvironmentObject private var theme: BrowserTheme
    let edge: SideChromeEdge

    var body: some View {
        VStack(spacing: 12) {
            ChromeHeader(compact: true)

            SearchTrigger(style: .sidebar)

            NewTabActions(layout: .sidebar)

            TabBarStyleControl(compact: false)

            if model.essentials.isEmpty == false {
                EssentialsSection()
            }

            TabSection(title: "Tabs", tabs: model.normalTabs)

            if model.privateTabs.isEmpty == false {
                TabSection(title: "Private", tabs: model.privateTabs)
            }

            Spacer(minLength: 8)

            ChromeFooter()
        }
        .padding(.top, 12)
        .padding(.bottom, 12)
        .padding(.horizontal, 12)
        .frame(maxHeight: .infinity)
        .background(ChromeGlassBackground(cornerRadius: 0))
        .shadow(color: Color.black.opacity(0.24), radius: 18, x: edge == .left ? 8 : -8, y: 0)
        .overlay(alignment: edge == .left ? .trailing : .leading) {
            Rectangle()
                .fill(theme.color(.border).opacity(0.65))
                .frame(width: 1)
        }
    }
}

private struct HorizontalChrome: View {
    @EnvironmentObject private var model: BrowserViewModel
    @EnvironmentObject private var theme: BrowserTheme
    let edge: VerticalEdge

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                ChromeHeader(compact: false)
                SearchTrigger(style: .bar)
                ChromeFooter()
                TabBarStyleControl(compact: true)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    NewTabActions(layout: .strip)

                    ForEach(model.essentials) { item in
                        EssentialPill(item: item, layout: .horizontal)
                    }

                    ForEach(model.tabs) { tab in
                        TabPill(tab: tab, layout: .horizontal)
                    }
                }
                .padding(.horizontal, 2)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background(ChromeGlassBackground(cornerRadius: 0))
        .shadow(color: Color.black.opacity(0.22), radius: 16, x: 0, y: edge == .top ? 8 : -8)
        .overlay(alignment: edge == .top ? .bottom : .top) {
            Rectangle()
                .fill(theme.color(.border).opacity(0.65))
                .frame(height: 1)
        }
    }
}

private struct FloatingChrome: View {
    @EnvironmentObject private var model: BrowserViewModel
    @EnvironmentObject private var theme: BrowserTheme

    var body: some View {
        VStack {
            Spacer()

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ChromeButton(slot: .search, symbol: "magnifyingglass", label: "Search") {
                        model.openFloatingSearch()
                    }

                    if model.isInMoreMenu(.forward) == false {
                        ChromeButton(slot: .forward, symbol: "chevron.right", label: "Forward") {
                            model.goForward()
                        }
                        .disabled(model.selectedTab?.canGoForward != true)
                    }

                    FloatingTabSwitcher()

                    if model.isInMoreMenu(.tabFinder) == false {
                        ChromeButton(slot: .tabFinder, symbol: "square.grid.2x2", label: "Tab Finder") {
                            model.isTabFinderPresented = true
                        }
                    }

                    if model.isInMoreMenu(.containedTabs) == false {
                        ChromeButton(slot: .containedTabs, symbol: "rectangle.on.rectangle", label: "Contained Tabs") {
                            model.showContainedTabs()
                        }
                    }

                    if model.isInMoreMenu(.reload) == false {
                        ChromeButton(slot: model.selectedTab?.isLoading == true ? nil : .reload, symbol: model.selectedTab?.isLoading == true ? "xmark" : "arrow.clockwise", label: "Reload") {
                            model.reloadOrStop()
                        }
                    }

                    if model.isInMoreMenu(.downloadCurrent) == false {
                        ChromeButton(slot: .downloadCurrent, symbol: "arrow.down.doc", label: "Download Current Page") {
                            model.downloadSelectedTab()
                        }
                    }

                    if model.isInMoreMenu(.history) == false {
                        ChromeButton(slot: .history, symbol: "clock.arrow.circlepath", label: "History") {
                            model.isHistoryPresented = true
                        }
                    }

                    if model.isInMoreMenu(.downloads) == false {
                        ChromeButton(slot: .downloads, symbol: "arrow.down.circle", label: "Downloads") {
                            model.isDownloadsPresented = true
                        }
                    }

                    TabBarStyleControl(compact: true)

                    if model.isInMoreMenu(.settings) == false {
                        ChromeButton(slot: .settings, symbol: "gearshape", label: "Settings") {
                            model.isSettingsPresented = true
                        }
                    }
                }
                .padding(8)
            }
            .background(FloatingChromeBackground())
            .overlay {
                Capsule()
                    .stroke(theme.color(.border).opacity(0.75), lineWidth: 1)
            }
            .shadow(color: Color.black.opacity(0.34), radius: 20, y: 12)
            .padding(.horizontal, 12)
            .padding(.bottom, 14)
        }
    }
}

private struct ChromeHeader: View {
    @EnvironmentObject private var model: BrowserViewModel
    @EnvironmentObject private var theme: BrowserTheme
    let compact: Bool

    var body: some View {
        HStack(spacing: 8) {
            BrandMark()

            if compact == false {
                Text("Glide")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(theme.chromeForegroundColor)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
    }
}

private struct ChromeFooter: View {
    @EnvironmentObject private var model: BrowserViewModel

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                if model.isInMoreMenu(.forward) == false {
                    ChromeButton(slot: .forward, symbol: "chevron.right", label: "Forward") {
                        model.goForward()
                    }
                    .disabled(model.selectedTab?.canGoForward != true)
                }

                if model.isInMoreMenu(.reload) == false {
                    ChromeButton(slot: model.selectedTab?.isLoading == true ? nil : .reload, symbol: model.selectedTab?.isLoading == true ? "xmark" : "arrow.clockwise", label: "Reload") {
                        model.reloadOrStop()
                    }
                }

                if model.isInMoreMenu(.history) == false {
                    ChromeButton(slot: .history, symbol: "clock.arrow.circlepath", label: "History") {
                        model.isHistoryPresented = true
                    }
                }

                if model.isInMoreMenu(.tabFinder) == false {
                    ChromeButton(slot: .tabFinder, symbol: "square.grid.2x2", label: "Tab Finder") {
                        model.isTabFinderPresented = true
                    }
                }

                if model.isInMoreMenu(.downloadCurrent) == false {
                    ChromeButton(slot: .downloadCurrent, symbol: "arrow.down.doc", label: "Download Current Page") {
                        model.downloadSelectedTab()
                    }
                }

                if model.isInMoreMenu(.downloads) == false {
                    ChromeButton(slot: .downloads, symbol: "arrow.down.circle", label: "Downloads") {
                        model.isDownloadsPresented = true
                    }
                }

                if model.isInMoreMenu(.containedTabs) == false {
                    ChromeButton(slot: .containedTabs, symbol: "rectangle.on.rectangle", label: "Contained Tabs") {
                        model.showContainedTabs()
                    }
                }

                if model.isInMoreMenu(.placement) == false {
                    PlacementMenu()
                }

                if model.isInMoreMenu(.settings) == false {
                    ChromeButton(slot: .settings, symbol: "gearshape", label: "Settings") {
                        model.isSettingsPresented = true
                    }
                }
            }
        }
    }
}

private struct ChromeGlassBackground: View {
    @EnvironmentObject private var theme: BrowserTheme
    let cornerRadius: CGFloat

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(.ultraThinMaterial)
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(theme.color(.chrome).opacity(chromeOpacity))
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color.black.opacity(theme.isUserBackgroundEnabled && theme.hasUserBackground ? 0.34 : 0))
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                theme.color(.accent).opacity(0.08),
                                Color.white.opacity(0.03),
                                Color.clear
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
    }

    private var chromeOpacity: Double {
        theme.isUserBackgroundEnabled && theme.hasUserBackground
            ? max(theme.tabBarOpacity, 0.62)
            : theme.tabBarOpacity
    }
}

private struct FloatingChromeBackground: View {
    @EnvironmentObject private var theme: BrowserTheme

    var body: some View {
        Capsule()
            .fill(.ultraThinMaterial)
            .overlay {
                Capsule()
                    .fill(theme.color(.chrome).opacity(chromeOpacity))
            }
            .overlay {
                Capsule()
                    .fill(Color.black.opacity(theme.isUserBackgroundEnabled && theme.hasUserBackground ? 0.34 : 0))
            }
            .overlay {
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                theme.color(.accent).opacity(0.10),
                                Color.white.opacity(0.04),
                                Color.clear
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
    }

    private var chromeOpacity: Double {
        theme.isUserBackgroundEnabled && theme.hasUserBackground
            ? max(theme.tabBarOpacity, 0.68)
            : theme.tabBarOpacity
    }
}

private struct ControlGlassBackground: View {
    @EnvironmentObject private var theme: BrowserTheme
    let cornerRadius: CGFloat

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(.ultraThinMaterial)
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(theme.color(.field).opacity(controlOpacity))
            }
    }

    private var controlOpacity: Double {
        theme.isUserBackgroundEnabled && theme.hasUserBackground
            ? max(theme.controlOpacity, 0.88)
            : theme.controlOpacity
    }
}

private struct BrowserIcon: View {
    @EnvironmentObject private var model: BrowserViewModel
    let slot: BrowserCustomIconSlot?
    let systemName: String
    let size: CGFloat
    let weight: Font.Weight

    var body: some View {
        Group {
            if let image = model.customIconImage(for: slot) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                Image(systemName: model.customIconName(for: slot, fallback: systemName))
                    .font(.system(size: size, weight: weight))
            }
        }
    }
}

private struct PlacementMenu: View {
    @EnvironmentObject private var model: BrowserViewModel
    @EnvironmentObject private var theme: BrowserTheme

    var body: some View {
        Menu {
            ForEach(BrowserChromePlacement.allCases) { placement in
                Button {
                    model.chromePlacement = placement
                } label: {
                    Label(placement.title, systemImage: placement.symbolName)
                }
            }
        } label: {
            BrowserIcon(slot: .placement, systemName: model.chromePlacement.symbolName, size: 15, weight: .semibold)
                .frame(width: 36, height: 36)
                .foregroundStyle(theme.chromeForegroundColor)
                .background(ControlGlassBackground(cornerRadius: 8))
        }
        .accessibilityLabel("Change chrome placement")
    }
}

private struct TabBarStyleControl: View {
    @EnvironmentObject private var theme: BrowserTheme
    @State private var isPresented = false
    @State private var isBackgroundImporterPresented = false
    let compact: Bool

    var body: some View {
        Button {
            isPresented = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 15, weight: .semibold))
                if compact == false {
                    Text("Tab Bar")
                        .font(.system(size: 13, weight: .bold))
                        .lineLimit(1)
                }
            }
            .frame(height: 36)
            .frame(maxWidth: compact ? nil : .infinity)
            .padding(.horizontal, compact ? 0 : 12)
            .frame(width: compact ? 36 : nil)
            .foregroundStyle(theme.chromeForegroundColor)
            .background(ControlGlassBackground(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(theme.color(.border).opacity(0.45), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Configure tab bar")
        .popover(isPresented: $isPresented) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("Tab Bar")
                        .font(.headline.weight(.semibold))
                    Spacer()
                    Text("\(Int(theme.tabBarTransparency * 100))%")
                    .font(.caption.weight(.bold))
                        .foregroundStyle(theme.chromeSecondaryForegroundColor)
                }

                Toggle("Transparent", isOn: $theme.isTabBarTransparencyEnabled)

                Slider(value: $theme.tabBarTransparency, in: 0...0.85)
                    .disabled(theme.isTabBarTransparencyEnabled == false)

                HStack(spacing: 8) {
                    Button("Solid") {
                        theme.isTabBarTransparencyEnabled = false
                    }
                    .buttonStyle(.bordered)

                    Button("Clear") {
                        theme.isTabBarTransparencyEnabled = true
                        theme.tabBarTransparency = 0.85
                    }
                    .buttonStyle(.borderedProminent)
                }

                Divider()

                Toggle("Background", isOn: $theme.isUserBackgroundEnabled)
                    .disabled(theme.hasUserBackground == false)

                if theme.isUserBackgroundEnabled,
                   let image = theme.userBackgroundImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 74)
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }

                HStack(spacing: 8) {
                    Button("Files") {
                        isBackgroundImporterPresented = true
                    }
                    .buttonStyle(.borderedProminent)

                    BackgroundPhotoPickerButton(title: "Photos")
                        .buttonStyle(.bordered)

                    Button("Remove") {
                        theme.clearUserBackground()
                    }
                    .buttonStyle(.bordered)
                    .disabled(theme.hasUserBackground == false)
                }
            }
            .padding(16)
            .frame(width: 300)
            .background(theme.color(.surface))
            .foregroundStyle(theme.chromeForegroundColor)
        }
        .fileImporter(
            isPresented: $isBackgroundImporterPresented,
            allowedContentTypes: [.image],
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result,
               let url = urls.first {
                theme.setUserBackground(from: url)
            }
        }
    }
}

private struct BackgroundPhotoPickerButton: View {
    @EnvironmentObject private var theme: BrowserTheme
    @State private var selectedPhoto: PhotosPickerItem?
    let title: String

    var body: some View {
        PhotosPicker(selection: $selectedPhoto, matching: .images, photoLibrary: .shared()) {
            Label(title, systemImage: "photo.on.rectangle")
        }
        .onChange(of: selectedPhoto) { _, newPhoto in
            importPhoto(newPhoto)
        }
    }

    private func importPhoto(_ item: PhotosPickerItem?) {
        guard let item = item else { return }

        Task {
            guard let data = try? await item.loadTransferable(type: Data.self) else { return }
            await MainActor.run {
                theme.setUserBackground(fromImageData: data)
                selectedPhoto = nil
            }
        }
    }
}

private enum SearchTriggerStyle {
    case sidebar
    case bar
}

private struct SearchTrigger: View {
    @EnvironmentObject private var model: BrowserViewModel
    @EnvironmentObject private var theme: BrowserTheme
    let style: SearchTriggerStyle

    var body: some View {
        Button {
            model.openFloatingSearch()
        } label: {
            HStack(spacing: 8) {
                BrowserIcon(
                    slot: model.selectedTab?.isPrivate == true ? .privateTab : .search,
                    systemName: model.selectedTab?.isPrivate == true ? "lock.shield" : "magnifyingglass",
                    size: 15,
                    weight: .semibold
                )
                    .frame(width: 20, height: 20)
                    .foregroundStyle(model.selectedTab?.isPrivate == true ? theme.color(.privateAccent) : theme.color(.accent))

                VStack(alignment: .leading, spacing: 2) {
                    Text(displayTitle)
                        .font(.system(size: style == .sidebar ? 13 : 15, weight: .semibold))
                        .foregroundStyle(theme.chromeForegroundColor)
                        .lineLimit(1)

                    if style == .sidebar {
                        Text("Search or enter address")
                            .font(.caption2)
                            .foregroundStyle(theme.chromeSecondaryForegroundColor)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .frame(height: style == .sidebar ? 46 : 48)
            .background(ControlGlassBackground(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(theme.color(.border).opacity(0.65), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }

    private var displayTitle: String {
        if BrowserTab.isStartPageURL(model.selectedTab?.url) {
            return "Search \(model.searchEngine.title)"
        }

        return model.selectedTab?.url?.host ?? "Search \(model.searchEngine.title)"
    }
}

private enum AddressFieldStyle {
    case floating
}

private struct AddressField: View {
    @EnvironmentObject private var model: BrowserViewModel
    @EnvironmentObject private var theme: BrowserTheme
    let style: AddressFieldStyle
    let focusOnAppear: Bool

    var body: some View {
        HStack(spacing: 10) {
            BrowserIcon(
                slot: model.selectedTab?.isPrivate == true ? .privateTab : .search,
                systemName: model.selectedTab?.isPrivate == true ? "lock.shield" : "magnifyingglass",
                size: 17,
                weight: .semibold
            )
                .frame(width: 24, height: 24)
                .foregroundStyle(model.selectedTab?.isPrivate == true ? theme.color(.privateAccent) : theme.color(.accent))

            SelectableAddressTextField(
                text: addressBinding,
                placeholder: "Search \(model.searchEngine.title) or enter address",
                textColor: UIColor(theme.color(.text)),
                placeholderColor: UIColor(theme.color(.mutedText)),
                tintColor: UIColor(theme.color(.createTab)),
                shouldFocus: focusOnAppear,
                shouldSelectText: selectTextBinding
            ) {
                model.submitAddress()
            }
            .frame(height: 34)

            Button {
                model.submitAddress()
            } label: {
                BrowserIcon(slot: .go, systemName: "arrow.up.circle.fill", size: 25, weight: .semibold)
                    .frame(width: 30, height: 30)
                    .foregroundStyle(theme.color(.createTab))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Go")

            if model.selectedTab?.isPrivate == true {
                Text("Private")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(theme.color(.text))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background(theme.color(.privateAccent).opacity(0.72), in: Capsule())
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 54)
        .frame(maxWidth: 680)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(theme.color(.border).opacity(0.9), lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.38), radius: 22, y: 12)
    }

    private var addressBinding: Binding<String> {
        Binding(
            get: { model.floatingSearchText },
            set: { model.floatingSearchText = $0 }
        )
    }

    private var selectTextBinding: Binding<Bool> {
        Binding(
            get: { model.shouldSelectFloatingSearchText },
            set: { model.shouldSelectFloatingSearchText = $0 }
        )
    }
}

private struct SelectableAddressTextField: UIViewRepresentable {
    @Binding var text: String
    let placeholder: String
    let textColor: UIColor
    let placeholderColor: UIColor
    let tintColor: UIColor
    let shouldFocus: Bool
    @Binding var shouldSelectText: Bool
    let onSubmit: () -> Void

    func makeUIView(context: Context) -> UITextField {
        let textField = UITextField(frame: .zero)
        textField.delegate = context.coordinator
        textField.keyboardType = .URL
        textField.returnKeyType = .go
        textField.autocorrectionType = .no
        textField.autocapitalizationType = .none
        textField.clearButtonMode = .whileEditing
        textField.font = .systemFont(ofSize: 18, weight: .medium)
        textField.backgroundColor = .clear
        textField.borderStyle = .none
        return textField
    }

    func updateUIView(_ textField: UITextField, context: Context) {
        context.coordinator.parent = self
        if textField.text != text {
            textField.text = text
        }
        textField.textColor = textColor
        textField.tintColor = tintColor
        textField.attributedPlaceholder = NSAttributedString(
            string: placeholder,
            attributes: [
                .foregroundColor: placeholderColor,
                .font: UIFont.systemFont(ofSize: 18, weight: .medium)
            ]
        )

        guard shouldFocus else { return }

        let shouldSelectCurrentText = shouldSelectText
        let selectTextBinding = $shouldSelectText

        DispatchQueue.main.async {
            if textField.isFirstResponder == false {
                textField.becomeFirstResponder()
            }
            if shouldSelectCurrentText {
                textField.selectAll(nil)
                selectTextBinding.wrappedValue = false
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    final class Coordinator: NSObject, UITextFieldDelegate {
        var parent: SelectableAddressTextField

        init(parent: SelectableAddressTextField) {
            self.parent = parent
        }

        func textFieldDidChangeSelection(_ textField: UITextField) {
            parent.text = textField.text ?? ""
        }

        func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            parent.onSubmit()
            return true
        }
    }
}

private struct FloatingSearchOverlay: View {
    @EnvironmentObject private var model: BrowserViewModel
    @EnvironmentObject private var theme: BrowserTheme

    var body: some View {
        ZStack(alignment: .top) {
            Color.black.opacity(0.32)
                .ignoresSafeArea()
                .onTapGesture {
                    model.isFloatingSearchPresented = false
                }

            VStack(spacing: 12) {
                AddressField(style: .floating, focusOnAppear: true)
                SearchResultsList(query: model.floatingSearchText)

                if let tab = model.selectedTab {
                    HStack(spacing: 8) {
                        Image(systemName: tab.isPrivate ? "theatermasks" : "globe")
                        Text(tab.title)
                            .lineLimit(1)
                        Spacer()
                        Text(BrowserTab.isStartPageURL(tab.url) ? "Start Page" : (tab.url?.host ?? model.searchEngine.title))
                            .lineLimit(1)
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(theme.color(.mutedText))
                    .padding(.horizontal, 14)
                    .frame(maxWidth: 680)
                }
            }
            .padding(.top, 18)
            .padding(.horizontal, 16)
        }
    }
}

private struct SearchResultsList: View {
    @EnvironmentObject private var model: BrowserViewModel
    @EnvironmentObject private var theme: BrowserTheme
    let query: String

    var body: some View {
        let results = model.searchResults(for: query)

        if results.isEmpty == false {
            VStack(spacing: 0) {
                ForEach(Array(results.enumerated()), id: \.element.id) { index, result in
                    SearchResultRow(result: result)

                    if index < results.count - 1 {
                        Rectangle()
                            .fill(theme.color(.border).opacity(0.35))
                            .frame(height: 1)
                            .padding(.leading, 52)
                    }
                }
            }
            .frame(maxWidth: 680)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(theme.color(.border).opacity(0.8), lineWidth: 1)
            }
            .shadow(color: Color.black.opacity(0.28), radius: 18, y: 10)
        }
    }
}

private struct BrowserTopSearchBar: View {
    @EnvironmentObject private var model: BrowserViewModel
    @EnvironmentObject private var theme: BrowserTheme
    @State private var shouldSelectText = false

    var body: some View {
        HStack(spacing: 10) {
            BrowserIcon(
                slot: model.selectedTab?.isPrivate == true ? .privateTab : .search,
                systemName: model.selectedTab?.isPrivate == true ? "lock.shield" : "magnifyingglass",
                size: 16,
                weight: .semibold
            )
            .frame(width: 22, height: 22)
            .foregroundStyle(model.selectedTab?.isPrivate == true ? theme.color(.privateAccent) : theme.color(.accent))

            SelectableAddressTextField(
                text: addressBinding,
                placeholder: "Search \(model.searchEngine.title) or enter address",
                textColor: UIColor(theme.color(.text)),
                placeholderColor: UIColor(theme.color(.mutedText)),
                tintColor: UIColor(theme.color(.createTab)),
                shouldFocus: false,
                shouldSelectText: $shouldSelectText
            ) {
                model.submitAddress()
            }
            .frame(height: 32)

            Button {
                model.submitAddress()
            } label: {
                BrowserIcon(slot: .go, systemName: "arrow.up.circle.fill", size: 24, weight: .semibold)
                    .frame(width: 28, height: 28)
                    .foregroundStyle(theme.color(.createTab))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Go")
        }
        .padding(.horizontal, 14)
        .frame(height: 50)
        .frame(maxWidth: 760)
        .background {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(theme.color(.field).opacity(theme.isUserBackgroundEnabled && theme.hasUserBackground ? max(theme.controlOpacity, 0.88) : theme.controlOpacity))
                }
        }
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(theme.color(.border).opacity(0.82), lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.28), radius: 18, y: 10)
    }

    private var addressBinding: Binding<String> {
        Binding(
            get: { model.selectedTab?.addressText ?? "" },
            set: { model.selectedTab?.addressText = $0 }
        )
    }
}

private struct SearchResultRow: View {
    @EnvironmentObject private var model: BrowserViewModel
    @EnvironmentObject private var theme: BrowserTheme
    let result: BrowserSearchResult

    var body: some View {
        Button {
            model.openSearchResult(result)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: result.symbolName)
                    .font(.system(size: 15, weight: .semibold))
                    .frame(width: 28, height: 28)
                    .foregroundStyle(theme.color(.accent))
                    .background(theme.color(.field), in: RoundedRectangle(cornerRadius: 7, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text(result.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(theme.color(.text))
                        .lineLimit(1)

                    Text(result.subtitle)
                        .font(.caption)
                        .foregroundStyle(theme.color(.mutedText))
                        .lineLimit(1)
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .frame(height: 52)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct BrowserPageControls: View {
    @EnvironmentObject private var theme: BrowserTheme

    var body: some View {
        HStack(spacing: 8) {
            AITabButton()
            MoreTabButton()
        }
        .padding(6)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(theme.color(.border).opacity(0.42), lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.24), radius: 14, y: 7)
    }
}

private struct MoreTabButton: View {
    @EnvironmentObject private var model: BrowserViewModel
    @EnvironmentObject private var theme: BrowserTheme

    var body: some View {
        Menu {
            let actions = movedActions
            if actions.isEmpty {
                Button {} label: {
                    Label("Move actions here in Settings", systemImage: "slider.horizontal.3")
                }
                .disabled(true)
            } else {
                ForEach(actions) { action in
                    menuContent(for: action)
                }

                Divider()
            }

            Button {
                model.isAddOnsPresented = true
            } label: {
                Label("Add-ons Library", systemImage: "puzzlepiece")
            }

            Button {
                model.isSettingsPresented = true
            } label: {
                Label("Customize More Menu", systemImage: "slider.horizontal.3")
            }
        } label: {
            BrowserIcon(slot: .more, systemName: "ellipsis", size: 18, weight: .black)
                .frame(width: 38, height: 38)
                .foregroundStyle(theme.color(.text))
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(theme.color(.border).opacity(0.62), lineWidth: 1)
                }
        }
        .accessibilityLabel("More actions")
    }

    private var movedActions: [BrowserToolbarAction] {
        BrowserToolbarAction.allCases.filter { model.isInMoreMenu($0) }
    }

    @ViewBuilder
    private func menuContent(for action: BrowserToolbarAction) -> some View {
        if action == .placement {
            Menu {
                PlacementMenuContent()
            } label: {
                Label(action.menuTitle, systemImage: model.chromePlacement.symbolName)
            }
        } else {
            Button {
                model.performToolbarAction(action)
            } label: {
                Label(menuTitle(for: action), systemImage: menuSymbol(for: action))
            }
            .disabled(action == .forward && model.selectedTab?.canGoForward != true)
        }
    }

    private func menuTitle(for action: BrowserToolbarAction) -> String {
        if action == .reload {
            return model.selectedTab?.isLoading == true ? "Stop Loading" : "Reload"
        }
        return action.menuTitle
    }

    private func menuSymbol(for action: BrowserToolbarAction) -> String {
        if action == .reload {
            return model.selectedTab?.isLoading == true ? "xmark" : "arrow.clockwise"
        }
        return model.customIconName(for: action.customIconSlot, fallback: action.symbolName)
    }
}

private struct AITabButton: View {
    @EnvironmentObject private var model: BrowserViewModel
    @EnvironmentObject private var theme: BrowserTheme

    var body: some View {
        Menu {
            ForEach(AIAssistant.allCases) { assistant in
                Button {
                    model.openAIShortcut(assistant)
                } label: {
                    Label(assistant.menuTitle, systemImage: assistant.symbolName)
                }
            }

            Divider()

            if model.localAIURLText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
                Button {
                    model.openLocalAI()
                } label: {
                    Label(model.localAIName, systemImage: "desktopcomputer")
                }
            }

            Button {
                model.isLocalAIImporterPresented = true
            } label: {
                Label("Import Local AI", systemImage: "square.and.arrow.down")
            }
        } label: {
            BrowserIcon(slot: .ai, systemName: "sparkles", size: 15, weight: .bold)
                .frame(width: 38, height: 38)
                .foregroundStyle(theme.color(.text))
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(theme.color(.accent).opacity(0.65), lineWidth: 1)
                }
                .shadow(color: Color.black.opacity(0.25), radius: 10, y: 5)
        }
        .accessibilityLabel("AI shortcuts")
    }
}

private struct ContainedBrowserOverlay: View {
    @EnvironmentObject private var model: BrowserViewModel
    @EnvironmentObject private var theme: BrowserTheme

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color.black.opacity(0.42)
                    .ignoresSafeArea()

                VStack(spacing: 10) {
                    ContainedBrowserHeader()

                    if let tab = model.selectedContainedTab {
                        ContainedAddressBar(tab: tab)
                        ContainedTabStrip()

                        BrowserWebView(tab: tab)
                            .id(tab.id)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            .overlay(alignment: .top) {
                                LoadingProgress(tab: tab)
                            }
                            .overlay {
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .stroke(theme.color(.border).opacity(0.8), lineWidth: 1)
                            }
                    } else {
                        VStack(spacing: 12) {
                            Image(systemName: "rectangle.on.rectangle")
                                .font(.system(size: 30, weight: .semibold))
                                .foregroundStyle(theme.color(.accent))
                            Text("No contained tabs")
                                .font(.headline.weight(.semibold))
                                .foregroundStyle(theme.color(.text))
                            Button("Create Contained Tab") {
                                model.openContainedTab()
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                .padding(12)
                .frame(
                    maxWidth: min(proxy.size.width - 24, 980),
                    maxHeight: min(proxy.size.height - 36, 760)
                )
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(theme.color(.accent).opacity(0.46), lineWidth: 1)
                }
                .shadow(color: Color.black.opacity(0.48), radius: 32, y: 18)
                .padding(.horizontal, 12)
                .padding(.vertical, 18)
            }
            .onAppear {
                if model.containedTabs.isEmpty {
                    model.openContainedTab()
                }
            }
        }
    }
}

private struct ContainedBrowserHeader: View {
    @EnvironmentObject private var model: BrowserViewModel
    @EnvironmentObject private var theme: BrowserTheme

    var body: some View {
        HStack(spacing: 10) {
            BrowserIcon(slot: .containedTabs, systemName: "rectangle.on.rectangle", size: 15, weight: .bold)
                .frame(width: 34, height: 34)
                .foregroundStyle(theme.color(.createTab))
                .background(theme.color(.field).opacity(theme.controlOpacity), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text("Contained Tabs")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(theme.color(.text))
                Text("Browser inside the browser")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(theme.color(.mutedText))
            }

            Spacer(minLength: 0)

            Button {
                model.openContainedTab()
            } label: {
                BrowserIcon(slot: .newTab, systemName: "plus", size: 15, weight: .bold)
                    .frame(width: 34, height: 34)
                    .foregroundStyle(theme.color(.canvas))
                    .background(theme.color(.createTab), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("New Contained Tab")

            Button {
                model.closeContainedBrowser()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .black))
                    .frame(width: 34, height: 34)
                    .foregroundStyle(theme.color(.text))
                    .background(theme.color(.field).opacity(theme.controlOpacity), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close Contained Tabs")
        }
    }
}

private struct ContainedAddressBar: View {
    @EnvironmentObject private var model: BrowserViewModel
    @EnvironmentObject private var theme: BrowserTheme
    @ObservedObject var tab: BrowserTab
    @State private var shouldSelectText = true

    var body: some View {
        HStack(spacing: 8) {
            ContainedControlButton(
                symbol: "chevron.left",
                label: "Contained Back",
                isDisabled: tab.canGoBack == false
            ) {
                tab.goBack()
            }

            ContainedControlButton(
                symbol: "chevron.right",
                label: "Contained Forward",
                isDisabled: tab.canGoForward == false
            ) {
                tab.goForward()
            }

            HStack(spacing: 8) {
                BrowserIcon(slot: .search, systemName: "magnifyingglass", size: 14, weight: .semibold)
                    .frame(width: 20, height: 20)
                    .foregroundStyle(theme.color(.accent))

                SelectableAddressTextField(
                    text: Binding(
                        get: { tab.addressText },
                        set: { tab.addressText = $0 }
                    ),
                    placeholder: "Search \(model.searchEngine.title) or enter address",
                    textColor: UIColor(theme.color(.text)),
                    placeholderColor: UIColor(theme.color(.mutedText)),
                    tintColor: UIColor(theme.color(.createTab)),
                    shouldFocus: true,
                    shouldSelectText: $shouldSelectText
                ) {
                    model.submitContainedAddress()
                }
                .frame(height: 32)

                Button {
                    model.submitContainedAddress()
                } label: {
                    BrowserIcon(slot: .go, systemName: "arrow.up.circle.fill", size: 23, weight: .semibold)
                        .frame(width: 28, height: 28)
                        .foregroundStyle(theme.color(.createTab))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Open Contained Address")
            }
            .padding(.horizontal, 12)
            .frame(height: 42)
            .background(theme.color(.field).opacity(theme.controlOpacity), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(theme.color(.border).opacity(0.55), lineWidth: 1)
            }

            ContainedControlButton(
                symbol: tab.isLoading ? "xmark" : "arrow.clockwise",
                label: "Reload Contained Tab"
            ) {
                tab.reloadOrStop()
            }
        }
    }
}

private struct ContainedControlButton: View {
    @EnvironmentObject private var theme: BrowserTheme
    let symbol: String
    let label: String
    var isDisabled = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            BrowserIcon(slot: symbol == "arrow.clockwise" ? .reload : nil, systemName: symbol, size: 14, weight: .bold)
                .frame(width: 38, height: 42)
                .foregroundStyle(theme.color(.text))
                .background(theme.color(.field).opacity(theme.controlOpacity), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(theme.color(.border).opacity(0.45), lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.38 : 1)
        .accessibilityLabel(label)
    }
}

private struct ContainedTabStrip: View {
    @EnvironmentObject private var model: BrowserViewModel
    @EnvironmentObject private var theme: BrowserTheme

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Button {
                    model.openContainedTab()
                } label: {
                    BrowserIcon(slot: .newTab, systemName: "plus.circle.fill", size: 20, weight: .bold)
                        .frame(width: 42, height: 38)
                        .foregroundStyle(theme.color(.createTab))
                        .background(theme.color(.field).opacity(theme.controlOpacity), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("New Contained Tab")

                ForEach(model.containedTabs) { tab in
                    ContainedTabPill(tab: tab)
                }
            }
            .padding(.horizontal, 2)
        }
    }
}

private struct ContainedTabPill: View {
    @EnvironmentObject private var model: BrowserViewModel
    @EnvironmentObject private var theme: BrowserTheme
    @ObservedObject var tab: BrowserTab

    private var isSelected: Bool {
        model.selectedContainedTabID.map { $0 == tab.id } ?? false
    }

    var body: some View {
        HStack(spacing: 6) {
            Button {
                model.selectContained(tab)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "rectangle.on.rectangle")
                        .font(.system(size: 12, weight: .bold))
                        .frame(width: 26, height: 26)
                        .foregroundStyle(theme.color(.text))
                        .background(theme.color(.accent).opacity(0.22), in: RoundedRectangle(cornerRadius: 7, style: .continuous))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(tab.title)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(theme.color(.text))
                            .lineLimit(1)
                        Text(tab.url?.host ?? model.searchEngine.title)
                            .font(.caption2)
                            .foregroundStyle(theme.color(.mutedText))
                            .lineLimit(1)
                    }

                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity)

            Button {
                model.closeContained(tab)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
            .foregroundStyle(theme.color(.mutedText))
            .accessibilityLabel("Close Contained Tab")
        }
        .padding(.leading, 8)
        .padding(.trailing, 5)
        .frame(width: 210, height: 42)
        .background(isSelected ? theme.color(.surface).opacity(theme.controlOpacity) : theme.color(.field).opacity(theme.controlOpacity * 0.66), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(isSelected ? theme.color(.accent).opacity(0.72) : theme.color(.border).opacity(0.35), lineWidth: 1)
        }
    }
}

private struct FirstRunTutorialView: View {
    @EnvironmentObject private var model: BrowserViewModel
    @EnvironmentObject private var theme: BrowserTheme
    @State private var step = 0

    var body: some View {
        ZStack {
            BrowserBackground()

            VStack(spacing: 18) {
                Spacer(minLength: 10)

                VStack(spacing: 22) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(.ultraThinMaterial)
                            .overlay {
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .fill(theme.color(.surface).opacity(0.62))
                            }
                            .overlay {
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .stroke(theme.color(.accent).opacity(0.55), lineWidth: 1)
                            }
                        Image(systemName: "globe")
                            .font(.system(size: 28, weight: .black))
                            .foregroundStyle(theme.color(.createTab))
                    }
                    .frame(width: 72, height: 72)
                    .shadow(color: theme.color(.accent).opacity(0.22), radius: 26, y: 14)

                    Group {
                        if step == 0 {
                            VStack(spacing: 10) {
                                Text("Welcome to Glide")
                                    .font(.system(size: 38, weight: .black))
                                    .foregroundStyle(theme.color(.text))
                                    .multilineTextAlignment(.center)

                                Text("A lighter, glassy browser built around fast search and side tabs.")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(theme.color(.mutedText))
                                    .multilineTextAlignment(.center)
                            }
                            .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .move(edge: .leading).combined(with: .opacity)))
                        } else {
                            VStack(spacing: 12) {
                                Text("Ready to glide the web")
                                    .font(.system(size: 36, weight: .black))
                                    .foregroundStyle(theme.color(.text))
                                    .multilineTextAlignment(.center)

                                VStack(spacing: 0) {
                                    TutorialFeatureRow(
                                        symbol: "arrow.left.and.right",
                                        title: "Gestures",
                                        detail: "Two fingers left hides the tab bar, two fingers right reveals it. Three fingers moves back or forward.",
                                        tint: .accent
                                    )

                                    TutorialDivider()

                                    TutorialFeatureRow(
                                        symbol: "sparkle",
                                        title: "Essentials",
                                        detail: "Hold a tab and add it to Essentials for a saved launcher.",
                                        tint: .createTab
                                    )
                                }
                                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .stroke(theme.color(.border).opacity(0.72), lineWidth: 1)
                                }
                            }
                            .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .move(edge: .leading).combined(with: .opacity)))
                        }
                    }
                    .id(step)
                    .animation(.spring(response: 0.42, dampingFraction: 0.86), value: step)
                }
                .frame(maxWidth: 560)
                .padding(.horizontal, 22)

                Spacer(minLength: 6)

                TutorialQuickCustomization()
                    .frame(maxWidth: 560)
                    .padding(.horizontal, 22)

                Button {
                    if step == 0 {
                        withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) {
                            step = 1
                        }
                    } else {
                        model.completeTutorial()
                        model.openFloatingSearch()
                    }
                } label: {
                    HStack(spacing: 10) {
                        Text(step == 0 ? "Next" : "Start browsing")
                            .font(.system(size: 16, weight: .bold))
                        Image(systemName: "arrow.right")
                            .font(.system(size: 14, weight: .black))
                    }
                    .frame(maxWidth: 560)
                    .frame(height: 54)
                    .foregroundStyle(theme.color(.canvas))
                    .background(theme.color(.createTab), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(step == 0 ? "Next" : "Start browsing")
                .padding(.horizontal, 22)
                .padding(.bottom, 24)
            }
        }
    }
}

private struct TutorialQuickCustomization: View {
    @EnvironmentObject private var model: BrowserViewModel
    @EnvironmentObject private var theme: BrowserTheme

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick customization")
                .font(.caption.weight(.bold))
                .foregroundStyle(theme.color(.mutedText))

            HStack(spacing: 8) {
                Button {
                    model.setTabBarCollapsed(!model.areSideTabsCollapsed)
                } label: {
                    Label(model.areSideTabsCollapsed ? "Reveal" : "Hide", systemImage: model.areSideTabsCollapsed ? "sidebar.left" : "sidebar.leading")
                }

                Button {
                    theme.isTabBarTransparencyEnabled = true
                    theme.tabBarTransparency = 0.58
                } label: {
                    Label("Glass", systemImage: "square.stack.3d.up")
                }

                Button {
                    theme.isTabBarTransparencyEnabled = true
                    theme.tabBarTransparency = 0.85
                } label: {
                    Label("Liquid", systemImage: "drop")
                }
            }
            .font(.system(size: 13, weight: .bold))
            .buttonStyle(.bordered)
        }
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(theme.color(.border).opacity(0.65), lineWidth: 1)
        }
    }
}

private struct TutorialFeatureRow: View {
    @EnvironmentObject private var theme: BrowserTheme
    let symbol: String
    let title: String
    let detail: String
    let tint: BrowserThemeToken

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .bold))
                .frame(width: 34, height: 34)
                .foregroundStyle(theme.color(tint))
                .background(theme.color(.field).opacity(theme.controlOpacity), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(theme.color(.text))
                    .lineLimit(2)

                Text(detail)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(theme.color(.mutedText))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
    }
}

private struct TutorialDivider: View {
    @EnvironmentObject private var theme: BrowserTheme

    var body: some View {
        Rectangle()
            .fill(theme.color(.border).opacity(0.32))
            .frame(height: 1)
            .padding(.leading, 60)
    }
}

private struct BrowserTabFinderView: View {
    @EnvironmentObject private var model: BrowserViewModel
    @EnvironmentObject private var theme: BrowserTheme
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    var body: some View {
        NavigationStack {
            Group {
                if visibleTabCount == 0 {
                    VStack(spacing: 12) {
                        Image(systemName: "square.grid.2x2")
                            .font(.system(size: 34, weight: .semibold))
                        Text(query.isEmpty ? "No tabs open" : "No matching tabs")
                            .font(.headline)
                    }
                    .foregroundStyle(theme.color(.mutedText))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(theme.color(.canvas))
                } else {
                    List {
                        tabSection("Normal", tabs: filtered(model.normalTabs), isContained: false)
                        tabSection("Private", tabs: filtered(model.privateTabs), isContained: false)
                        tabSection("Contained", tabs: filtered(model.containedTabs), isContained: true)
                    }
                    .scrollContentBackground(.hidden)
                    .background(theme.color(.canvas))
                }
            }
            .navigationTitle("Tab Finder")
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Find tabs")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        model.openNewTabAndSearch()
                        dismiss()
                    } label: {
                        Label("New Tab", systemImage: "plus")
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func tabSection(_ title: String, tabs: [BrowserTab], isContained: Bool) -> some View {
        if tabs.isEmpty == false {
            Section("\(title) (\(tabs.count))") {
                ForEach(tabs) { tab in
                    TabFinderRow(tab: tab, isContained: isContained) {
                        model.selectFromFinder(tab)
                    } closeAction: {
                        model.closeFromFinder(tab)
                    }
                    .listRowBackground(theme.color(.surface))
                    .contextMenu {
                        if isContained == false && tab.isPrivate == false {
                            Button {
                                model.addEssential(from: tab)
                            } label: {
                                Label("Add to Essentials", systemImage: "sparkle")
                            }
                        }

                        Button(role: .destructive) {
                            model.closeFromFinder(tab)
                        } label: {
                            Label("Close Tab", systemImage: "xmark")
                        }
                    }
                }
            }
        }
    }

    private var visibleTabCount: Int {
        filtered(model.normalTabs).count + filtered(model.privateTabs).count + filtered(model.containedTabs).count
    }

    private func filtered(_ tabs: [BrowserTab]) -> [BrowserTab] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard trimmedQuery.isEmpty == false else { return tabs }

        return tabs.filter { tab in
            tab.title.lowercased().contains(trimmedQuery) ||
            (tab.url?.absoluteString.lowercased().contains(trimmedQuery) ?? false)
        }
    }
}

private struct TabFinderRow: View {
    @EnvironmentObject private var model: BrowserViewModel
    @EnvironmentObject private var theme: BrowserTheme
    @ObservedObject var tab: BrowserTab
    let isContained: Bool
    let selectAction: () -> Void
    let closeAction: () -> Void

    private var isSelected: Bool {
        if isContained {
            return model.selectedContainedTabID == tab.id
        }
        return model.selectedTabID == tab.id
    }

    var body: some View {
        HStack(spacing: 12) {
            Button(action: selectAction) {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(iconFill)
                        Image(systemName: iconName)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(theme.color(.text))
                    }
                    .frame(width: 36, height: 36)

                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Text(tab.title)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(theme.color(.text))
                                .lineLimit(1)

                            if isSelected {
                                Text("ACTIVE")
                                    .font(.system(size: 9, weight: .black))
                                    .foregroundStyle(theme.color(.canvas))
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 3)
                                    .background(theme.color(.createTab), in: RoundedRectangle(cornerRadius: 5, style: .continuous))
                            }
                        }

                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(theme.color(.mutedText))
                            .lineLimit(1)
                    }

                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button(role: .destructive, action: closeAction) {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
                    .frame(width: 30, height: 30)
            }
            .buttonStyle(.plain)
            .foregroundStyle(theme.color(.mutedText))
            .accessibilityLabel("Close \(tab.title)")
        }
        .padding(.vertical, 4)
    }

    private var iconName: String {
        if isContained {
            return "rectangle.on.rectangle"
        }
        return tab.isPrivate ? "theatermasks" : "globe"
    }

    private var iconFill: Color {
        if isContained {
            return theme.color(.accent).opacity(0.28)
        }
        return tab.isPrivate ? theme.color(.privateAccent).opacity(0.82) : theme.color(.accent).opacity(0.24)
    }

    private var subtitle: String {
        if BrowserTab.isStartPageURL(tab.url) {
            return "Start Page"
        }
        return tab.url?.absoluteString ?? "No URL"
    }
}

private struct BrowserDownloadsView: View {
    @EnvironmentObject private var model: BrowserViewModel
    @EnvironmentObject private var theme: BrowserTheme
    @Environment(\.dismiss) private var dismiss
    @State private var pendingExportRequest: DownloadExportRequest?
    @State private var preparedExport: PreparedDownloadExport?
    @State private var preparedExportCleanupURL: URL?
    @State private var exportErrorMessage = ""

    var body: some View {
        NavigationStack {
            Group {
                if model.downloads.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "arrow.down.circle")
                            .font(.system(size: 34, weight: .semibold))
                        Text("No downloads yet")
                            .font(.headline)
                        Button {
                            model.downloadSelectedTab()
                        } label: {
                            Label("Download Current Tab", systemImage: "arrow.down.doc")
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .foregroundStyle(theme.color(.mutedText))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(theme.color(.canvas))
                } else {
                    List {
                        if model.downloadStatusMessage.isEmpty == false || exportErrorMessage.isEmpty == false {
                            Section {
                                if model.downloadStatusMessage.isEmpty == false {
                                    Label(model.downloadStatusMessage, systemImage: "info.circle")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(theme.color(.mutedText))
                                }
                                if exportErrorMessage.isEmpty == false {
                                    Label(exportErrorMessage, systemImage: "exclamationmark.triangle")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.red)
                                }
                            }
                            .listRowBackground(theme.color(.surface))
                        }

                        ForEach(model.downloads) { item in
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(spacing: 8) {
                                    Image(systemName: symbolName(for: item.state))
                                        .foregroundStyle(color(for: item.state))
                                    Text(item.filename)
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundStyle(theme.color(.text))
                                        .lineLimit(1)
                                }

                                Text(item.sourceURLString.isEmpty ? item.localPath : item.sourceURLString)
                                    .font(.caption)
                                    .foregroundStyle(theme.color(.mutedText))
                                    .lineLimit(1)

                                HStack(spacing: 10) {
                                    Text(item.state.title)
                                    if item.isEncrypted {
                                        Label("Encrypted", systemImage: "lock.fill")
                                    }
                                    if let byteCount = item.originalByteCount {
                                        Text(ByteCountFormatter.string(fromByteCount: byteCount, countStyle: .file))
                                    }
                                    Text(item.createdAt, style: .relative)
                                }
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(theme.color(.mutedText))

                                if let error = item.errorMessage, error.isEmpty == false {
                                    Text(error)
                                        .font(.caption2)
                                        .foregroundStyle(.red)
                                        .lineLimit(2)
                                }

                                HStack(spacing: 8) {
                                    if model.canExportDownload(item) {
                                        Button {
                                            requestExport(item, intent: .preview)
                                        } label: {
                                            Label("Open", systemImage: "doc.text.magnifyingglass")
                                        }
                                        .buttonStyle(.bordered)

                                        Button {
                                            requestExport(item, intent: .share)
                                        } label: {
                                            Label("Share", systemImage: "square.and.arrow.up")
                                        }
                                        .buttonStyle(.bordered)
                                    }

                                    if item.sourceURLString.isEmpty == false {
                                        Button {
                                            model.retryDownload(item)
                                        } label: {
                                            Label(item.state == .failed ? "Retry" : "Download Again", systemImage: "arrow.clockwise")
                                        }
                                        .buttonStyle(.bordered)
                                    }

                                    Button(role: .destructive) {
                                        model.deleteDownload(item)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                    .buttonStyle(.bordered)
                                }
                                .font(.caption.weight(.bold))
                            }
                            .padding(.vertical, 4)
                            .listRowBackground(theme.color(.surface))
                        }
                    }
                    .scrollContentBackground(.hidden)
                    .background(theme.color(.canvas))
                }
            }
            .navigationTitle("Downloads")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        model.clearDownloads()
                    } label: {
                        Label("Clear", systemImage: "trash")
                    }
                    .disabled(model.downloads.isEmpty)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        model.downloadSelectedTab()
                    } label: {
                        Label("Download Current Tab", systemImage: "arrow.down.doc")
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .confirmationDialog(
            "Export decrypted file?",
            isPresented: Binding(
                get: { pendingExportRequest != nil },
                set: { isPresented in
                    if isPresented == false {
                        pendingExportRequest = nil
                    }
                }
            ),
            titleVisibility: .visible
        ) {
            if let request = pendingExportRequest {
                Button(request.intent.confirmationTitle) {
                    prepareExport(request)
                }
            }
            Button("Cancel", role: .cancel) {
                pendingExportRequest = nil
            }
        } message: {
            Text("Glide keeps downloads encrypted at rest. Continuing creates a temporary decrypted copy outside the vault so iOS can open or share it.")
        }
        .sheet(item: $preparedExport, onDismiss: cleanupPreparedExport) { export in
            switch export.intent {
            case .preview:
                DownloadPreviewController(url: export.url)
                    .ignoresSafeArea()
            case .share:
                ActivityShareController(activityItems: [export.url])
                    .ignoresSafeArea()
            }
        }
    }

    private func requestExport(_ item: BrowserDownloadItem, intent: DownloadExportIntent) {
        exportErrorMessage = ""
        pendingExportRequest = DownloadExportRequest(item: item, intent: intent)
    }

    private func prepareExport(_ request: DownloadExportRequest) {
        pendingExportRequest = nil

        do {
            let url = try model.prepareDownloadForExport(request.item)
            preparedExportCleanupURL = url
            preparedExport = PreparedDownloadExport(url: url, intent: request.intent)
        } catch {
            exportErrorMessage = error.localizedDescription
        }
    }

    private func cleanupPreparedExport() {
        if let preparedExportCleanupURL {
            model.cleanupPreparedExport(at: preparedExportCleanupURL)
        }
        preparedExportCleanupURL = nil
    }

    private func symbolName(for state: BrowserDownloadState) -> String {
        switch state {
        case .inProgress:
            return "arrow.down"
        case .finished:
            return "checkmark.circle"
        case .failed:
            return "exclamationmark.triangle"
        }
    }

    private func color(for state: BrowserDownloadState) -> Color {
        switch state {
        case .inProgress:
            return theme.color(.accent)
        case .finished:
            return .green
        case .failed:
            return .red
        }
    }
}

private enum DownloadExportIntent {
    case preview
    case share

    var confirmationTitle: String {
        switch self {
        case .preview:
            return "Open Temporary Copy"
        case .share:
            return "Share Temporary Copy"
        }
    }
}

private struct DownloadExportRequest {
    let item: BrowserDownloadItem
    let intent: DownloadExportIntent
}

private struct PreparedDownloadExport: Identifiable {
    let id = UUID()
    let url: URL
    let intent: DownloadExportIntent
}

private struct DownloadPreviewController: UIViewControllerRepresentable {
    let url: URL

    func makeCoordinator() -> Coordinator {
        Coordinator(url: url)
    }

    func makeUIViewController(context: Context) -> QLPreviewController {
        let controller = QLPreviewController()
        controller.dataSource = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: QLPreviewController, context: Context) {}

    final class Coordinator: NSObject, QLPreviewControllerDataSource {
        let url: URL

        init(url: URL) {
            self.url = url
        }

        func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
            1
        }

        func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
            url as NSURL
        }
    }
}

private struct ActivityShareController: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

private struct CustomVPNView: View {
    @EnvironmentObject private var model: BrowserViewModel
    @EnvironmentObject private var theme: BrowserTheme
    @Environment(\.dismiss) private var dismiss
    @State private var profile = CustomVPNProfile.empty

    var body: some View {
        NavigationStack {
            Form {
                Section("Custom VPN") {
                    TextField("Country", text: $profile.countryName)
                    TextField("Server address", text: $profile.serverAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                    TextField("Remote identifier", text: $profile.remoteIdentifier)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    TextField("Username", text: $profile.username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Toggle("Enable profile", isOn: $profile.isEnabled)
                }

                Section("Native iOS") {
                    Button("Save in app") {
                        model.saveVPNProfile(profile)
                    }

                    Button("Install VPN profile") {
                        model.saveVPNProfile(profile)
                        model.installVPNProfile()
                    }
                    .disabled(profile.isConfigured == false)

                    Button("Connect") {
                        model.saveVPNProfile(profile)
                        model.connectVPNProfile()
                    }
                    .disabled(profile.isConfigured == false)

                    Button("Disconnect") {
                        model.disconnectVPNProfile()
                    }
                }

                Section("Status") {
                    Text(model.vpnStatusMessage)
                    Text("Native Personal VPN requires a real VPN server and the Personal VPN entitlement when this IPA is signed.")
                        .font(.caption)
                        .foregroundStyle(theme.color(.mutedText))
                }
            }
            .scrollContentBackground(.hidden)
            .background(theme.color(.canvas))
            .foregroundStyle(theme.color(.text))
            .navigationTitle("Custom VPN")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        model.saveVPNProfile(profile)
                        dismiss()
                    }
                }
            }
            .onAppear {
                profile = model.vpnProfile
            }
        }
    }
}

private struct BrowserHistoryView: View {
    @EnvironmentObject private var model: BrowserViewModel
    @EnvironmentObject private var theme: BrowserTheme
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if model.history.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 34, weight: .semibold))
                        Text("No history yet")
                            .font(.headline)
                    }
                    .foregroundStyle(theme.color(.mutedText))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(theme.color(.canvas))
                } else {
                    List {
                        ForEach(model.history) { item in
                            Button {
                                model.openHistoryItem(item)
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(item.title)
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundStyle(theme.color(.text))
                                        .lineLimit(1)

                                    Text(item.urlString)
                                        .font(.caption)
                                        .foregroundStyle(theme.color(.mutedText))
                                        .lineLimit(1)

                                    Text(item.visitedAt, style: .relative)
                                        .font(.caption2)
                                        .foregroundStyle(theme.color(.mutedText))
                                }
                                .padding(.vertical, 4)
                            }
                        }
                        .listRowBackground(theme.color(.surface))
                    }
                    .scrollContentBackground(.hidden)
                    .background(theme.color(.canvas))
                }
            }
            .navigationTitle("History")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Clear") {
                        model.clearHistory()
                    }
                    .disabled(model.history.isEmpty)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

private struct CrashLogsView: View {
    @EnvironmentObject private var security: AppSecurityModel
    @EnvironmentObject private var theme: BrowserTheme
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if security.crashLogs.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "waveform.path.ecg.rectangle")
                            .font(.system(size: 34, weight: .semibold))
                        Text("No crash logs")
                            .font(.headline)
                    }
                    .foregroundStyle(theme.color(.mutedText))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(theme.color(.canvas))
                } else {
                    List {
                        Section {
                            Text("Crash logs are local diagnostics. Glide stores the time, app version, and crash state only, not page contents or URLs.")
                                .font(.caption)
                                .foregroundStyle(theme.color(.mutedText))
                        }
                        .listRowBackground(theme.color(.surface))

                        ForEach(security.crashLogs) { log in
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(spacing: 8) {
                                    Image(systemName: log.isUnread ? "exclamationmark.triangle.fill" : "waveform.path.ecg")
                                        .foregroundStyle(log.isUnread ? .yellow : theme.color(.accent))

                                    Text(log.title)
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundStyle(theme.color(.text))
                                        .lineLimit(2)
                                }

                                Text(log.reason)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(theme.color(.mutedText))

                                Text(log.detail)
                                    .font(.caption)
                                    .foregroundStyle(theme.color(.mutedText))
                                    .fixedSize(horizontal: false, vertical: true)

                                HStack(spacing: 10) {
                                    Text(log.occurredAt, style: .relative)
                                    Text("v\(log.appVersion) (\(log.buildNumber))")
                                }
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(theme.color(.mutedText))
                            }
                            .padding(.vertical, 5)
                            .listRowBackground(theme.color(.surface))
                        }
                    }
                    .scrollContentBackground(.hidden)
                    .background(theme.color(.canvas))
                }
            }
            .navigationTitle("Crash Logs")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(role: .destructive) {
                        security.clearCrashLogs()
                    } label: {
                        Label("Clear", systemImage: "trash")
                    }
                    .disabled(security.crashLogs.isEmpty)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .onDisappear {
                security.markCrashLogsSeen()
            }
        }
    }
}

private struct LocalAIImportView: View {
    @EnvironmentObject private var model: BrowserViewModel
    @EnvironmentObject private var theme: BrowserTheme
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var urlText = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Local AI") {
                    TextField("Name", text: $name)
                    TextField("URL or host", text: $urlText)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                }

                Section {
                    Button("Import Local AI") {
                        model.importLocalAI(name: name, urlText: urlText)
                        model.openLocalAI()
                        dismiss()
                    }
                    .disabled(urlText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .scrollContentBackground(.hidden)
            .background(theme.color(.canvas))
            .foregroundStyle(theme.color(.text))
            .navigationTitle("Import Local AI")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                name = model.localAIName
                urlText = model.localAIURLText
            }
        }
    }
}

private enum NewTabActionLayout {
    case sidebar
    case strip
}

private struct NewTabActions: View {
    @EnvironmentObject private var model: BrowserViewModel
    @EnvironmentObject private var theme: BrowserTheme
    let layout: NewTabActionLayout

    var body: some View {
        HStack(spacing: 8) {
            Button {
                model.openNewTabAndSearch()
            } label: {
                HStack(spacing: 8) {
                    BrowserIcon(slot: .newTab, systemName: "plus.circle.fill", size: layout == .sidebar ? 22 : 20, weight: .bold)
                        .frame(width: 24, height: 24)
                    Text("New Tab")
                        .font(.system(size: 14, weight: .bold))
                        .lineLimit(1)
                }
                .foregroundStyle(theme.color(.canvas))
                .padding(.horizontal, 12)
                .frame(width: layout == .strip ? 136 : nil, height: 44)
                .frame(maxWidth: layout == .sidebar ? .infinity : nil)
                .background(theme.color(.createTab).opacity(theme.isUserBackgroundEnabled && theme.hasUserBackground ? max(theme.controlOpacity, 0.9) : theme.controlOpacity), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(theme.color(.border).opacity(0.45), lineWidth: 1)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("New Tab")

            Button {
                model.openNewTabAndSearch(private: true)
            } label: {
                BrowserIcon(slot: .privateTab, systemName: "theatermasks", size: 15, weight: .semibold)
                    .frame(width: 44, height: 44)
                    .foregroundStyle(theme.chromeForegroundColor)
                    .background(ControlGlassBackground(cornerRadius: 8))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(theme.color(.privateAccent).opacity(0.55), lineWidth: 1)
                    }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("New Private Tab")

            Button {
                model.openContainedTab()
            } label: {
                BrowserIcon(slot: .containedTabs, systemName: "rectangle.on.rectangle", size: 15, weight: .semibold)
                    .frame(width: 44, height: 44)
                    .foregroundStyle(theme.chromeForegroundColor)
                    .background(ControlGlassBackground(cornerRadius: 8))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(theme.color(.accent).opacity(0.55), lineWidth: 1)
                    }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("New Contained Tab")
        }
    }
}

private struct EssentialsSection: View {
    @EnvironmentObject private var model: BrowserViewModel
    @EnvironmentObject private var theme: BrowserTheme

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                BrowserIcon(slot: .essentials, systemName: "sparkle", size: 12, weight: .black)
                    .frame(width: 16, height: 16)
                Text("ESSENTIALS")
                    .font(.caption2.weight(.bold))
                Spacer(minLength: 0)
            }
            .foregroundStyle(theme.color(.mutedText))
            .padding(.horizontal, 4)

            ForEach(model.essentials) { item in
                EssentialPill(item: item, layout: .vertical)
            }
        }
    }
}

private enum EssentialPillLayout {
    case vertical
    case horizontal
}

private struct EssentialPill: View {
    @EnvironmentObject private var model: BrowserViewModel
    @EnvironmentObject private var theme: BrowserTheme
    let item: BrowserEssentialItem
    let layout: EssentialPillLayout

    var body: some View {
        Button {
            model.openEssential(item)
        } label: {
            HStack(spacing: 10) {
                BrowserIcon(slot: .essentials, systemName: "sparkle", size: 12, weight: .bold)
                    .frame(width: 28, height: 28)
                    .foregroundStyle(theme.color(.canvas))
                    .background(theme.color(.createTab).opacity(0.9), in: RoundedRectangle(cornerRadius: 7, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(theme.color(.text))
                        .lineLimit(1)

                    if layout == .vertical {
                        Text(item.url?.host ?? item.urlString)
                            .font(.caption2)
                            .foregroundStyle(theme.color(.mutedText))
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(.leading, 10)
            .padding(.trailing, 10)
            .frame(width: layout == .horizontal ? 178 : nil, height: 44)
            .frame(maxWidth: layout == .vertical ? .infinity : nil)
            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .background(ControlGlassBackground(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(theme.color(.createTab).opacity(0.38), lineWidth: 1)
        }
        .contextMenu {
            Button(role: .destructive) {
                model.removeEssential(item)
            } label: {
                Label("Remove from Essentials", systemImage: "xmark")
            }
        }
    }
}

private struct TabSection: View {
    @EnvironmentObject private var theme: BrowserTheme
    let title: String
    let tabs: [BrowserTab]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.caption2.weight(.bold))
                .foregroundStyle(theme.color(.mutedText))
                .padding(.horizontal, 4)

            ForEach(tabs) { tab in
                TabPill(tab: tab, layout: .vertical)
            }
        }
    }
}

private enum TabPillLayout {
    case vertical
    case horizontal
}

private struct TabPill: View {
    @EnvironmentObject private var model: BrowserViewModel
    @EnvironmentObject private var theme: BrowserTheme
    @ObservedObject var tab: BrowserTab
    let layout: TabPillLayout

    private var isSelected: Bool {
        model.selectedTabID.map { $0 == tab.id } ?? false
    }

    var body: some View {
        HStack(spacing: 6) {
            Button {
                model.select(tab)
            } label: {
                HStack(spacing: 10) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(tab.isPrivate ? theme.color(.privateAccent).opacity(0.82) : theme.color(.accent).opacity(0.24))
                        BrowserIcon(slot: tab.isPrivate ? .privateTab : .normalTab, systemName: tab.isPrivate ? "theatermasks" : "globe", size: 12, weight: .bold)
                            .frame(width: 18, height: 18)
                            .foregroundStyle(theme.color(.text))
                    }
                    .frame(width: 28, height: 28)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(tab.title)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(theme.color(.text))
                            .lineLimit(1)

                        if layout == .vertical {
                            Text(subtitle)
                                .font(.caption2)
                                .foregroundStyle(theme.color(.mutedText))
                                .lineLimit(1)
                        }
                    }

                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity)

            Button {
                model.close(tab)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
            .foregroundStyle(theme.color(.mutedText))
        }
        .padding(.leading, 10)
        .padding(.trailing, 6)
        .frame(width: layout == .horizontal ? 210 : nil, height: 46)
        .background(isSelected ? theme.color(.surface).opacity(theme.controlOpacity) : Color.clear, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(isSelected ? theme.color(.accent).opacity(0.72) : theme.color(.border).opacity(0.35), lineWidth: 1)
        }
        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .contextMenu {
            if tab.isPrivate == false {
                Button {
                    model.addEssential(from: tab)
                } label: {
                    Label("Add to Essentials", systemImage: "sparkle")
                }
            }

            Button(role: .destructive) {
                model.close(tab)
            } label: {
                Label("Close Tab", systemImage: "xmark")
            }
        }
    }

    private var subtitle: String {
        BrowserTab.isStartPageURL(tab.url)
            ? "Start Page"
            : (tab.url?.host ?? model.searchEngine.title)
    }
}

private struct FloatingTabSwitcher: View {
    @EnvironmentObject private var model: BrowserViewModel
    @EnvironmentObject private var theme: BrowserTheme

    var body: some View {
        Menu {
            Button {
                model.openNewTabAndSearch()
            } label: {
                Label("New Tab", systemImage: "plus")
            }

            Button {
                model.openPrivateTab()
            } label: {
                Label("New Private Tab", systemImage: "theatermasks")
            }

            Divider()

            ForEach(model.tabs) { tab in
                Button {
                    model.select(tab)
                } label: {
                    Label(tab.title, systemImage: tab.isPrivate ? "lock.shield" : "globe")
                }
            }

            Divider()

            Button {
                model.isTabFinderPresented = true
            } label: {
                Label("Tab Finder", systemImage: "square.grid.2x2")
            }

            PlacementMenuContent()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "square.on.square")
                Text("\(model.tabs.count)")
                    .font(.system(size: 14, weight: .bold))
            }
            .frame(height: 36)
            .padding(.horizontal, 12)
            .foregroundStyle(theme.chromeForegroundColor)
            .background {
                Capsule()
                    .fill(.ultraThinMaterial)
                    .overlay {
                        Capsule()
                            .fill(theme.color(.field).opacity(theme.isUserBackgroundEnabled && theme.hasUserBackground ? max(theme.controlOpacity, 0.88) : theme.controlOpacity))
                    }
            }
            .overlay {
                Capsule()
                    .stroke(theme.color(.border).opacity(0.48), lineWidth: 1)
            }
        }
    }
}

private struct PlacementMenuContent: View {
    @EnvironmentObject private var model: BrowserViewModel

    var body: some View {
        ForEach(BrowserChromePlacement.allCases) { placement in
            Button {
                model.chromePlacement = placement
            } label: {
                Label(placement.title, systemImage: placement.symbolName)
            }
        }
    }
}

private struct ChromeButton: View {
    @EnvironmentObject private var theme: BrowserTheme
    var slot: BrowserCustomIconSlot? = nil
    let symbol: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            BrowserIcon(slot: slot, systemName: symbol, size: 15, weight: .semibold)
                .frame(width: 36, height: 36)
                .foregroundStyle(theme.chromeForegroundColor)
                .background(ControlGlassBackground(cornerRadius: 8))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(theme.color(.border).opacity(0.4), lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .shadow(color: Color.black.opacity(theme.isUserBackgroundEnabled && theme.hasUserBackground ? 0.24 : 0.08), radius: 8, y: 4)
    }
}

private struct BrandMark: View {
    @EnvironmentObject private var theme: BrowserTheme

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(theme.color(.surface).opacity(theme.isUserBackgroundEnabled && theme.hasUserBackground ? max(theme.controlOpacity, 0.88) : theme.controlOpacity))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(theme.color(.accent).opacity(0.8), lineWidth: 1)
                }
            BrowserIcon(slot: .brand, systemName: "globe", size: 15, weight: .black)
                .frame(width: 22, height: 22)
                .foregroundStyle(theme.isUserBackgroundEnabled && theme.hasUserBackground ? Color.white : theme.color(.accent))
        }
        .frame(width: 36, height: 36)
    }
}

private struct BrowserBackground: View {
    @EnvironmentObject private var theme: BrowserTheme

    var body: some View {
        ZStack {
            if theme.isUserBackgroundEnabled,
               let image = theme.userBackgroundImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()
                theme.color(.canvas)
                    .opacity(0.34)
                    .ignoresSafeArea()
            } else {
                LinearGradient(
                    colors: [
                        theme.color(.canvas),
                        theme.color(.chrome),
                        theme.color(.canvas)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            }
        }
    }
}

private struct BrowserSettingsView: View {
    @EnvironmentObject private var model: BrowserViewModel
    @EnvironmentObject private var theme: BrowserTheme
    @EnvironmentObject private var security: AppSecurityModel
    @Environment(\.dismiss) private var dismiss
    @State private var isBackgroundImporterPresented = false
    @State private var isThemeImporterPresented = false
    @State private var themeExportItem: ThemeExportItem?
    @State private var themeImportMessage = ""
    @State private var savedThemeName = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Browsing") {
                    Toggle("Dark Reader style pages", isOn: darkReaderBinding)
                    Toggle("Block ads and trackers", isOn: adBlockerBinding)
                    Toggle("Hide tab bar", isOn: $model.areSideTabsCollapsed)
                    Toggle("Top search bar", isOn: $model.isTopSearchBarEnabled)
                    Picker("Chrome placement", selection: $model.chromePlacement) {
                        ForEach(BrowserChromePlacement.allCases) { placement in
                            Label(placement.title, systemImage: placement.symbolName)
                                .tag(placement)
                        }
                    }
                    Picker("Search engine", selection: $model.searchEngine) {
                        ForEach(BrowserSearchEngine.allCases) { engine in
                            Text(engine.title)
                                .tag(engine)
                        }
                    }

                    if model.searchEngine == .custom {
                        TextField("Search URL with {query}", text: $model.customSearchTemplate)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .keyboardType(.URL)
                    }

                    Button("Downloads") {
                        presentAfterDismiss {
                            model.isDownloadsPresented = true
                        }
                    }

                    Button("Tab Finder") {
                        presentAfterDismiss {
                            model.isTabFinderPresented = true
                        }
                    }

                    Button("Custom VPN") {
                        presentAfterDismiss {
                            model.isVPNPresented = true
                        }
                    }
                }

                Section("Advanced") {
                    Button {
                        presentAfterDismiss {
                            model.isAddOnsPresented = true
                        }
                    } label: {
                        Label("Add-ons Library", systemImage: "puzzlepiece")
                    }

                    Button {
                        presentAfterDismiss {
                            model.isAdvancedConfigPresented = true
                        }
                    } label: {
                        Label("Config Editor", systemImage: "curlybraces")
                    }

                    Button {
                        presentAfterDismiss {
                            model.isCustomIconsPresented = true
                        }
                    } label: {
                        Label("Custom Icons", systemImage: "app.badge")
                    }
                }

                Section("Three-Dot Menu") {
                    ForEach(BrowserToolbarAction.allCases) { action in
                        Toggle(isOn: moreMenuBinding(for: action)) {
                            Label(action.title, systemImage: action.symbolName)
                        }
                    }
                }

                Section("Privacy Lock") {
                    LabeledContent("Encrypted vault") {
                        Label("Unlocked", systemImage: "checkmark.shield")
                            .foregroundStyle(theme.color(.accent))
                    }

                    LabeledContent("Biometric unlock") {
                        Text(security.isBiometricAvailable ? security.biometricTitle : "Unavailable")
                            .foregroundStyle(theme.color(.mutedText))
                    }

                    Button(role: .destructive) {
                        dismiss()
                        security.lock()
                    } label: {
                        Label("Lock Glide Now", systemImage: "lock.fill")
                    }
                }

                Section("Crash Logs") {
                    LabeledContent("Status") {
                        Text(security.hasUnreadCrashLogs ? "New crash detected" : "\(security.crashLogs.count) saved")
                            .foregroundStyle(security.hasUnreadCrashLogs ? .yellow : theme.color(.mutedText))
                    }

                    Button {
                        presentAfterDismiss {
                            security.refreshCrashLogs()
                            security.isCrashLogsPresented = true
                        }
                    } label: {
                        Label("Open Crash Logs", systemImage: "waveform.path.ecg.rectangle")
                    }
                }

                Section("Backgrounds & Tab Bar") {
                    Toggle("Transparent tab bar", isOn: $theme.isTabBarTransparencyEnabled)

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Transparency")
                            Spacer()
                            Text("\(Int(theme.tabBarTransparency * 100))%")
                                .foregroundStyle(theme.color(.mutedText))
                        }
                        Slider(value: $theme.tabBarTransparency, in: 0...0.85)
                            .disabled(theme.isTabBarTransparencyEnabled == false)
                    }

                    Toggle("Use custom background", isOn: $theme.isUserBackgroundEnabled)
                        .disabled(theme.hasUserBackground == false)

                    if theme.isUserBackgroundEnabled,
                       let image = theme.userBackgroundImage {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(height: 92)
                            .frame(maxWidth: .infinity)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .stroke(theme.color(.border).opacity(0.75), lineWidth: 1)
                            }
                    }

                    HStack(spacing: 10) {
                        Button("Choose from Files") {
                            isBackgroundImporterPresented = true
                        }

                        BackgroundPhotoPickerButton(title: "Choose from Photos")
                    }

                    Button("Remove background") {
                        theme.clearUserBackground()
                    }
                    .disabled(theme.hasUserBackground == false)
                }

                Section("Local AI") {
                    TextField("Name", text: $model.localAIName)
                    TextField("URL or host", text: $model.localAIURLText)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)

                    Button("Import Local AI") {
                        model.isLocalAIImporterPresented = true
                    }
                }

                Section("Colors") {
                    ForEach(BrowserThemeToken.allCases) { token in
                        ColorPicker(token.title, selection: theme.binding(for: token), supportsOpacity: false)
                    }

                    Button("Reset to Zen dark defaults") {
                        theme.resetToZenDefaults()
                    }
                }

                Section("Saved Themes") {
                    TextField("Theme name", text: $savedThemeName)
                        .textInputAutocapitalization(.words)

                    Button("Save current theme") {
                        theme.saveCurrentTheme(named: savedThemeName)
                        savedThemeName = ""
                    }

                    HStack(spacing: 10) {
                        Button {
                            exportCurrentTheme()
                        } label: {
                            Label("Export current", systemImage: "square.and.arrow.up")
                        }
                        .buttonStyle(.bordered)

                        Button {
                            isThemeImporterPresented = true
                        } label: {
                            Label("Import from Files", systemImage: "square.and.arrow.down")
                        }
                        .buttonStyle(.bordered)
                    }

                    if themeImportMessage.isEmpty == false {
                        Text(themeImportMessage)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(theme.color(.mutedText))
                    }

                    if theme.savedThemes.isEmpty {
                        Text("No saved themes yet")
                            .foregroundStyle(theme.color(.mutedText))
                    } else {
                        ForEach(theme.savedThemes) { savedTheme in
                            HStack(spacing: 10) {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(savedTheme.name)
                                        .font(.body.weight(.semibold))
                                    Text("\(Int(savedTheme.tabBarTransparency * 100))% transparent")
                                        .font(.caption)
                                        .foregroundStyle(theme.color(.mutedText))
                                }

                                Spacer()

                                Button("Export") {
                                    exportTheme(savedTheme)
                                }
                                .buttonStyle(.bordered)

                                Button("Apply") {
                                    theme.applySavedTheme(savedTheme)
                                }
                                .buttonStyle(.bordered)

                                Button(role: .destructive) {
                                    theme.deleteSavedTheme(savedTheme)
                                } label: {
                                    Image(systemName: "trash")
                                }
                                .buttonStyle(.bordered)
                                .accessibilityLabel("Delete \(savedTheme.name)")
                            }
                        }
                    }
                }

                Section("Reset") {
                    Button("Reset to default") {
                        model.resetToDefaults()
                        theme.resetToZenDefaults()
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(theme.color(.canvas))
            .foregroundStyle(theme.color(.text))
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .fileImporter(
                isPresented: $isBackgroundImporterPresented,
                allowedContentTypes: [.image],
                allowsMultipleSelection: false
            ) { result in
                if case .success(let urls) = result,
                   let url = urls.first {
                    theme.setUserBackground(from: url)
                }
            }
            .fileImporter(
                isPresented: $isThemeImporterPresented,
                allowedContentTypes: [.glideTheme, .json, .data],
                allowsMultipleSelection: false
            ) { result in
                importTheme(result)
            }
            .sheet(item: $themeExportItem) { item in
                ThemeFileExportController(url: item.url) {
                    themeExportItem = nil
                }
                .ignoresSafeArea()
            }
        }
    }

    private var darkReaderBinding: Binding<Bool> {
        Binding(
            get: { model.isDarkReaderEnabled },
            set: { model.setDarkReaderEnabled($0) }
        )
    }

    private var adBlockerBinding: Binding<Bool> {
        Binding(
            get: { model.isAdBlockerEnabled },
            set: { model.setAdBlockerEnabled($0) }
        )
    }

    private func moreMenuBinding(for action: BrowserToolbarAction) -> Binding<Bool> {
        Binding(
            get: { model.isInMoreMenu(action) },
            set: { model.setMoreMenuAction(action, enabled: $0) }
        )
    }

    private func presentAfterDismiss(_ action: @escaping () -> Void) {
        dismiss()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18, execute: action)
    }

    private func exportCurrentTheme() {
        let themeName = savedThemeName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "Glide Theme"
            : savedThemeName
        exportTheme(theme.currentTheme(named: themeName))
    }

    private func exportTheme(_ savedTheme: SavedBrowserTheme) {
        do {
            let url = try theme.exportThemeFile(savedTheme)
            themeExportItem = ThemeExportItem(url: url)
            themeImportMessage = "Ready to save \(savedTheme.name)."
        } catch {
            themeImportMessage = error.localizedDescription
        }
    }

    private func importTheme(_ result: Result<[URL], Error>) {
        do {
            guard let url = try result.get().first else { return }
            let importedTheme = try theme.importTheme(from: url)
            themeImportMessage = "Imported and applied \(importedTheme.name)."
        } catch {
            themeImportMessage = error.localizedDescription
        }
    }
}

private struct ThemeExportItem: Identifiable {
    let id = UUID()
    let url: URL
}

private struct ThemeFileExportController: UIViewControllerRepresentable {
    let url: URL
    let onComplete: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onComplete: onComplete)
    }

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let controller = UIDocumentPickerViewController(forExporting: [url], asCopy: true)
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onComplete: () -> Void

        init(onComplete: @escaping () -> Void) {
            self.onComplete = onComplete
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            onComplete()
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            onComplete()
        }
    }
}

private struct AddOnsLibraryView: View {
    @EnvironmentObject private var model: BrowserViewModel
    @EnvironmentObject private var theme: BrowserTheme
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Add-ons") {
                    ForEach(BrowserAddOnLibrary.allCases) { library in
                        Button {
                            model.openAddOnLibrary(library)
                            dismiss()
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: library.symbolName)
                                    .font(.system(size: 17, weight: .bold))
                                    .frame(width: 34, height: 34)
                                    .foregroundStyle(theme.color(.accent))
                                    .background(theme.color(.field).opacity(theme.controlOpacity), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                                VStack(alignment: .leading, spacing: 3) {
                                    Text(library.title)
                                        .font(.body.weight(.semibold))
                                        .foregroundStyle(theme.color(.text))
                                    Text(library.subtitle)
                                        .font(.caption)
                                        .foregroundStyle(theme.color(.mutedText))
                                }

                                Spacer(minLength: 0)
                            }
                        }
                    }
                }

                Section("Compatibility") {
                    Text("Glide can browse Firefox and Brave add-on libraries. iOS WKWebView does not expose desktop extension installation, so add-ons open as web pages.")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(theme.color(.mutedText))
                }
            }
            .scrollContentBackground(.hidden)
            .background(theme.color(.canvas))
            .foregroundStyle(theme.color(.text))
            .navigationTitle("Add-ons Library")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

private struct AdvancedConfigView: View {
    @EnvironmentObject private var model: BrowserViewModel
    @EnvironmentObject private var theme: BrowserTheme
    @Environment(\.dismiss) private var dismiss
    @State private var configText = ""
    @State private var statusMessage = ""
    @State private var hasLoaded = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                TextEditor(text: $configText)
                    .font(.system(size: 12, weight: .regular, design: .monospaced))
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .scrollContentBackground(.hidden)
                    .padding(10)
                    .background(theme.color(.surface), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(theme.color(.border).opacity(0.72), lineWidth: 1)
                    }

                if statusMessage.isEmpty == false {
                    Label(statusMessage, systemImage: statusMessage.hasPrefix("Applied") ? "checkmark.circle" : "exclamationmark.triangle")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(statusMessage.hasPrefix("Applied") ? theme.color(.accent) : .red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                HStack(spacing: 10) {
                    Button("Discard") {
                        reloadConfig()
                    }
                    .buttonStyle(.bordered)

                    Spacer()

                    Button("Apply") {
                        applyConfig(shouldDismiss: false)
                    }
                    .buttonStyle(.borderedProminent)

                    Button("Save") {
                        applyConfig(shouldDismiss: true)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding(16)
            .background(theme.color(.canvas))
            .foregroundStyle(theme.color(.text))
            .navigationTitle("Advanced Config")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                if hasLoaded == false {
                    reloadConfig()
                    hasLoaded = true
                }
            }
        }
    }

    private func reloadConfig() {
        configText = model.advancedConfigJSON(theme: theme)
        statusMessage = ""
    }

    private func applyConfig(shouldDismiss: Bool) {
        do {
            try model.applyAdvancedConfigJSON(configText, theme: theme)
            configText = model.advancedConfigJSON(theme: theme)
            statusMessage = "Applied config."
            if shouldDismiss {
                dismiss()
            }
        } catch {
            statusMessage = error.localizedDescription
        }
    }
}

private struct CustomIconsView: View {
    @EnvironmentObject private var model: BrowserViewModel
    @EnvironmentObject private var theme: BrowserTheme
    @Environment(\.dismiss) private var dismiss
    @State private var importingSlot: BrowserCustomIconSlot?
    @State private var isIconImporterPresented = false
    @State private var importStatusMessage = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Icon Slots") {
                    ForEach(BrowserCustomIconSlot.allCases) { slot in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 10) {
                                BrowserIcon(slot: slot, systemName: slot.defaultSymbol, size: 17, weight: .semibold)
                                    .frame(width: 34, height: 34)
                                    .foregroundStyle(theme.color(.accent))
                                    .background(theme.color(.field).opacity(theme.controlOpacity), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                                            .stroke(theme.color(.border).opacity(0.52), lineWidth: 1)
                                    }

                                Text(slot.title)
                                    .font(.body.weight(.semibold))

                                Spacer(minLength: 0)

                                if model.hasCustomIconImage(for: slot) {
                                    Label("Image", systemImage: "checkmark.circle.fill")
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(theme.color(.accent))
                                }
                            }

                            TextField(slot.defaultSymbol, text: iconNameBinding(for: slot))
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .font(.system(.footnote, design: .monospaced))

                            HStack(spacing: 8) {
                                Button("Import") {
                                    importingSlot = slot
                                    isIconImporterPresented = true
                                }
                                .buttonStyle(.bordered)

                                Button("Clear Image") {
                                    model.clearCustomIconImage(for: slot)
                                }
                                .buttonStyle(.bordered)
                                .disabled(model.hasCustomIconImage(for: slot) == false)

                                Button("Default") {
                                    model.setCustomIconName("", for: slot)
                                    model.clearCustomIconImage(for: slot)
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }

                if importStatusMessage.isEmpty == false {
                    Section {
                        Label(importStatusMessage, systemImage: "info.circle")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(theme.color(.mutedText))
                    }
                }

                Section("Reset") {
                    Button(role: .destructive) {
                        model.resetCustomIcons()
                    } label: {
                        Label("Reset all icons", systemImage: "arrow.counterclockwise")
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(theme.color(.canvas))
            .foregroundStyle(theme.color(.text))
            .navigationTitle("Custom Icons")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .fileImporter(
                isPresented: $isIconImporterPresented,
                allowedContentTypes: [.image],
                allowsMultipleSelection: false
            ) { result in
                guard let slot = importingSlot else { return }
                importingSlot = nil

                switch result {
                case .success(let urls):
                    if let url = urls.first {
                        model.setCustomIconImage(from: url, for: slot)
                        importStatusMessage = "Imported \(slot.title)."
                    }
                case .failure(let error):
                    importStatusMessage = error.localizedDescription
                }
            }
        }
    }

    private func iconNameBinding(for slot: BrowserCustomIconSlot) -> Binding<String> {
        Binding(
            get: { model.customIconNames[slot.rawValue] ?? "" },
            set: { model.setCustomIconName($0, for: slot) }
        )
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
