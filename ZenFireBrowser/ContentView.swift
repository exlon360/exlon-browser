import SwiftUI
import AVFoundation
import PhotosUI
import QuickLook
import UIKit
import UniformTypeIdentifiers
import WebKit

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
    @StateObject private var profiles: BrowserProfileManager

    init(vault: SecureBrowserVault) {
        _profiles = StateObject(wrappedValue: BrowserProfileManager(vault: vault))
    }

    var body: some View {
        BrowserProfileSessionRoot(vault: profiles.activeVault, profileID: profiles.activeProfile.id)
            .id(profiles.activeProfile.id)
            .environmentObject(profiles)
            .preferredColorScheme(.dark)
    }
}

private struct BrowserProfileSessionRoot: View {
    @StateObject private var model: BrowserViewModel
    @StateObject private var theme: BrowserTheme

    init(vault: SecureBrowserVault, profileID: String) {
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
    @State private var isForgotPINAlertPresented = false
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

                if security.isConfigured == false {
                    PremiumSetupPreview()
                        .frame(maxWidth: 440)
                        .padding(.horizontal, 24)
                        .transition(.opacity.combined(with: .scale(scale: 0.98)))
                }

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
                        .background(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.84, green: 0.89, blue: 1.0),
                                    Color(red: 0.62, green: 0.70, blue: 0.98),
                                    Color(red: 0.74, green: 0.62, blue: 0.98)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                        )
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

                    if security.isConfigured {
                        Button(role: .destructive) {
                            isForgotPINAlertPresented = true
                        } label: {
                            Label("Forgot PIN?", systemImage: "exclamationmark.lock")
                                .font(.system(size: 14, weight: .bold))
                                .frame(maxWidth: 440)
                                .frame(height: 42)
                                .foregroundStyle(Color.white.opacity(0.72))
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
        .alert("Reset Glide vault?", isPresented: $isForgotPINAlertPresented) {
            Button("Cancel", role: .cancel) {}
            Button("Erase and Reset PIN", role: .destructive) {
                security.resetForgottenPIN()
                pin = ""
                confirmation = ""
                focusedField = .pin
            }
        } message: {
            Text("This erases saved tabs, passwords, add-ons, settings, cookies, and local browser data. Use it only if the PIN is lost.")
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

private struct PremiumSetupPreview: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "crown.fill")
                    .font(.system(size: 14, weight: .black))
                    .frame(width: 30, height: 30)
                    .foregroundStyle(Color(red: 0.05, green: 0.06, blue: 0.08))
                    .background(
                        LinearGradient(
                            colors: [
                                Color(red: 0.84, green: 0.89, blue: 1.0),
                                Color(red: 0.74, green: 0.62, blue: 0.98)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text("Premium private setup")
                        .font(.system(size: 15, weight: .black))
                        .foregroundStyle(Color.white.opacity(0.94))
                    Text("Profiles, resolution, color studio, moving gradients, and Shields Max are ready after unlock.")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.62))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            HStack(spacing: 8) {
                PremiumSetupChip(symbol: "person.2.fill", title: "Profiles")
                PremiumSetupChip(symbol: "rectangle.resize", title: "Resolution")
                PremiumSetupChip(symbol: "paintpalette.fill", title: "Color")
            }
        }
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.18), lineWidth: 1)
        }
    }
}

private struct PremiumSetupChip: View {
    let symbol: String
    let title: String

    var body: some View {
        Label(title, systemImage: symbol)
            .font(.system(size: 11, weight: .black))
            .lineLimit(1)
            .minimumScaleFactor(0.82)
            .frame(maxWidth: .infinity)
            .frame(height: 30)
            .foregroundStyle(Color.white.opacity(0.86))
            .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            }
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

private enum GlideDeviceExperience: Equatable {
    case phone
    case iPad

    var title: String {
        switch self {
        case .phone:
            return "Glide for iPhone"
        case .iPad:
            return "Glide for iPad"
        }
    }

    var symbolName: String {
        switch self {
        case .phone:
            return "iphone"
        case .iPad:
            return "ipad"
        }
    }

    static func resolve(
        for size: CGSize,
        override: BrowserDeviceExperienceOverride = .automatic
    ) -> GlideDeviceExperience {
        switch override {
        case .automatic:
            break
        case .phone:
            return .phone
        case .iPad:
            return .iPad
        }

        if UIDevice.current.userInterfaceIdiom == .pad {
            return .iPad
        }

        return min(size.width, size.height) >= 600 ? GlideDeviceExperience.iPad : GlideDeviceExperience.phone
    }
}

private struct BrowserShell: View {
    @EnvironmentObject private var model: BrowserViewModel
    @EnvironmentObject private var theme: BrowserTheme
    @EnvironmentObject private var security: AppSecurityModel
    @EnvironmentObject private var profiles: BrowserProfileManager
    @State private var isDesktopZenChromeHovered = false

    var body: some View {
        GeometryReader { proxy in
            let virtualSize = proxy.size

            ZStack {
                BrowserBackground()

                ZStack {
                let experience = GlideDeviceExperience.resolve(
                    for: virtualSize,
                    override: model.effectiveDeviceExperienceOverride
                )
                PhoneExperienceSyncView(isPhoneExperience: experience == .phone)

                if isDesktopZenModeActive {
                    DesktopZenBrowserLayout(
                        sideWidth: sideWidth(for: virtualSize, experience: experience),
                        containerWidth: virtualSize.width,
                        experience: experience,
                        isChromeHovered: $isDesktopZenChromeHovered
                    )
                } else {
                    switch model.chromePlacement {
                    case .left:
                        SideBrowserLayout(edge: .left, sideWidth: sideWidth(for: virtualSize, experience: experience), containerWidth: virtualSize.width, experience: experience)
                    case .right:
                        SideBrowserLayout(edge: .right, sideWidth: sideWidth(for: virtualSize, experience: experience), containerWidth: virtualSize.width, experience: experience)
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
                }

                MovableBrowserPageControls(
                    containerSize: virtualSize,
                    defaultLeading: pageControlsLeadingPadding(for: virtualSize, experience: experience),
                    defaultTop: pageControlsTopPadding
                )
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

                if model.isPrivateModeEnabled {
                    PrivateModeBadge()
                        .padding(.top, privateModeBadgeTopPadding)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                if model.isTopSearchBarEnabled {
                    MovableTopSearchBar(
                        containerSize: virtualSize,
                        topInset: topSearchBarTopPadding,
                        bottomInset: topSearchBarBottomPadding,
                        experience: experience
                    )
                        .transition(topSearchBarTransition)
                }

                if model.isTopSearchBarMoveMode {
                    TopSearchBarMoveControls()
                        .padding(.horizontal, 16)
                        .padding(.bottom, 18)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                if model.isChromeWidthResizeMode {
                    ChromeWidthResizeControls(experience: experience)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 18)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                if model.isPageControlsMoveMode {
                    PageControlsMoveControls()
                        .padding(.horizontal, 16)
                        .padding(.bottom, 18)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                if let item = model.latestDownloadShelfItem {
                    DownloadShelf(item: item)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 16)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                if model.isContainedBrowserPresented {
                    ContainedBrowserOverlay()
                        .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .center)))
                }

                if model.isFloatingSearchPresented {
                    FloatingSearchOverlay(experience: experience)
                        .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .top)))
                }

                BrowserShellGestureInstaller(
                    isTwoFingerDoubleTapEnabled: experience == .phone || model.isTwoFingerDoubleTapCompactEnabledOnIPad,
                    onTwoFingerSwipe: { deltaX, deltaY in
                        model.handleTwoFingerSwipe(deltaX: deltaX, deltaY: deltaY)
                    },
                    onThreeFingerSwipe: { deltaX in
                        model.handleThreeFingerSwipe(deltaX: deltaX)
                    },
                    onTwoFingerDoubleTap: {
                        model.handleTwoFingerDoubleTap()
                    }
                )
                .frame(width: 1, height: 1)
                .allowsHitTesting(false)

                BrowserKeyboardShortcutHost()
                }
                .frame(width: virtualSize.width, height: virtualSize.height)
                .frame(width: proxy.size.width, height: proxy.size.height)
                .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
                .clipped()
            }
            .coordinateSpace(name: "browserShell")
            .animation(.spring(response: 0.25, dampingFraction: 0.86), value: model.isFloatingSearchPresented)
            .animation(.spring(response: 0.27, dampingFraction: 0.86), value: model.isContainedBrowserPresented)
            .animation(.spring(response: 0.28, dampingFraction: 0.84), value: model.areSideTabsCollapsed)
            .animation(.spring(response: 0.24, dampingFraction: 0.88), value: model.isDesktopZenModeEnabled)
            .animation(.spring(response: 0.24, dampingFraction: 0.88), value: isDesktopZenChromeHovered)
            .ignoresSafeArea(.keyboard, edges: .bottom)
            .sheet(isPresented: $model.isSettingsPresented) {
                BrowserSettingsView(
                    currentExperience: GlideDeviceExperience.resolve(
                        for: virtualSize,
                        override: model.effectiveDeviceExperienceOverride
                    )
                )
                    .environmentObject(model)
                    .environmentObject(theme)
                    .environmentObject(security)
                    .environmentObject(profiles)
                    .preferredColorScheme(.dark)
            }
            .sheet(isPresented: $model.isTabFinderPresented) {
                BrowserTabFinderView()
                    .environmentObject(model)
                    .environmentObject(theme)
                    .preferredColorScheme(.dark)
            }
            .sheet(isPresented: $model.isTabFoldersPresented) {
                BrowserTabFoldersView()
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
            .sheet(isPresented: $model.isPasswordManagerPresented) {
                PasswordManagerView()
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
            .sheet(isPresented: $model.isPrivateModeAuthPresented) {
                PrivateModeAuthView()
                    .environmentObject(model)
                    .environmentObject(theme)
                    .environmentObject(security)
                    .preferredColorScheme(.dark)
            }
            .sheet(isPresented: $model.isLocalAIImporterPresented) {
                LocalAIImportView()
                    .environmentObject(model)
                    .environmentObject(theme)
                    .preferredColorScheme(.dark)
            }
            .sheet(isPresented: $model.isAIPanelPresented) {
                GlideAIPanelView()
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
            .fullScreenCover(isPresented: $model.isFeatureUpdatePresented) {
                GlideFeatureUpdateView()
                    .environmentObject(model)
                    .environmentObject(theme)
                    .environmentObject(profiles)
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
            .alert("Close all tabs?", isPresented: $model.isCloseAllTabsWarningPresented) {
                Button("Cancel", role: .cancel) {}
                Button("Close All Tabs", role: .destructive) {
                    model.closeAllTabs()
                }
            } message: {
                Text(model.closeAllTabsWarningMessage)
            }
            .onAppear {
                security.presentCrashLogsIfNeeded()
            }
            .onChange(of: model.isDesktopZenModeEnabled) { _, enabled in
                if enabled == false {
                    isDesktopZenChromeHovered = false
                }
            }
        }
        .tint(theme.color(.accent))
    }

    private var isDesktopZenModeActive: Bool {
        BrowserViewModel.supportsDesktopZenMode && model.isDesktopZenModeEnabled
    }

    private var isDesktopZenChromeVisible: Bool {
        isDesktopZenModeActive && (isDesktopZenChromeHovered || model.isChromeWidthResizeMode)
    }

    private func chromeIsVisible(for placement: BrowserChromePlacement) -> Bool {
        guard model.chromePlacement == placement else { return false }
        if isDesktopZenModeActive {
            return isDesktopZenChromeVisible
        }
        return model.areSideTabsCollapsed == false
    }

    private func sideWidth(for size: CGSize, experience: GlideDeviceExperience) -> CGFloat {
        if experience == .phone {
            return max(1, size.width)
        }

        let width = size.width * CGFloat(model.sideChromeWidthFraction)
        return min(max(width, 286), min(size.width - 120, 520))
    }

    private func pageControlsLeadingPadding(for size: CGSize, experience: GlideDeviceExperience) -> CGFloat {
        if experience == .phone {
            return 14
        }

        if chromeIsVisible(for: .left) {
            return sideWidth(for: size, experience: experience) + 18
        }
        return 14
    }

    private var pageControlsTopPadding: CGFloat {
        if model.isTopSearchBarEnabled && model.topSearchBarPlacement == .top {
            return topSearchBarTopPadding + 62
        }

        if chromeIsVisible(for: .top) {
            return 118
        }
        return 14
    }

    private var privateModeBadgeTopPadding: CGFloat {
        if chromeIsVisible(for: .top) {
            return 118
        }
        return 18
    }

    private var topSearchBarTopPadding: CGFloat {
        if chromeIsVisible(for: .top) {
            return 112
        }
        return 12
    }

    private var topSearchBarBottomPadding: CGFloat {
        if chromeIsVisible(for: .bottom) {
            return 112
        }
        return 16
    }

    private var topSearchBarAlignment: Alignment {
        switch model.topSearchBarPlacement {
        case .top:
            return .top
        case .center:
            return .center
        case .bottom:
            return .bottom
        }
    }

    private var topSearchBarPadding: EdgeInsets {
        switch model.topSearchBarPlacement {
        case .top:
            return EdgeInsets(top: topSearchBarTopPadding, leading: 0, bottom: 0, trailing: 0)
        case .center:
            return EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0)
        case .bottom:
            return EdgeInsets(top: 0, leading: 0, bottom: topSearchBarBottomPadding, trailing: 0)
        }
    }

    private var topSearchBarTransition: AnyTransition {
        switch model.topSearchBarPlacement {
        case .top:
            return .move(edge: .top).combined(with: .opacity)
        case .center:
            return .scale(scale: 0.96).combined(with: .opacity)
        case .bottom:
            return .move(edge: .bottom).combined(with: .opacity)
        }
    }
}

private struct PhoneExperienceSyncView: View {
    @EnvironmentObject private var model: BrowserViewModel
    let isPhoneExperience: Bool

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .allowsHitTesting(false)
            .onAppear {
                model.setPhoneExperienceActive(isPhoneExperience)
            }
            .onChange(of: isPhoneExperience) { _, newValue in
                model.setPhoneExperienceActive(newValue)
            }
    }
}

private struct BrowserKeyboardShortcutHost: View {
    @EnvironmentObject private var model: BrowserViewModel

    var body: some View {
        Group {
            shortcutButton("New Tab", key: "t", modifiers: [.control]) {
                model.openNewTabAndSearch(private: model.isPrivateModeEnabled)
            }
            shortcutButton("New Tab", key: "t", modifiers: [.command]) {
                model.openNewTabAndSearch(private: model.isPrivateModeEnabled)
            }
            shortcutButton("Close Tab", key: "w", modifiers: [.control]) {
                model.closeSelectedTab()
            }
            shortcutButton("Close Tab", key: "w", modifiers: [.command]) {
                model.closeSelectedTab()
            }
            shortcutButton("Search or Address", key: "l", modifiers: [.control]) {
                model.openFloatingSearch()
            }
            shortcutButton("Search or Address", key: "l", modifiers: [.command]) {
                model.openFloatingSearch()
            }
            shortcutButton("Reload", key: "r", modifiers: [.control]) {
                model.reloadOrStop()
            }
            shortcutButton("Reload", key: "r", modifiers: [.command]) {
                model.reloadOrStop()
            }
            shortcutButton("Back", key: "[", modifiers: [.control]) {
                model.goBack()
            }
            shortcutButton("Back", key: "[", modifiers: [.command]) {
                model.goBack()
            }
            shortcutButton("Forward", key: "]", modifiers: [.control]) {
                model.goForward()
            }
            shortcutButton("Forward", key: "]", modifiers: [.command]) {
                model.goForward()
            }
            shortcutButton("Next Tab", key: .tab, modifiers: [.control]) {
                model.selectNextTab()
            }
            shortcutButton("Previous Tab", key: .tab, modifiers: [.control, .shift]) {
                model.selectPreviousTab()
            }
            shortcutButton("Previous Tab", key: "[", modifiers: [.control, .shift]) {
                model.selectPreviousTab()
            }
            shortcutButton("Previous Tab", key: "[", modifiers: [.command, .shift]) {
                model.selectPreviousTab()
            }
            shortcutButton("Next Tab", key: "]", modifiers: [.control, .shift]) {
                model.selectNextTab()
            }
            shortcutButton("Next Tab", key: "]", modifiers: [.command, .shift]) {
                model.selectNextTab()
            }
            shortcutButton("Settings", key: ",", modifiers: [.control]) {
                model.isSettingsPresented = true
            }
            shortcutButton("Settings", key: ",", modifiers: [.command]) {
                model.isSettingsPresented = true
            }
        }
        .frame(width: 1, height: 1)
        .opacity(0)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func shortcutButton(
        _ title: String,
        key: KeyEquivalent,
        modifiers: EventModifiers,
        action: @escaping () -> Void
    ) -> some View {
        Button(title, action: action)
            .keyboardShortcut(key, modifiers: modifiers)
    }
}

private struct BrowserShellGestureInstaller: UIViewRepresentable {
    let isTwoFingerDoubleTapEnabled: Bool
    let onTwoFingerSwipe: (CGFloat, CGFloat) -> Void
    let onThreeFingerSwipe: (CGFloat) -> Void
    let onTwoFingerDoubleTap: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.isUserInteractionEnabled = false
        DispatchQueue.main.async {
            context.coordinator.install(from: view)
        }
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.parent = self
        DispatchQueue.main.async {
            context.coordinator.install(from: uiView)
        }
    }

    static func dismantleUIView(_ uiView: UIView, coordinator: Coordinator) {
        coordinator.uninstall()
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var parent: BrowserShellGestureInstaller
        private weak var installedView: UIView?
        private let twoFingerPan = UIPanGestureRecognizer()
        private let threeFingerPan = UIPanGestureRecognizer()
        private let twoFingerDoubleTap = UITapGestureRecognizer()
        private let minimumDistance: CGFloat = 154
        private let directionRatio: CGFloat = 1.6
        private let pinchDistanceTolerance: CGFloat = 28
        private let pinchRelativeTolerance: CGFloat = 0.10
        private var twoFingerStartDistance: CGFloat?
        private var twoFingerRejectedForPinch = false

        init(parent: BrowserShellGestureInstaller) {
            self.parent = parent
            super.init()
            twoFingerPan.addTarget(self, action: #selector(handleTwoFingerPan(_:)))
            twoFingerPan.minimumNumberOfTouches = 2
            twoFingerPan.maximumNumberOfTouches = 2
            twoFingerPan.cancelsTouchesInView = false
            twoFingerPan.delegate = self

            twoFingerDoubleTap.addTarget(self, action: #selector(handleTwoFingerDoubleTap(_:)))
            twoFingerDoubleTap.numberOfTouchesRequired = 2
            twoFingerDoubleTap.numberOfTapsRequired = 2
            twoFingerDoubleTap.cancelsTouchesInView = false
            twoFingerDoubleTap.delaysTouchesBegan = false
            twoFingerDoubleTap.delaysTouchesEnded = false
            twoFingerDoubleTap.delegate = self

            threeFingerPan.addTarget(self, action: #selector(handleThreeFingerPan(_:)))
            threeFingerPan.minimumNumberOfTouches = 3
            threeFingerPan.maximumNumberOfTouches = 3
            threeFingerPan.cancelsTouchesInView = false
            threeFingerPan.delegate = self
        }

        func install(from view: UIView) {
            guard let target = view.superview else { return }
            twoFingerDoubleTap.isEnabled = parent.isTwoFingerDoubleTapEnabled
            guard installedView !== target else { return }
            uninstall()
            target.addGestureRecognizer(twoFingerPan)
            target.addGestureRecognizer(threeFingerPan)
            target.addGestureRecognizer(twoFingerDoubleTap)
            installedView = target
        }

        func uninstall() {
            installedView?.removeGestureRecognizer(twoFingerPan)
            installedView?.removeGestureRecognizer(threeFingerPan)
            installedView?.removeGestureRecognizer(twoFingerDoubleTap)
            installedView = nil
        }

        @objc private func handleTwoFingerPan(_ recognizer: UIPanGestureRecognizer) {
            switch recognizer.state {
            case .began:
                twoFingerStartDistance = twoFingerDistance(in: recognizer)
                twoFingerRejectedForPinch = false
                return
            case .changed:
                updatePinchRejection(for: recognizer)
                return
            case .ended:
                break
            case .cancelled, .failed:
                resetTwoFingerTracking()
                return
            default:
                return
            }

            defer { resetTwoFingerTracking() }
            updatePinchRejection(for: recognizer)
            guard twoFingerRejectedForPinch == false,
                  let view = recognizer.view else { return }
            let translation = recognizer.translation(in: view)
            let absX = abs(translation.x)
            let absY = abs(translation.y)
            guard max(absX, absY) >= minimumDistance else { return }

            if absY >= absX * directionRatio {
                parent.onTwoFingerSwipe(0, translation.y)
            } else if absX >= absY * directionRatio {
                parent.onTwoFingerSwipe(translation.x, 0)
            }
        }

        @objc private func handleThreeFingerPan(_ recognizer: UIPanGestureRecognizer) {
            guard recognizer.state == .ended,
                  let view = recognizer.view else { return }
            let translation = recognizer.translation(in: view)
            guard abs(translation.x) >= minimumDistance,
                  abs(translation.x) >= abs(translation.y) * directionRatio else { return }
            parent.onThreeFingerSwipe(translation.x)
        }

        @objc private func handleTwoFingerDoubleTap(_ recognizer: UITapGestureRecognizer) {
            guard recognizer.state == .recognized,
                  parent.isTwoFingerDoubleTapEnabled else { return }
            parent.onTwoFingerDoubleTap()
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            if gestureRecognizer === twoFingerDoubleTap || otherGestureRecognizer === twoFingerDoubleTap {
                return true
            }
            if gestureRecognizer is UIPinchGestureRecognizer || otherGestureRecognizer is UIPinchGestureRecognizer {
                return false
            }
            return true
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
            if gestureRecognizer === twoFingerDoubleTap {
                return parent.isTwoFingerDoubleTapEnabled
            }
            return touch.view?.hasSuperview(of: WKWebView.self) == false
        }

        private func twoFingerDistance(in recognizer: UIPanGestureRecognizer) -> CGFloat? {
            guard recognizer.numberOfTouches >= 2,
                  let view = recognizer.view else { return nil }
            let first = recognizer.location(ofTouch: 0, in: view)
            let second = recognizer.location(ofTouch: 1, in: view)
            return hypot(first.x - second.x, first.y - second.y)
        }

        private func updatePinchRejection(for recognizer: UIPanGestureRecognizer) {
            guard let start = twoFingerStartDistance,
                  let current = twoFingerDistance(in: recognizer),
                  start > 0 else { return }
            let allowedDelta = max(pinchDistanceTolerance, start * pinchRelativeTolerance)
            if abs(current - start) > allowedDelta {
                twoFingerRejectedForPinch = true
            }
        }

        private func resetTwoFingerTracking() {
            twoFingerStartDistance = nil
            twoFingerRejectedForPinch = false
        }
    }
}

private extension UIView {
    func hasSuperview<T: UIView>(of type: T.Type) -> Bool {
        var view: UIView? = self
        while let current = view {
            if current is T {
                return true
            }
            view = current.superview
        }
        return false
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

private enum ButtonGradientProminence {
    case standard
    case primary
    case quiet
}

private struct ButtonGradientBackground: View {
    @EnvironmentObject private var theme: BrowserTheme
    let cornerRadius: CGFloat
    var prominence: ButtonGradientProminence = .standard
    var isPressed = false

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(.ultraThinMaterial)
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(gradient)
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color.black.opacity(theme.isUserBackgroundEnabled && theme.hasUserBackground ? 0.16 : 0))
            }
            .opacity(isPressed ? 0.86 : 1)
    }

    private var gradient: LinearGradient {
        switch prominence {
        case .primary:
            return LinearGradient(
                colors: primaryGradientColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .standard:
            return LinearGradient(
                colors: standardGradientColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .quiet:
            return LinearGradient(
                colors: quietGradientColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private var primaryGradientColors: [Color] {
        var colors = [theme.color(.createTab).opacity(0.98)]
        colors.append(contentsOf: theme.gradientColors(for: .createTab).map { $0.opacity(0.94) })
        colors.append(contentsOf: theme.customGradientColors.map { $0.opacity(0.9) })
        colors.append(contentsOf: theme.gradientColors(for: .accent).map { $0.opacity(0.84) })
        colors.append(theme.color(.surface).opacity(0.76))
        return colors
    }

    private var standardGradientColors: [Color] {
        var colors = [theme.color(.field).opacity(controlOpacity)]
        colors.append(contentsOf: theme.gradientColors(for: .field).map { $0.opacity(max(controlOpacity, 0.64)) })
        colors.append(contentsOf: theme.customGradientColors.map { $0.opacity(0.34) })
        colors.append(contentsOf: theme.gradientColors(for: .accent).map { $0.opacity(0.28) })
        colors.append(theme.color(.field).opacity(max(0.18, controlOpacity * 0.82)))
        return colors
    }

    private var quietGradientColors: [Color] {
        var colors = [theme.color(.surface).opacity(max(controlOpacity, 0.48))]
        colors.append(contentsOf: theme.gradientColors(for: .surface).map { $0.opacity(max(controlOpacity, 0.42)) })
        colors.append(contentsOf: theme.customGradientColors.map { $0.opacity(0.22) })
        colors.append(contentsOf: theme.gradientColors(for: .accent).map { $0.opacity(0.16) })
        colors.append(theme.color(.surface).opacity(max(0.16, controlOpacity * 0.72)))
        return colors
    }

    private var controlOpacity: Double {
        theme.isUserBackgroundEnabled && theme.hasUserBackground
            ? max(theme.controlOpacity, 0.88)
            : theme.controlOpacity
    }
}

private struct GlideGradientButtonStyle: ButtonStyle {
    @EnvironmentObject private var theme: BrowserTheme
    var prominence: ButtonGradientProminence = .standard
    var minHeight: CGFloat = 36
    var cornerRadius: CGFloat = 8

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .bold))
            .padding(.horizontal, 12)
            .frame(minHeight: minHeight)
            .foregroundStyle(foregroundColor)
            .background(ButtonGradientBackground(cornerRadius: cornerRadius, prominence: prominence, isPressed: configuration.isPressed))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(strokeColor, lineWidth: 1)
            }
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.spring(response: 0.18, dampingFraction: 0.82), value: configuration.isPressed)
    }

    private var foregroundColor: Color {
        switch prominence {
        case .primary:
            return theme.color(.canvas)
        case .standard, .quiet:
            return theme.chromeForegroundColor
        }
    }

    private var strokeColor: Color {
        switch prominence {
        case .primary:
            return Color.white.opacity(0.34)
        case .standard:
            return theme.color(.border).opacity(0.54)
        case .quiet:
            return theme.color(.border).opacity(0.36)
        }
    }
}

private struct BrowserContent: View {
    @EnvironmentObject private var model: BrowserViewModel
    @EnvironmentObject private var theme: BrowserTheme

    var body: some View {
        ZStack {
            if let tab = model.selectedTab {
                if shouldUseNeutralStartBackdrop(for: tab) {
                    Color(red: 0.027, green: 0.035, blue: 0.051)
                } else if shouldShowPageBackdrop(for: tab) {
                    theme.color(.canvas)
                        .opacity(theme.isUserBackgroundEnabled && theme.hasUserBackground ? 0.18 : 1)
                }

                BrowserWebView(tab: tab)
                    .id(tab.id)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .ignoresSafeArea()
                    .overlay(alignment: .top) {
                        LoadingProgress(tab: tab)
                    }
            }
        }
        .ignoresSafeArea()
    }

    private func shouldShowPageBackdrop(for tab: BrowserTab) -> Bool {
        BrowserTab.isStartPageURL(tab.url) == false
    }

    private func shouldUseNeutralStartBackdrop(for tab: BrowserTab) -> Bool {
        BrowserTab.isStartPageURL(tab.url) && (theme.isUserBackgroundEnabled && theme.hasUserBackground) == false
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
    let containerWidth: CGFloat
    let experience: GlideDeviceExperience

    var body: some View {
        ZStack(alignment: edge == .left ? .leading : .trailing) {
            BrowserContent()

            if model.areSideTabsCollapsed == false {
                if experience == .phone {
                    Color.black.opacity(0.28)
                        .ignoresSafeArea()
                        .onTapGesture {
                            model.setTabBarCollapsed(true)
                        }
                        .transition(.opacity)
                }

                SideChrome(edge: edge)
                    .frame(width: sideWidth)
                    .transition(chromeTransition)

                if model.isChromeWidthResizeMode {
                    SideChromeWidthDragHandle(edge: edge, sideWidth: sideWidth, containerWidth: containerWidth, experience: experience)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: edge == .left ? .leading : .trailing)
                        .offset(x: edge == .left ? sideWidth - 16 : -(sideWidth - 16))
                        .transition(.opacity)
                }
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

private struct DesktopZenBrowserLayout: View {
    @EnvironmentObject private var model: BrowserViewModel
    let sideWidth: CGFloat
    let containerWidth: CGFloat
    let experience: GlideDeviceExperience
    @Binding var isChromeHovered: Bool
    @State private var chromeHideTask: Task<Void, Never>?

    private var isChromeVisible: Bool {
        isChromeHovered || model.isChromeWidthResizeMode
    }

    var body: some View {
        ZStack {
            BrowserContent()

            switch model.chromePlacement {
            case .left:
                sideReveal(edge: .left)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            case .right:
                sideReveal(edge: .right)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
            case .top:
                horizontalReveal(edge: .top)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            case .bottom:
                horizontalReveal(edge: .bottom)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            case .floating:
                floatingReveal()
            }
        }
        .animation(.spring(response: 0.24, dampingFraction: 0.88), value: isChromeVisible)
        .animation(.spring(response: 0.24, dampingFraction: 0.88), value: model.chromePlacement)
    }

    @ViewBuilder
    private func sideReveal(edge: SideChromeEdge) -> some View {
        if isChromeVisible {
            ZStack(alignment: edge == .left ? .leading : .trailing) {
                SideChrome(edge: edge)
                    .frame(width: sideWidth)
                    .onHover(perform: setChromeHovered)

                if model.isChromeWidthResizeMode {
                    SideChromeWidthDragHandle(edge: edge, sideWidth: sideWidth, containerWidth: containerWidth, experience: experience)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: edge == .left ? .leading : .trailing)
                        .offset(x: edge == .left ? sideWidth - 16 : -(sideWidth - 16))
                        .transition(.opacity)
                }
            }
            .frame(width: sideWidth)
            .frame(maxHeight: .infinity)
            .transition(sideTransition(for: edge))
        } else {
            DesktopZenHoverStrip(edge: edge == .left ? .left : .right)
                .frame(width: 28)
                .frame(maxHeight: .infinity)
                .onHover(perform: setChromeHovered)
                .transition(.opacity)
        }
    }

    @ViewBuilder
    private func horizontalReveal(edge: VerticalEdge) -> some View {
        if isChromeVisible {
            HorizontalChrome(edge: edge)
                .onHover(perform: setChromeHovered)
                .transition(.move(edge: edge == .top ? .top : .bottom).combined(with: .opacity))
        } else {
            DesktopZenHoverStrip(edge: edge == .top ? .top : .bottom)
                .frame(maxWidth: .infinity)
                .frame(height: 28)
                .onHover(perform: setChromeHovered)
                .transition(.opacity)
        }
    }

    @ViewBuilder
    private func floatingReveal() -> some View {
        if isChromeVisible {
            FloatingChrome(onHoverChanged: setChromeHovered)
                .transition(.move(edge: .bottom).combined(with: .opacity))
        } else {
            DesktopZenHoverStrip(edge: .bottom)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                .onHover(perform: setChromeHovered)
                .transition(.opacity)
        }
    }

    private func sideTransition(for edge: SideChromeEdge) -> AnyTransition {
        edge == .left
            ? .move(edge: .leading).combined(with: .opacity)
            : .move(edge: .trailing).combined(with: .opacity)
    }

    private func setChromeHovered(_ hovered: Bool) {
        chromeHideTask?.cancel()
        if hovered {
            updateChromeHovered(true)
            return
        }

        chromeHideTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 240_000_000)
            guard Task.isCancelled == false else { return }
            updateChromeHovered(false)
        }
    }

    private func updateChromeHovered(_ hovered: Bool) {
        guard isChromeHovered != hovered else { return }
        withAnimation(.spring(response: 0.24, dampingFraction: 0.88)) {
            isChromeHovered = hovered
        }
    }
}

private enum DesktopZenHoverEdge {
    case left
    case right
    case top
    case bottom

    var alignment: Alignment {
        switch self {
        case .left:
            return .leading
        case .right:
            return .trailing
        case .top:
            return .top
        case .bottom:
            return .bottom
        }
    }

    var isHorizontal: Bool {
        self == .top || self == .bottom
    }
}

private struct DesktopZenHoverStrip: View {
    @EnvironmentObject private var theme: BrowserTheme
    let edge: DesktopZenHoverEdge

    var body: some View {
        ZStack(alignment: edge.alignment) {
            Color.clear

            Capsule()
                .fill(theme.color(.accent).opacity(0.48))
                .frame(width: edge.isHorizontal ? 118 : 4, height: edge.isHorizontal ? 4 : 118)
                .shadow(color: theme.color(.accent).opacity(0.24), radius: 8)
                .padding(stripPadding)
        }
        .contentShape(Rectangle())
        .accessibilityLabel("Reveal desktop chrome")
    }

    private var stripPadding: EdgeInsets {
        switch edge {
        case .left:
            return EdgeInsets(top: 0, leading: 7, bottom: 0, trailing: 0)
        case .right:
            return EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 7)
        case .top:
            return EdgeInsets(top: 7, leading: 0, bottom: 0, trailing: 0)
        case .bottom:
            return EdgeInsets(top: 0, leading: 0, bottom: 7, trailing: 0)
        }
    }
}

private struct SideChromeWidthDragHandle: View {
    @EnvironmentObject private var model: BrowserViewModel
    @EnvironmentObject private var theme: BrowserTheme
    let edge: SideChromeEdge
    let sideWidth: CGFloat
    let containerWidth: CGFloat
    let experience: GlideDeviceExperience
    @State private var dragStartWidth: CGFloat?

    var body: some View {
        Capsule()
            .fill(.ultraThinMaterial)
            .overlay {
                Capsule()
                    .fill(theme.color(.accent).opacity(experience == .phone ? 0.18 : 0.36))
            }
            .overlay {
                Image(systemName: experience == .phone ? "arrow.left.and.right" : "line.3.horizontal")
                    .font(.system(size: 13, weight: .black))
                    .foregroundStyle(theme.color(.text))
                    .rotationEffect(experience == .phone ? .degrees(0) : .degrees(90))
            }
            .frame(width: 32, height: 92)
            .shadow(color: Color.black.opacity(0.28), radius: 12, y: 6)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        guard experience != .phone else { return }
                        let startWidth = dragStartWidth ?? sideWidth
                        dragStartWidth = startWidth
                        let proposedWidth = edge == .left
                            ? startWidth + value.translation.width
                            : startWidth - value.translation.width
                        model.updateSideChromeWidth(proposedWidth, containerWidth: containerWidth)
                    }
                    .onEnded { _ in
                        dragStartWidth = nil
                    }
            )
            .accessibilityLabel(experience == .phone ? "Phone chrome is full screen" : "Drag chrome width")
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

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 12) {
                    NewTabActions(layout: .sidebar)

                    TabBarStyleControl(compact: false)

                    if model.isPrivateModeEnabled == false {
                        EssentialsSection()
                    }

                    if model.isPrivateModeEnabled {
                        TabSection(title: "Private Mode", tabs: model.visiblePrivateTabs)
                    } else {
                        TabSection(title: "Tabs", tabs: model.visibleNormalTabs)

                        if model.visiblePrivateTabs.isEmpty == false {
                            TabSection(title: "Private", tabs: model.visiblePrivateTabs)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .frame(maxHeight: .infinity)

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
        Group {
            if edge == .top {
                TraditionalTopChrome()
            } else {
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

                            ForEach(model.visibleEssentials) { item in
                                EssentialPill(item: item, layout: .horizontal)
                            }

                            ForEach(model.chromeTabs) { tab in
                                TabPill(tab: tab, layout: .horizontal)
                            }
                        }
                        .padding(.horizontal, 2)
                    }
                }
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

private struct TraditionalTopChrome: View {
    @EnvironmentObject private var model: BrowserViewModel
    @EnvironmentObject private var theme: BrowserTheme

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                BrandMark()

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(model.chromeTabs) { tab in
                            TraditionalTopTab(tab: tab)
                        }
                    }
                    .padding(.horizontal, 2)
                }

                Button {
                    model.openNewTabAndSearch()
                } label: {
                    BrowserIcon(slot: .newTab, systemName: "plus", size: 18, weight: .black)
                        .frame(width: 42, height: 38)
                        .foregroundStyle(theme.color(.canvas))
                        .background(ButtonGradientBackground(cornerRadius: 8, prominence: .primary))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("New Tab")

                if model.isPrivateModeEnabled == false && model.isInMoreMenu(.tabFolders) == false {
                    TabFoldersToolbarButton()
                }

                TabBarStyleControl(compact: true)
            }

            HStack(spacing: 10) {
                SearchTrigger(style: .bar)
                ChromeFooter()
            }
        }
    }
}

private struct TraditionalTopTab: View {
    @EnvironmentObject private var model: BrowserViewModel
    @EnvironmentObject private var theme: BrowserTheme
    @ObservedObject var tab: BrowserTab
    @State private var isTargeted = false

    private var isSelected: Bool {
        model.selectedTabID == tab.id
    }

    var body: some View {
        HStack(spacing: 8) {
            Button {
                model.select(tab)
            } label: {
                HStack(spacing: 8) {
                    BrowserIcon(slot: tab.isPrivate ? .privateTab : .normalTab, systemName: tab.isPrivate ? "theatermasks" : "globe", size: 12, weight: .bold)
                        .frame(width: 22, height: 22)
                        .foregroundStyle(tab.isPrivate ? theme.color(.text) : theme.color(.accent))

                    VStack(alignment: .leading, spacing: 2) {
                        PrivateRedactedText(text: tab.title, isPrivate: tab.isPrivate, minWidth: 72, maxWidth: 118, height: 10)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(theme.color(.text))
                            .lineLimit(1)

                        if tab.usesDevWebKitProfile {
                            Label("Dev WebKit", systemImage: "hammer")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(theme.color(.createTab))
                                .lineLimit(1)
                        } else if let folderName = model.folderName(for: tab) {
                            Label(folderName, systemImage: "folder")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(theme.color(.mutedText))
                                .lineLimit(1)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button {
                model.close(tab)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .frame(width: 22, height: 22)
                    .foregroundStyle(theme.color(.mutedText))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close tab")
        }
        .padding(.leading, 10)
        .padding(.trailing, 6)
        .frame(width: 182, height: 40)
        .background(topTabBackground)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(isSelected ? theme.color(.createTab) : Color.clear)
                .frame(height: 2)
                .padding(.horizontal, 10)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(isTargeted ? theme.color(.createTab).opacity(0.95) : theme.color(.border).opacity(isSelected ? 0.72 : 0.38), lineWidth: 1)
        }
        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .draggable(tab.id.uuidString)
        .dropDestination(for: String.self, action: { items, _ in
            guard let rawID = items.first,
                  let sourceID = UUID(uuidString: rawID) else { return false }
            model.moveTab(withID: sourceID, before: tab.id)
            return true
        }, isTargeted: { targeted in
            isTargeted = targeted
        })
        .contextMenu {
            if tab.isPrivate == false {
                Button {
                    model.addEssential(from: tab)
                } label: {
                    Label("Add to Essentials", systemImage: "sparkle")
                }

                if model.tabFolders.isEmpty == false {
                    Menu {
                        ForEach(model.tabFolders) { folder in
                            Button {
                                model.assign(tab, to: folder)
                            } label: {
                                Label(folder.name, systemImage: "folder")
                            }
                        }
                    } label: {
                        Label("Move to Folder", systemImage: "folder")
                    }
                }

                Button {
                    model.createFolder(from: tab)
                } label: {
                    Label("New Folder from Tab", systemImage: "folder.badge.plus")
                }

                if tab.folderID != nil {
                    Button {
                        model.removeFromFolder(tab)
                    } label: {
                        Label("Remove from Folder", systemImage: "folder.badge.minus")
                    }
                }
            }

            Button(role: .destructive) {
                model.close(tab)
            } label: {
                Label("Close Tab", systemImage: "xmark")
            }
        }
    }

    private var topTabBackground: some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(.ultraThinMaterial)
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill((isSelected ? theme.color(.field) : theme.color(.surface)).opacity(isSelected ? 0.92 : 0.54))
            }
    }
}

private struct FloatingChrome: View {
    @EnvironmentObject private var model: BrowserViewModel
    @EnvironmentObject private var theme: BrowserTheme
    var onHoverChanged: ((Bool) -> Void)? = nil

    var body: some View {
        VStack {
            Spacer()

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ChromeButton(slot: .search, symbol: "magnifyingglass", label: "Search") {
                        model.openFloatingSearch()
                    }

                    if model.isInMoreMenu(.back) == false {
                        ChromeButton(slot: .back, symbol: "chevron.left", label: "Back") {
                            model.goBack()
                        }
                        .disabled(model.selectedTab?.canGoBack != true)
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

                    if model.isPrivateModeEnabled == false && model.isInMoreMenu(.tabFolders) == false {
                        TabFoldersToolbarButton()
                    }

                    if model.isInMoreMenu(.closeAllTabs) == false {
                        ChromeButton(slot: .closeAllTabs, symbol: "xmark.square", label: "Close All Tabs") {
                            model.requestCloseAllTabs()
                        }
                    }

                    if model.isPrivateModeEnabled == false && model.isInMoreMenu(.containedTabs) == false {
                        ChromeButton(slot: .containedTabs, symbol: "rectangle.on.rectangle", label: "Contained Tabs") {
                            model.showContainedTabs()
                        }
                    }

                    if model.isInMoreMenu(.reload) == false {
                        ChromeButton(slot: model.selectedTab?.isLoading == true ? nil : .reload, symbol: model.selectedTab?.isLoading == true ? "xmark" : "arrow.clockwise", label: "Reload") {
                            model.reloadOrStop()
                        }
                    }

                    if model.isInMoreMenu(.websiteMode) == false {
                        WebsiteModeButton()
                    }

                    if model.isPrivateModeEnabled == false && model.isInMoreMenu(.vpnCountry) == false {
                        VPNCountryToolbarButton()
                    }

                    if model.isInMoreMenu(.passwordManager) == false {
                        PasswordManagerToolbarButton()
                    }

                    if model.isPrivateModeEnabled == false && model.isInMoreMenu(.downloadCurrent) == false {
                        ChromeButton(slot: .downloadCurrent, symbol: "arrow.down.doc", label: "Download Current Page") {
                            model.downloadSelectedTab()
                        }
                    }

                    if model.isPrivateModeEnabled == false && model.isInMoreMenu(.history) == false {
                        ChromeButton(slot: .history, symbol: "clock.arrow.circlepath", label: "History") {
                            model.isHistoryPresented = true
                        }
                    }

                    if model.isPrivateModeEnabled == false && model.isInMoreMenu(.downloads) == false {
                        ChromeButton(slot: .downloads, symbol: "arrow.down.circle", label: "Downloads") {
                            model.isDownloadsPresented = true
                        }
                    }

                    if model.isInMoreMenu(.browserMusic) == false {
                        BrowserMusicToolbarButton()
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
            .onHover { isHovered in
                onHoverChanged?(isHovered)
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
                VStack(alignment: .leading, spacing: 1) {
                    Text("Glide")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(theme.chromeForegroundColor)
                        .lineLimit(1)

                    if model.isPrivateModeEnabled {
                        Text("Private Mode")
                            .font(.caption2.weight(.black))
                            .foregroundStyle(theme.color(.privateAccent))
                            .lineLimit(1)
                    }
                }
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
                if model.isInMoreMenu(.back) == false {
                    ChromeButton(slot: .back, symbol: "chevron.left", label: "Back") {
                        model.goBack()
                    }
                    .disabled(model.selectedTab?.canGoBack != true)
                }

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

                if model.isInMoreMenu(.websiteMode) == false {
                    WebsiteModeButton()
                }

                if model.isPrivateModeEnabled == false && model.isInMoreMenu(.vpnCountry) == false {
                    VPNCountryToolbarButton()
                }

                if model.isInMoreMenu(.passwordManager) == false {
                    PasswordManagerToolbarButton()
                }

                if model.isPrivateModeEnabled == false && model.isInMoreMenu(.history) == false {
                    ChromeButton(slot: .history, symbol: "clock.arrow.circlepath", label: "History") {
                        model.isHistoryPresented = true
                    }
                }

                if model.isInMoreMenu(.tabFinder) == false {
                    ChromeButton(slot: .tabFinder, symbol: "square.grid.2x2", label: "Tab Finder") {
                        model.isTabFinderPresented = true
                    }
                }

                if model.chromePlacement != .top && model.isPrivateModeEnabled == false && model.isInMoreMenu(.tabFolders) == false {
                    TabFoldersToolbarButton()
                }

                if model.isInMoreMenu(.closeAllTabs) == false {
                    ChromeButton(slot: .closeAllTabs, symbol: "xmark.square", label: "Close All Tabs") {
                        model.requestCloseAllTabs()
                    }
                }

                if model.isPrivateModeEnabled == false && model.isInMoreMenu(.downloadCurrent) == false {
                    ChromeButton(slot: .downloadCurrent, symbol: "arrow.down.doc", label: "Download Current Page") {
                        model.downloadSelectedTab()
                    }
                }

                if model.isPrivateModeEnabled == false && model.isInMoreMenu(.downloads) == false {
                    ChromeButton(slot: .downloads, symbol: "arrow.down.circle", label: "Downloads") {
                        model.isDownloadsPresented = true
                    }
                }

                if model.isPrivateModeEnabled == false && model.isInMoreMenu(.containedTabs) == false {
                    ChromeButton(slot: .containedTabs, symbol: "rectangle.on.rectangle", label: "Contained Tabs") {
                        model.showContainedTabs()
                    }
                }

                if model.isInMoreMenu(.browserMusic) == false {
                    BrowserMusicToolbarButton()
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
            .opacity(materialOpacity)
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(theme.color(.chrome).opacity(chromeOpacity))
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color.black.opacity(theme.isUserBackgroundEnabled && theme.hasUserBackground ? 0.34 * materialOpacity : 0))
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
                    .opacity(materialOpacity)
            }
    }

    private var chromeOpacity: Double {
        theme.tabBarOpacity
    }

    private var materialOpacity: Double {
        theme.isTabBarTransparencyEnabled ? max(0.0, 1.0 - theme.tabBarTransparency) : 1.0
    }
}

private struct FloatingChromeBackground: View {
    @EnvironmentObject private var theme: BrowserTheme

    var body: some View {
        Capsule()
            .fill(.ultraThinMaterial)
            .opacity(materialOpacity)
            .overlay {
                Capsule()
                    .fill(theme.color(.chrome).opacity(chromeOpacity))
            }
            .overlay {
                Capsule()
                    .fill(Color.black.opacity(theme.isUserBackgroundEnabled && theme.hasUserBackground ? 0.34 * materialOpacity : 0))
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
                    .opacity(materialOpacity)
            }
    }

    private var chromeOpacity: Double {
        theme.tabBarOpacity
    }

    private var materialOpacity: Double {
        theme.isTabBarTransparencyEnabled ? max(0.0, 1.0 - theme.tabBarTransparency) : 1.0
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
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                theme.color(.accent).opacity(0.20),
                            ] + theme.gradientColors(for: .field).map { $0.opacity(max(controlOpacity, 0.46)) } + [
                                theme.color(.field).opacity(controlOpacity)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
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

                Slider(value: $theme.tabBarTransparency, in: 0...1.0)
                    .disabled(theme.isTabBarTransparencyEnabled == false)

                HStack(spacing: 8) {
                    Button("Solid") {
                        theme.isTabBarTransparencyEnabled = false
                    }
                    .buttonStyle(GlideGradientButtonStyle(prominence: .standard))

                    Button("Clear") {
                        theme.isTabBarTransparencyEnabled = true
                        theme.tabBarTransparency = 1.0
                    }
                    .buttonStyle(GlideGradientButtonStyle(prominence: .primary))
                }

                Divider()

                Toggle("Background", isOn: $theme.isUserBackgroundEnabled)
                    .disabled(theme.hasUserBackground == false)

                if theme.isUserBackgroundEnabled,
                   let image = theme.userBackgroundImage {
                    ZStack(alignment: .bottomLeading) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                        if let duration = theme.userBackgroundVideoDurationLabel {
                            Label(duration, systemImage: "play.rectangle.fill")
                                .font(.caption2.weight(.bold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 5)
                                .background(.ultraThinMaterial, in: Capsule())
                                .padding(8)
                        }
                    }
                    .frame(height: 74)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }

                if theme.backgroundImportMessage.isEmpty == false {
                    Text(theme.backgroundImportMessage)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(theme.chromeSecondaryForegroundColor)
                }

                HStack(spacing: 8) {
                    Button("Files") {
                        isBackgroundImporterPresented = true
                    }
                    .buttonStyle(GlideGradientButtonStyle(prominence: .primary))

                    BackgroundPhotoPickerButton(title: "Photos")
                        .buttonStyle(GlideGradientButtonStyle(prominence: .standard))

                    Button("Remove") {
                        theme.clearUserBackground()
                    }
                    .buttonStyle(GlideGradientButtonStyle(prominence: .standard))
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
            allowedContentTypes: [.image, .movie, .video],
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
        PhotosPicker(selection: $selectedPhoto, matching: .any(of: [.images, .videos]), photoLibrary: .shared()) {
            Label(title, systemImage: "photo.stack")
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
                let contentType = item.supportedContentTypes.first
                if item.supportedContentTypes.contains(where: { $0.conforms(to: .movie) || $0.conforms(to: .video) }) {
                    theme.setUserBackground(fromVideoData: data, contentTypeIdentifier: contentType?.identifier)
                } else {
                    theme.setUserBackground(fromImageData: data)
                }
                selectedPhoto = nil
            }
        }
    }
}

private enum SearchTriggerStyle {
    case sidebar
    case bar
}

private struct PrivateRedactedText: View {
    let text: String
    let isPrivate: Bool
    var minWidth: CGFloat = 58
    var maxWidth: CGFloat = 160
    var height: CGFloat = 11

    var body: some View {
        if isPrivate {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(Color.black)
                .frame(width: redactedWidth, height: height)
                .overlay {
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .stroke(Color.black.opacity(0.95), lineWidth: 1)
                }
                .accessibilityLabel("Private tab title hidden")
        } else {
            Text(text)
        }
    }

    private var redactedWidth: CGFloat {
        min(max(CGFloat(max(text.count, 7)) * 7.0, minWidth), maxWidth)
    }
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
                    PrivateRedactedText(
                        text: displayTitle,
                        isPrivate: model.selectedTab?.isPrivate == true,
                        minWidth: 74,
                        maxWidth: style == .sidebar ? 150 : 230,
                        height: 12
                    )
                        .font(.system(size: style == .sidebar ? 13 : 15, weight: .semibold))
                        .foregroundStyle(theme.chromeForegroundColor)
                        .lineLimit(1)

                    if style == .sidebar {
                        Text(searchSubtitle)
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

    private var searchSubtitle: String {
        model.isPrivateModeEnabled ? "Private Mode" : "Search or enter address"
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
    let autoCompactOnSubmit: Bool

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
                model.submitAddress(autoCompactChrome: autoCompactOnSubmit)
            }
            .frame(height: 34)

            Button {
                model.submitAddress(autoCompactChrome: autoCompactOnSubmit)
            } label: {
                BrowserIcon(slot: .go, systemName: "arrow.up.circle.fill", size: 25, weight: .semibold)
                    .frame(width: 30, height: 30)
                    .foregroundStyle(theme.color(.createTab))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Go")

            if model.selectedTab?.isPrivate == true {
                Text(model.isPrivateModeEnabled ? "Private Mode" : "Private")
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
        textField.keyboardType = .webSearch
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
    let experience: GlideDeviceExperience

    var body: some View {
        ZStack(alignment: .top) {
            Color.black.opacity(0.32)
                .ignoresSafeArea()
                .onTapGesture {
                    model.isFloatingSearchPresented = false
                }

            VStack(spacing: 12) {
                AddressField(
                    style: .floating,
                    focusOnAppear: true,
                    autoCompactOnSubmit: shouldAutoCompactAfterSubmit
                )
                SearchResultsList(
                    query: model.floatingSearchText,
                    autoCompactOnOpen: shouldAutoCompactAfterSubmit
                )

                if let tab = model.selectedTab {
                    HStack(spacing: 8) {
                        Image(systemName: tab.isPrivate ? "theatermasks" : "globe")
                        PrivateRedactedText(text: tab.title, isPrivate: tab.isPrivate, minWidth: 78, maxWidth: 220, height: 10)
                            .lineLimit(1)
                        Spacer()
                        Text(model.isPrivateModeEnabled ? "Private Mode" : (BrowserTab.isStartPageURL(tab.url) ? "Start Page" : (tab.url?.host ?? model.searchEngine.title)))
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

    private var shouldAutoCompactAfterSubmit: Bool {
        experience == .phone && model.autoCompactAfterSearchOnPhone
    }
}

private struct SearchResultsList: View {
    @EnvironmentObject private var model: BrowserViewModel
    @EnvironmentObject private var theme: BrowserTheme
    let query: String
    let autoCompactOnOpen: Bool

    var body: some View {
        let results = model.searchResults(for: query)

        if results.isEmpty == false {
            VStack(spacing: 0) {
                ForEach(Array(results.enumerated()), id: \.element.id) { index, result in
                    SearchResultRow(result: result, autoCompactOnOpen: autoCompactOnOpen)

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

private struct MovableTopSearchBar: View {
    @EnvironmentObject private var model: BrowserViewModel
    let containerSize: CGSize
    let topInset: CGFloat
    let bottomInset: CGFloat
    let experience: GlideDeviceExperience

    var body: some View {
        let metrics = layoutMetrics

        BrowserTopSearchBar(
            isMoving: model.isTopSearchBarMoveMode,
            autoCompactOnSubmit: experience == .phone && model.autoCompactAfterSearchOnPhone
        )
            .frame(width: metrics.width, height: metrics.height)
            .position(
                x: position(from: model.displayedTopSearchBarX, min: metrics.minX, max: metrics.maxX),
                y: position(from: model.displayedTopSearchBarY, min: metrics.minY, max: metrics.maxY)
            )
            .overlay {
                if model.isTopSearchBarMoveMode {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.clear)
                        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .gesture(
                            DragGesture(minimumDistance: 0, coordinateSpace: .named("browserShell"))
                                .onChanged { value in
                                    updateDraftPosition(value.location, metrics: metrics)
                                }
                        )
                }
            }
    }

    private var layoutMetrics: (width: CGFloat, height: CGFloat, minX: CGFloat, maxX: CGFloat, minY: CGFloat, maxY: CGFloat) {
        let margin: CGFloat = 16
        let height: CGFloat = 50
        let width = min(760, max(1, containerSize.width - (margin * 2)))
        let minX = margin + (width / 2)
        let maxX = max(minX, containerSize.width - margin - (width / 2))
        let minY = topInset + (height / 2)
        let maxY = max(minY, containerSize.height - bottomInset - (height / 2))
        return (width, height, minX, maxX, minY, maxY)
    }

    private func position(from normalizedValue: Double, min minimum: CGFloat, max maximum: CGFloat) -> CGFloat {
        minimum + CGFloat(min(max(normalizedValue, 0), 1)) * (maximum - minimum)
    }

    private func normalized(_ value: CGFloat, min minimum: CGFloat, max maximum: CGFloat) -> Double {
        guard maximum > minimum else { return 0.5 }
        return Double(min(max((value - minimum) / (maximum - minimum), 0), 1))
    }

    private func updateDraftPosition(
        _ location: CGPoint,
        metrics: (width: CGFloat, height: CGFloat, minX: CGFloat, maxX: CGFloat, minY: CGFloat, maxY: CGFloat)
    ) {
        model.updateTopSearchBarDraft(
            x: normalized(location.x, min: metrics.minX, max: metrics.maxX),
            y: normalized(location.y, min: metrics.minY, max: metrics.maxY)
        )
    }
}

private struct TopSearchBarMoveControls: View {
    @EnvironmentObject private var model: BrowserViewModel
    @EnvironmentObject private var theme: BrowserTheme

    var body: some View {
        HStack(spacing: 8) {
            Button {
                model.cancelTopSearchBarMove()
            } label: {
                Label("Cancel", systemImage: "xmark")
            }
            .buttonStyle(GlideGradientButtonStyle(prominence: .standard))

            Button {
                model.resetTopSearchBarPosition()
            } label: {
                Image(systemName: "arrow.counterclockwise")
                    .frame(width: 20, height: 20)
            }
            .buttonStyle(GlideGradientButtonStyle(prominence: .standard))
            .accessibilityLabel("Reset top search bar position")

            Button {
                model.saveTopSearchBarMove()
            } label: {
                Label("Save", systemImage: "checkmark")
            }
            .buttonStyle(GlideGradientButtonStyle(prominence: .primary))
        }
        .font(.system(size: 14, weight: .bold))
        .padding(10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(theme.color(.border).opacity(0.7), lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.3), radius: 16, y: 8)
    }
}

private struct ChromeWidthResizeControls: View {
    @EnvironmentObject private var model: BrowserViewModel
    @EnvironmentObject private var theme: BrowserTheme
    let experience: GlideDeviceExperience

    var body: some View {
        HStack(spacing: 8) {
            Label(experience == .phone ? "Phone chrome is full screen" : "Drag the side edge", systemImage: experience == .phone ? "iphone" : "arrow.left.and.right")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(theme.color(.mutedText))

            Button {
                model.resetChromeWidth()
            } label: {
                Image(systemName: "arrow.counterclockwise")
                    .frame(width: 20, height: 20)
            }
            .buttonStyle(GlideGradientButtonStyle(prominence: .standard))
            .disabled(experience == .phone)
            .accessibilityLabel("Reset chrome width")

            Button {
                model.endChromeWidthResize()
            } label: {
                Label("Done", systemImage: "checkmark")
            }
            .buttonStyle(GlideGradientButtonStyle(prominence: .primary))
        }
        .font(.system(size: 14, weight: .bold))
        .padding(10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(theme.color(.border).opacity(0.7), lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.3), radius: 16, y: 8)
    }
}

private struct PageControlsMoveControls: View {
    @EnvironmentObject private var model: BrowserViewModel
    @EnvironmentObject private var theme: BrowserTheme

    var body: some View {
        HStack(spacing: 8) {
            Label("Drag the reveal arrow", systemImage: "arrow.up.left.and.arrow.down.right")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(theme.color(.mutedText))

            Button {
                model.resetPageControlsPosition()
            } label: {
                Image(systemName: "arrow.counterclockwise")
                    .frame(width: 20, height: 20)
            }
            .buttonStyle(GlideGradientButtonStyle(prominence: .standard))
            .accessibilityLabel("Reset reveal arrow position")

            Button {
                model.endPageControlsMove()
            } label: {
                Label("Done", systemImage: "checkmark")
            }
            .buttonStyle(GlideGradientButtonStyle(prominence: .primary))
        }
        .font(.system(size: 14, weight: .bold))
        .padding(10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(theme.color(.border).opacity(0.7), lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.3), radius: 16, y: 8)
    }
}

private struct BrowserTopSearchBar: View {
    @EnvironmentObject private var model: BrowserViewModel
    @EnvironmentObject private var theme: BrowserTheme
    @State private var shouldSelectText = false
    let isMoving: Bool
    let autoCompactOnSubmit: Bool

    init(isMoving: Bool = false, autoCompactOnSubmit: Bool = false) {
        self.isMoving = isMoving
        self.autoCompactOnSubmit = autoCompactOnSubmit
    }

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
                model.submitAddress(autoCompactChrome: autoCompactOnSubmit)
            }
            .frame(height: 32)

            Button {
                model.submitAddress(autoCompactChrome: autoCompactOnSubmit)
            } label: {
                BrowserIcon(slot: .go, systemName: "arrow.up.circle.fill", size: 24, weight: .semibold)
                    .frame(width: 28, height: 28)
                    .foregroundStyle(theme.color(.createTab))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Go")

            if model.isPrivateModeEnabled {
                Text("Private Mode")
                    .font(.caption2.weight(.black))
                    .foregroundStyle(theme.color(.text))
                    .lineLimit(1)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background(theme.color(.privateAccent).opacity(0.72), in: Capsule())
            }

            TopSearchOptionsMenu()
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
                .stroke(
                    isMoving ? theme.color(.createTab).opacity(0.95) : theme.color(.border).opacity(0.82),
                    lineWidth: isMoving ? 2 : 1
                )
        }
        .scaleEffect(isMoving ? 1.02 : 1)
        .shadow(color: Color.black.opacity(0.28), radius: 18, y: 10)
    }

    private var addressBinding: Binding<String> {
        Binding(
            get: { model.selectedTab?.addressText ?? "" },
            set: { model.selectedTab?.addressText = $0 }
        )
    }
}

private struct TopSearchOptionsMenu: View {
    @EnvironmentObject private var model: BrowserViewModel
    @EnvironmentObject private var theme: BrowserTheme

    var body: some View {
        Menu {
            Button {
                model.openFloatingSearch()
            } label: {
                Label("Search Overlay", systemImage: "magnifyingglass")
            }

            Button {
                model.openNewTabAndSearch(private: model.isPrivateModeEnabled)
            } label: {
                Label(model.isPrivateModeEnabled ? "New Private Tab" : "New Tab", systemImage: model.isPrivateModeEnabled ? "theatermasks" : "plus")
            }

            Divider()

            if BrowserViewModel.supportsDesktopZenMode {
                Button {
                    model.setDesktopZenModeEnabled(!model.isDesktopZenModeEnabled)
                } label: {
                    Label(model.isDesktopZenModeEnabled ? "Exit Desktop Zen Mode" : "Enter Desktop Zen Mode", systemImage: "macwindow")
                }
            }

            Picker("Search Bar Position", selection: topSearchBarPlacementBinding) {
                ForEach(BrowserTopSearchBarPlacement.allCases) { placement in
                    Label(placement.title, systemImage: placement.symbolName)
                        .tag(placement)
                }
            }

            Button {
                model.beginTopSearchBarMove()
            } label: {
                Label("Move Search Bar", systemImage: "hand.draw")
            }

            Divider()

            Menu {
                PlacementMenuContent()
            } label: {
                Label("Chrome Placement", systemImage: model.chromePlacement.symbolName)
            }

            Button {
                model.toggleCompactMode()
            } label: {
                Label(model.isCompactModeActive ? "Reveal Chrome" : "Compact Mode", systemImage: model.isCompactModeActive ? "arrow.up.left.and.arrow.down.right" : "arrow.down.right.and.arrow.up.left")
            }

            Button {
                model.isSettingsPresented = true
            } label: {
                Label("Settings", systemImage: "gearshape")
            }
        } label: {
            BrowserIcon(slot: .more, systemName: "ellipsis", size: 17, weight: .black)
                .frame(width: 34, height: 34)
                .foregroundStyle(theme.color(.text))
                .background(ControlGlassBackground(cornerRadius: 8))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(theme.color(.border).opacity(0.58), lineWidth: 1)
                }
        }
        .accessibilityLabel("Top search options")
    }

    private var topSearchBarPlacementBinding: Binding<BrowserTopSearchBarPlacement> {
        Binding(
            get: { model.topSearchBarPlacement },
            set: { model.setTopSearchBarPlacement($0) }
        )
    }
}

private struct SearchResultRow: View {
    @EnvironmentObject private var model: BrowserViewModel
    @EnvironmentObject private var theme: BrowserTheme
    let result: BrowserSearchResult
    let autoCompactOnOpen: Bool

    var body: some View {
        Button {
            model.openSearchResult(result, autoCompactChrome: autoCompactOnOpen)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: result.symbolName)
                    .font(.system(size: 15, weight: .semibold))
                    .frame(width: 28, height: 28)
                    .foregroundStyle(theme.color(.accent))
                    .background(ButtonGradientBackground(cornerRadius: 7, prominence: .quiet))

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
    @EnvironmentObject private var model: BrowserViewModel
    @EnvironmentObject private var theme: BrowserTheme

    var body: some View {
        HStack(spacing: 8) {
            PageControlsCollapseButton()
            if model.arePageControlsCollapsed == false {
                ShieldQuickButton()
                FavoriteSettingsButton()
                if model.isInMoreMenu(.compact) == false {
                    CompactChromeButton()
                }
                MoreTabButton()
            }
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

private struct MovableBrowserPageControls: View {
    @EnvironmentObject private var model: BrowserViewModel
    let containerSize: CGSize
    let defaultLeading: CGFloat
    let defaultTop: CGFloat
    @State private var dragStartOffset: CGPoint?

    var body: some View {
        BrowserPageControls()
            .padding(.leading, defaultLeading)
            .padding(.top, defaultTop)
            .offset(x: offsetX, y: offsetY)
            .overlay {
                if model.isPageControlsMoveMode {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.clear)
                        .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .gesture(moveGesture)
                }
            }
    }

    private var offsetX: CGFloat {
        CGFloat(model.pageControlsOffsetX) * horizontalRange
    }

    private var offsetY: CGFloat {
        CGFloat(model.pageControlsOffsetY) * verticalRange
    }

    private var horizontalRange: CGFloat {
        max(containerSize.width - 230, 1)
    }

    private var verticalRange: CGFloat {
        max(containerSize.height - 96, 1)
    }

    private var moveGesture: some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named("browserShell"))
            .onChanged { value in
                let start = dragStartOffset ?? CGPoint(x: CGFloat(model.pageControlsOffsetX), y: CGFloat(model.pageControlsOffsetY))
                dragStartOffset = start
                model.updatePageControlsOffset(
                    x: Double(start.x) + Double(value.translation.width / horizontalRange),
                    y: Double(start.y) + Double(value.translation.height / verticalRange)
                )
            }
            .onEnded { _ in
                dragStartOffset = nil
            }
    }
}

private struct FavoriteSettingsButton: View {
    @EnvironmentObject private var model: BrowserViewModel
    @EnvironmentObject private var theme: BrowserTheme

    var body: some View {
        Button {
            model.isSettingsPresented = true
        } label: {
            Image(systemName: "star.circle.fill")
                .font(.system(size: 17, weight: .black))
                .frame(width: 38, height: 38)
                .foregroundStyle(theme.color(.accent))
                .background(ControlGlassBackground(cornerRadius: 8))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(theme.color(.accent).opacity(0.62), lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Favorite settings")
    }
}

private struct PageControlsCollapseButton: View {
    @EnvironmentObject private var model: BrowserViewModel
    @EnvironmentObject private var theme: BrowserTheme

    var body: some View {
        Button {
            model.togglePageControlsCollapsed()
        } label: {
            Image(systemName: model.arePageControlsCollapsed ? "chevron.left" : "chevron.right")
                .font(.system(size: 15, weight: .black))
                .frame(width: 34, height: 38)
                .foregroundStyle(theme.color(.text))
                .background(ControlGlassBackground(cornerRadius: 8))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(theme.color(.border).opacity(0.58), lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(model.arePageControlsCollapsed ? "Show page controls" : "Hide page controls")
    }
}

private struct CompactChromeButton: View {
    @EnvironmentObject private var model: BrowserViewModel
    @EnvironmentObject private var theme: BrowserTheme

    private var symbolName: String {
        model.isCompactModeActive ? "arrow.up.left.and.arrow.down.right" : model.customIconName(for: .compact, fallback: "arrow.down.right.and.arrow.up.left")
    }

    var body: some View {
        Button {
            model.toggleCompactMode()
        } label: {
            BrowserIcon(slot: .compact, systemName: symbolName, size: 15, weight: .bold)
                .frame(width: 38, height: 38)
                .foregroundStyle(theme.color(.text))
                .background(ControlGlassBackground(cornerRadius: 8))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(theme.color(.accent).opacity(model.isCompactModeActive ? 0.78 : 0.48), lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(model.isCompactModeActive ? "Reveal chrome" : "Compact mode")
    }
}

private struct ShieldQuickButton: View {
    @EnvironmentObject private var model: BrowserViewModel
    @EnvironmentObject private var theme: BrowserTheme

    var body: some View {
        Menu {
            Button {
                model.enableGlideMaxProtection()
            } label: {
                Label("Glide Shields Max", systemImage: "shield.lefthalf.filled")
            }

            Button {
                model.setAdBlockerEnabled(!model.isAdBlockerEnabled)
            } label: {
                Label(model.isAdBlockerEnabled ? "Turn Shields Off" : "Turn Shields On", systemImage: model.isAdBlockerEnabled ? "shield.slash" : "shield")
            }

            Button {
                model.trackerBlockingLevel = .aggressive
            } label: {
                Label("Aggressive Blocking", systemImage: "bolt.shield")
            }

            Button {
                model.enableGlideGhostMode()
            } label: {
                Label("Ghost Mode", systemImage: "eye.slash")
            }

            Toggle("Block Scripts", isOn: $model.isScriptBlockingEnabled)
            Toggle("Fingerprint Protection", isOn: $model.isFingerprintProtectionEnabled)
            Toggle("Protect WebRTC IP", isOn: $model.isWebRTCProtectionEnabled)

            Button(role: .destructive) {
                model.clearPrivateBrowsingData()
            } label: {
                Label("Clear Private Data", systemImage: "trash")
            }

            Button {
                model.isSettingsPresented = true
            } label: {
                Label("Shield Settings", systemImage: "slider.horizontal.3")
            }
        } label: {
            BrowserIcon(
                slot: nil,
                systemName: model.isAdBlockerEnabled ? "shield.checkered" : "shield.slash",
                size: 15,
                weight: .bold
            )
            .frame(width: 38, height: 38)
            .foregroundStyle(model.isAdBlockerEnabled ? theme.color(.createTab) : theme.color(.mutedText))
            .background(ControlGlassBackground(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke((model.isAdBlockerEnabled ? theme.color(.createTab) : theme.color(.border)).opacity(0.7), lineWidth: 1)
            }
        }
        .accessibilityLabel(model.isAdBlockerEnabled ? "Glide Shields active" : "Glide Shields off")
    }
}

private struct TabFoldersToolbarButton: View {
    @EnvironmentObject private var model: BrowserViewModel

    var body: some View {
        ChromeButton(slot: .tabFolders, symbol: "folder", label: "Tab Folders") {
            model.isTabFoldersPresented = true
        }
    }
}

private struct BrowserMusicToolbarButton: View {
    @EnvironmentObject private var model: BrowserViewModel

    var body: some View {
        ChromeButton(
            slot: .browserMusic,
            symbol: model.isBrowserMusicEnabled ? "pause.fill" : "music.note",
            label: model.isBrowserMusicEnabled ? "Pause Browser Music" : "Play Browser Music"
        ) {
            model.toggleBrowserMusic()
        }
        .accessibilityValue(model.selectedBrowserMusicTitle)
    }
}

private struct WebsiteModeButton: View {
    @EnvironmentObject private var model: BrowserViewModel
    @EnvironmentObject private var theme: BrowserTheme

    var body: some View {
        Menu {
            ForEach(BrowserWebsiteDisplayMode.allCases) { mode in
                Button {
                    model.setWebsiteDisplayMode(mode)
                } label: {
                    Label(mode.title, systemImage: mode.symbolName)
                }
            }
        } label: {
            BrowserIcon(
                slot: .websiteMode,
                systemName: model.websiteDisplayMode.symbolName,
                size: 15,
                weight: .semibold
            )
            .frame(width: 36, height: 36)
            .foregroundStyle(theme.chromeForegroundColor)
            .background(ControlGlassBackground(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(theme.color(.accent).opacity(model.websiteDisplayMode == .automatic ? 0.4 : 0.78), lineWidth: 1)
            }
        }
        .accessibilityLabel("Website mode")
        .accessibilityValue(model.websiteDisplayMode.title)
    }
}

private struct VPNCountryToolbarButton: View {
    @EnvironmentObject private var model: BrowserViewModel

    var body: some View {
        ChromeButton(slot: .vpnCountry, symbol: "globe.americas", label: "Change Country") {
            model.isVPNPresented = true
        }
    }
}

private struct PasswordManagerToolbarButton: View {
    @EnvironmentObject private var model: BrowserViewModel

    var body: some View {
        ChromeButton(slot: .passwordManager, symbol: "key.fill", label: "Passwords") {
            model.isPasswordManagerPresented = true
        }
    }
}

private struct PrivateModeBadge: View {
    @EnvironmentObject private var theme: BrowserTheme

    var body: some View {
        Label("Private Mode", systemImage: "lock.shield")
            .font(.system(size: 13, weight: .black))
            .foregroundStyle(theme.color(.text))
            .padding(.horizontal, 12)
            .frame(height: 34)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay {
                Capsule()
                    .stroke(theme.color(.privateAccent).opacity(0.72), lineWidth: 1)
            }
            .shadow(color: Color.black.opacity(0.26), radius: 14, y: 7)
            .accessibilityLabel("Private Mode")
    }
}

private struct PrivateModeAuthView: View {
    @EnvironmentObject private var model: BrowserViewModel
    @EnvironmentObject private var theme: BrowserTheme
    @EnvironmentObject private var security: AppSecurityModel
    @Environment(\.dismiss) private var dismiss
    @State private var pin = ""
    @FocusState private var isPINFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 18) {
                Spacer(minLength: 16)

                Image(systemName: model.privateModeAuthAction == .enter ? "lock.shield.fill" : "lock.open.trianglebadge.exclamationmark")
                    .font(.system(size: 38, weight: .black))
                    .foregroundStyle(theme.color(.privateAccent))
                    .frame(width: 76, height: 76)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(theme.color(.privateAccent).opacity(0.5), lineWidth: 1)
                    }

                VStack(spacing: 7) {
                    Text(model.privateModeAuthAction.title)
                        .font(.system(size: 26, weight: .black))
                        .foregroundStyle(theme.color(.text))
                    Text(model.privateModeAuthAction.prompt)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(theme.color(.mutedText))
                        .multilineTextAlignment(.center)
                }

                SecurePINField(title: "Glide PIN", text: $pin)
                    .focused($isPINFocused)
                    .onSubmit(submit)
                    .frame(maxWidth: 420)

                if authMessage.isEmpty == false {
                    Text(authMessage)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color(red: 1.0, green: 0.64, blue: 0.64))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 420)
                }

                Button(action: submit) {
                    Label(model.privateModeAuthAction.buttonTitle, systemImage: "checkmark.shield")
                        .font(.system(size: 16, weight: .bold))
                        .frame(maxWidth: 420)
                        .frame(height: 52)
                }
                .buttonStyle(GlideGradientButtonStyle(prominence: .primary))
                .disabled(pin.count < 4)

                Spacer(minLength: 16)
            }
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(theme.color(.canvas))
            .navigationTitle("Private Mode")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") {
                        model.privateModeAuthMessage = ""
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            pin = ""
            model.privateModeAuthMessage = ""
            isPINFocused = true
        }
        .onChange(of: pin) { _, value in
            let cleaned = String(value.filter { $0.isNumber }.prefix(12))
            if cleaned != value {
                pin = cleaned
            }
        }
    }

    private var authMessage: String {
        model.privateModeAuthMessage.isEmpty ? security.message : model.privateModeAuthMessage
    }

    private func submit() {
        guard pin.count >= 4 else { return }

        if security.verifyPIN(pin) {
            model.completePrivateModeAuthentication()
            dismiss()
        } else {
            model.privateModeAuthMessage = security.message
            pin = ""
            isPINFocused = true
        }
    }
}

private struct MoreTabButton: View {
    @EnvironmentObject private var model: BrowserViewModel
    @EnvironmentObject private var theme: BrowserTheme
    @EnvironmentObject private var profiles: BrowserProfileManager
    @State private var isCommandCenterPresented = false

    var body: some View {
        Button {
            isCommandCenterPresented = true
        } label: {
            BrowserIcon(slot: .more, systemName: "ellipsis", size: 18, weight: .black)
                .frame(width: 38, height: 38)
                .foregroundStyle(theme.color(.text))
                .background(ControlGlassBackground(cornerRadius: 8))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(theme.color(.border).opacity(0.62), lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        .popover(isPresented: $isCommandCenterPresented, arrowEdge: .top) {
            BrowserCommandCenterView(isPresented: $isCommandCenterPresented)
                .environmentObject(model)
                .environmentObject(theme)
                .environmentObject(profiles)
                .frame(minWidth: 340, idealWidth: 380, maxWidth: 420)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .accessibilityLabel("More actions")
    }

    private var movedActions: [BrowserToolbarAction] {
        BrowserToolbarAction.allCases
            .filter { $0.isLeanBuildUtility == false }
            .filter { model.isInMoreMenu($0) }
            .filter { [.closeAllTabs, .settings, .tabFinder].contains($0) == false }
            .filter { action in
                guard model.isPrivateModeEnabled else { return true }
                return [.tabFolders, .containedTabs, .downloadCurrent, .history, .downloads].contains(action) == false
            }
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
            .disabled((action == .back && model.selectedTab?.canGoBack != true) ||
                      (action == .forward && model.selectedTab?.canGoForward != true))
        }
    }

    private func menuTitle(for action: BrowserToolbarAction) -> String {
        if action == .reload {
            return model.selectedTab?.isLoading == true ? "Stop Loading" : "Reload"
        }
        if action == .browserMusic {
            return model.isBrowserMusicEnabled ? "Pause Browser Music" : "Play Browser Music"
        }
        if action == .compact {
            return model.isCompactModeActive ? "Reveal Chrome" : "Compact Mode"
        }
        if action == .websiteMode {
            return "Website Mode: \(model.websiteDisplayMode.title)"
        }
        return action.menuTitle
    }

    private func menuSymbol(for action: BrowserToolbarAction) -> String {
        if action == .reload {
            return model.selectedTab?.isLoading == true ? "xmark" : "arrow.clockwise"
        }
        if action == .browserMusic {
            return model.isBrowserMusicEnabled ? "pause.fill" : model.customIconName(for: .browserMusic, fallback: action.symbolName)
        }
        if action == .compact {
            return model.isCompactModeActive ? "arrow.up.left.and.arrow.down.right" : model.customIconName(for: .compact, fallback: action.symbolName)
        }
        if action == .websiteMode {
            return model.customIconName(for: .websiteMode, fallback: model.websiteDisplayMode.symbolName)
        }
        return model.customIconName(for: action.customIconSlot, fallback: action.symbolName)
    }
}

private struct BrowserCommandCenterView: View {
    @EnvironmentObject private var model: BrowserViewModel
    @EnvironmentObject private var theme: BrowserTheme
    @EnvironmentObject private var profiles: BrowserProfileManager
    @Binding var isPresented: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                header

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 94), spacing: 8)], spacing: 8) {
                    CommandQuickTile(symbol: "plus", title: model.isPrivateModeEnabled ? "Private Tab" : "New Tab") {
                        close { model.openNewTabAndSearch(private: model.isPrivateModeEnabled) }
                    }
                    CommandQuickTile(symbol: "magnifyingglass", title: "Search") {
                        close { model.openFloatingSearch() }
                    }
                    CommandQuickTile(symbol: "sparkles", title: "AI") {
                        close { model.openAIPanel() }
                    }
                    CommandQuickTile(symbol: "rectangle.expand.vertical", title: "Fullscreen") {
                        close { model.enterFullscreenBrowsing() }
                    }
                    CommandQuickTile(symbol: "puzzlepiece", title: "Extensions", isDisabled: model.isPrivateModeEnabled) {
                        close { model.isAddOnsPresented = true }
                    }
                    CommandQuickTile(symbol: "star.circle.fill", title: "Settings") {
                        close { model.isSettingsPresented = true }
                    }
                }

                CommandCenterSection(title: "Profile", symbol: profiles.activeProfile.symbolName) {
                    ForEach(profiles.profiles) { profile in
                        CommandActionRow(
                            symbol: profile.symbolName,
                            title: profile.name,
                            subtitle: profiles.isActive(profile) ? "Active profile instance" : "Switch tabs, history, theme, and cookies",
                            isDisabled: profiles.isActive(profile) || profiles.isSwitchingProfiles
                        ) {
                            close { profiles.switchTo(profile) }
                        }
                    }
                    CommandActionRow(symbol: "slider.horizontal.3", title: "Customization Hub", subtitle: "Profiles, resolution, colors, gradients") {
                        close { model.isSettingsPresented = true }
                    }
                    CommandActionRow(symbol: "plus.circle.fill", title: "Add Glider", subtitle: "Create another browser profile instance") {
                        close {
                            let profile = profiles.createProfile()
                            profiles.switchTo(profile)
                        }
                    }
                }

                CommandCenterSection(title: "Menu Customization", symbol: "ellipsis.circle") {
                    CommandActionRow(symbol: "hand.draw", title: "Move Menu Button", subtitle: "Drag this control cluster anywhere") {
                        close { model.beginPageControlsMove() }
                    }
                    CommandActionRow(symbol: "arrow.counterclockwise", title: "Reset Menu Button", subtitle: "Return the floating menu to its default spot") {
                        close { model.resetPageControlsPosition() }
                    }
                    CommandActionRow(symbol: model.arePageControlsCollapsed ? "chevron.left" : "chevron.right", title: model.arePageControlsCollapsed ? "Expand Quick Buttons" : "Collapse Quick Buttons", subtitle: "Keep only the reveal handle visible") {
                        close { model.togglePageControlsCollapsed() }
                    }
                }

                CommandCenterSection(title: "Browser", symbol: "safari") {
                    CommandActionRow(symbol: "square.grid.2x2", title: "Find Tabs", subtitle: "\(model.chromeTabs.count) open") {
                        close { model.isTabFinderPresented = true }
                    }
                    CommandActionRow(symbol: model.areSideTabsCollapsed ? "sidebar.left" : "sidebar.leading", title: model.areSideTabsCollapsed ? "Reveal Tabs" : "Hide Tabs", subtitle: "Zen-style tab rail") {
                        close { model.setTabBarCollapsed(!model.areSideTabsCollapsed) }
                    }
                    CommandActionRow(symbol: "text.magnifyingglass", title: model.isTopSearchBarEnabled ? "Hide Top Search Bar" : "Show Top Search Bar", subtitle: "Keep websites fullscreen when hidden") {
                        close { model.isTopSearchBarEnabled.toggle() }
                    }
                    CommandActionRow(symbol: "hand.draw", title: "Move Menu Button", subtitle: "Drag the floating controls anywhere") {
                        close { model.beginPageControlsMove() }
                    }
                    CommandActionRow(symbol: model.isPrivateModeEnabled ? "lock.open" : "lock.shield", title: model.isPrivateModeEnabled ? "Close Private Mode" : "Private Mode", subtitle: "PIN-gated private tabs") {
                        close { model.requestPrivateModeToggle() }
                    }
                }

                CommandCenterSection(title: "Privacy", symbol: "hand.raised.fill") {
                    CommandActionRow(symbol: "shield.lefthalf.filled", title: "Shields Max", subtitle: model.isAdBlockerEnabled ? "Ads and trackers blocked" : "Turn protection back on") {
                        close { model.enableGlideMaxProtection() }
                    }
                    CommandActionRow(symbol: "eye.slash", title: "Ghost Mode", subtitle: "Stricter script and fingerprint protection") {
                        close { model.enableGlideGhostMode() }
                    }
                    Toggle("Block Scripts", isOn: $model.isScriptBlockingEnabled)
                    Toggle("Fingerprint Protection", isOn: $model.isFingerprintProtectionEnabled)
                    Toggle("Protect WebRTC IP", isOn: $model.isWebRTCProtectionEnabled)
                    CommandActionRow(symbol: "trash", title: "Clear Private Data", subtitle: "History, downloads, cookies, and cache", role: .destructive) {
                        close { model.clearPrivateBrowsingData() }
                    }
                }

                CommandCenterSection(title: "Extensions", symbol: "puzzlepiece") {
                    CommandActionRow(symbol: "square.and.arrow.down", title: "Install Extension File", subtitle: ".xpi, .crx, .zip, .js, .css", isDisabled: model.isPrivateModeEnabled) {
                        close { model.isAddOnsPresented = true }
                    }
                    CommandActionRow(symbol: "arrow.clockwise", title: "Reload Extensions", subtitle: "\(enabledExtensionCount) enabled") {
                        close { model.reloadWebExtensions() }
                    }
                    if model.webExtensionImportMessage.isEmpty == false {
                        Label(model.webExtensionImportMessage, systemImage: "info.circle")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(theme.color(.mutedText))
                            .lineLimit(2)
                    }
                }

                CommandCenterSection(title: "Tools", symbol: "wrench.and.screwdriver") {
                    CommandActionRow(symbol: "key.fill", title: "Passwords", subtitle: "Vault autofill", isDisabled: model.isPrivateModeEnabled) {
                        close { model.isPasswordManagerPresented = true }
                    }
                    CommandActionRow(symbol: "clock.arrow.circlepath", title: "History", subtitle: "Recently visited") {
                        close { model.isHistoryPresented = true }
                    }
                    CommandActionRow(symbol: "arrow.down.circle", title: "Downloads", subtitle: "\(model.downloads.count) saved") {
                        close { model.isDownloadsPresented = true }
                    }
                    CommandActionRow(symbol: "gearshape", title: "Favorite Settings", subtitle: "Pinned settings shortcut") {
                        close { model.isSettingsPresented = true }
                    }
                }

                if movedActions.isEmpty == false {
                    CommandCenterSection(title: "Custom", symbol: "slider.horizontal.3") {
                        ForEach(movedActions) { action in
                            commandRow(for: action)
                        }
                    }
                }

                CommandCenterSection(title: "Danger", symbol: "exclamationmark.triangle") {
                    CommandActionRow(symbol: "xmark.square", title: "Close All Tabs", subtitle: model.closeAllTabsWarningMessage, role: .destructive) {
                        close { model.requestCloseAllTabs() }
                    }
                }
            }
            .padding(14)
        }
        .background(theme.color(.canvas))
    }

    private var header: some View {
        HStack(spacing: 12) {
            BrowserIcon(slot: .more, systemName: "ellipsis", size: 18, weight: .black)
                .frame(width: 44, height: 44)
                .foregroundStyle(theme.color(.canvas))
                .background(ButtonGradientBackground(cornerRadius: 10, prominence: .primary))

            VStack(alignment: .leading, spacing: 3) {
                Text("Glide Menu")
                    .font(.system(size: 21, weight: .black))
                    .foregroundStyle(theme.color(.text))
                Text(currentSiteLabel)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(theme.color(.mutedText))
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            Button {
                close { model.isSettingsPresented = true }
            } label: {
                Image(systemName: "star.circle.fill")
                    .font(.system(size: 22, weight: .black))
                    .frame(width: 38, height: 38)
            }
            .buttonStyle(.plain)
            .foregroundStyle(theme.color(.accent))
            .accessibilityLabel("Favorite settings")
        }
    }

    private var currentSiteLabel: String {
        if BrowserTab.isStartPageURL(model.selectedTab?.url) {
            return "Start Page"
        }
        return model.selectedTab?.url?.host ?? model.selectedTab?.title ?? "Current page"
    }

    private var enabledExtensionCount: Int {
        model.installedWebExtensions.filter(\.isEnabled).count
    }

    private var movedActions: [BrowserToolbarAction] {
        BrowserToolbarAction.allCases
            .filter { $0.isLeanBuildUtility == false }
            .filter { model.isInMoreMenu($0) }
            .filter { [.closeAllTabs, .settings, .tabFinder].contains($0) == false }
            .filter { action in
                guard model.isPrivateModeEnabled else { return true }
                return [.tabFolders, .containedTabs, .downloadCurrent, .history, .downloads].contains(action) == false
            }
    }

    @ViewBuilder
    private func commandRow(for action: BrowserToolbarAction) -> some View {
        if action == .placement {
            VStack(alignment: .leading, spacing: 8) {
                Label("Chrome Placement", systemImage: model.chromePlacement.symbolName)
                    .font(.system(size: 13, weight: .black))
                    .foregroundStyle(theme.color(.mutedText))
                Picker("Chrome Placement", selection: $model.chromePlacement) {
                    ForEach(BrowserChromePlacement.allCases) { placement in
                        Label(placement.title, systemImage: placement.symbolName)
                            .tag(placement)
                    }
                }
                .pickerStyle(.segmented)
            }
            .padding(.vertical, 4)
        } else {
            CommandActionRow(
                symbol: menuSymbol(for: action),
                title: menuTitle(for: action),
                subtitle: action.title,
                isDisabled: (action == .back && model.selectedTab?.canGoBack != true) ||
                    (action == .forward && model.selectedTab?.canGoForward != true)
            ) {
                close { model.performToolbarAction(action) }
            }
        }
    }

    private func close(_ action: () -> Void) {
        isPresented = false
        action()
    }

    private func menuTitle(for action: BrowserToolbarAction) -> String {
        if action == .reload {
            return model.selectedTab?.isLoading == true ? "Stop Loading" : "Reload"
        }
        if action == .browserMusic {
            return model.isBrowserMusicEnabled ? "Pause Browser Music" : "Play Browser Music"
        }
        if action == .compact {
            return model.isCompactModeActive ? "Reveal Chrome" : "Compact Mode"
        }
        if action == .websiteMode {
            return "Website Mode: \(model.websiteDisplayMode.title)"
        }
        return action.menuTitle
    }

    private func menuSymbol(for action: BrowserToolbarAction) -> String {
        if action == .reload {
            return model.selectedTab?.isLoading == true ? "xmark" : "arrow.clockwise"
        }
        if action == .browserMusic {
            return model.isBrowserMusicEnabled ? "pause.fill" : model.customIconName(for: .browserMusic, fallback: action.symbolName)
        }
        if action == .compact {
            return model.isCompactModeActive ? "arrow.up.left.and.arrow.down.right" : model.customIconName(for: .compact, fallback: action.symbolName)
        }
        if action == .websiteMode {
            return model.customIconName(for: .websiteMode, fallback: model.websiteDisplayMode.symbolName)
        }
        return model.customIconName(for: action.customIconSlot, fallback: action.symbolName)
    }
}

private struct CommandCenterSection<Content: View>: View {
    @EnvironmentObject private var theme: BrowserTheme
    let title: String
    let symbol: String
    let content: () -> Content

    init(title: String, symbol: String, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.symbol = symbol
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: symbol)
                .font(.system(size: 12, weight: .black))
                .foregroundStyle(theme.color(.mutedText))

            VStack(alignment: .leading, spacing: 8) {
                content()
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(theme.color(.border).opacity(0.52), lineWidth: 1)
            }
        }
    }
}

private struct CommandQuickTile: View {
    @EnvironmentObject private var theme: BrowserTheme
    let symbol: String
    let title: String
    var isDisabled = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 7) {
                Image(systemName: symbol)
                    .font(.system(size: 17, weight: .black))
                    .frame(width: 30, height: 30)
                    .foregroundStyle(theme.color(.canvas))
                    .background(ButtonGradientBackground(cornerRadius: 8, prominence: .primary))
                Text(title)
                    .font(.system(size: 11, weight: .black))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                    .foregroundStyle(theme.color(.text))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 74)
            .background(ControlGlassBackground(cornerRadius: 10))
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(theme.color(.border).opacity(0.48), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.42 : 1)
    }
}

private struct CommandActionRow: View {
    @EnvironmentObject private var theme: BrowserTheme
    let symbol: String
    let title: String
    let subtitle: String
    var role: ButtonRole?
    var isDisabled = false
    let action: () -> Void

    init(
        symbol: String,
        title: String,
        subtitle: String,
        role: ButtonRole? = nil,
        isDisabled: Bool = false,
        action: @escaping () -> Void
    ) {
        self.symbol = symbol
        self.title = title
        self.subtitle = subtitle
        self.role = role
        self.isDisabled = isDisabled
        self.action = action
    }

    var body: some View {
        Button(role: role, action: action) {
            HStack(spacing: 10) {
                Image(systemName: symbol)
                    .font(.system(size: 14, weight: .bold))
                    .frame(width: 30, height: 30)
                    .foregroundStyle(role == .destructive ? .red : theme.color(.accent))
                    .background(ButtonGradientBackground(cornerRadius: 7, prominence: .quiet))

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(role == .destructive ? .red : theme.color(.text))
                        .lineLimit(1)
                    Text(subtitle)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(theme.color(.mutedText))
                        .lineLimit(2)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .black))
                    .foregroundStyle(theme.color(.mutedText))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.42 : 1)
    }
}

private struct AITabButton: View {
    @EnvironmentObject private var model: BrowserViewModel
    @EnvironmentObject private var theme: BrowserTheme

    var body: some View {
        Button {
            model.openAIPanel()
        } label: {
            BrowserIcon(slot: .ai, systemName: "sparkles", size: 15, weight: .bold)
                .frame(width: 38, height: 38)
                .foregroundStyle(theme.color(.text))
                .background(ControlGlassBackground(cornerRadius: 8))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(theme.color(.accent).opacity(0.65), lineWidth: 1)
                }
                .shadow(color: Color.black.opacity(0.25), radius: 10, y: 5)
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button {
                model.openAIPanel(action: .summarize)
            } label: {
                Label("Glide AI", systemImage: "sparkles")
            }

            ForEach(AIAssistant.allCases) { assistant in
                Button {
                    model.openAIAssistantWithPrompt(assistant)
                } label: {
                    Label(assistant.title, systemImage: assistant.symbolName)
                }
            }
        }
        .accessibilityLabel("Glide AI")
    }
}

private struct ContainedBrowserOverlay: View {
    @EnvironmentObject private var model: BrowserViewModel
    @EnvironmentObject private var theme: BrowserTheme

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                theme.color(.canvas)
                    .ignoresSafeArea()

                if let tab = model.selectedContainedTab {
                    ZStack(alignment: .top) {
                        BrowserWebView(tab: tab)
                            .id(tab.id)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .ignoresSafeArea()
                            .overlay(alignment: .top) {
                                LoadingProgress(tab: tab)
                            }

                        VStack(spacing: 10) {
                            ContainedBrowserHeader()
                            ContainedTabStrip()
                            ContainedAddressBar(tab: tab)
                        }
                        .padding(.top, 28)
                        .padding(.horizontal, 8)
                        .frame(maxWidth: .infinity, alignment: .top)
                        .background(.ultraThinMaterial)
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
                        .buttonStyle(GlideGradientButtonStyle(prominence: .primary))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .ignoresSafeArea()
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
                .background(ControlGlassBackground(cornerRadius: 8))

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
                    .background(ButtonGradientBackground(cornerRadius: 8, prominence: .primary))
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
                    .background(ControlGlassBackground(cornerRadius: 8))
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
                .background(ControlGlassBackground(cornerRadius: 8))
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
                        .background(ControlGlassBackground(cornerRadius: 8))
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
    private let finalStep = 2

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
                                Text("Build your Glide")
                                    .font(.system(size: 38, weight: .black))
                                    .foregroundStyle(theme.color(.text))
                                    .multilineTextAlignment(.center)

                                Text("Start with privacy, profiles, resolution, and moving gradients before the first tab even loads.")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(theme.color(.mutedText))
                                    .multilineTextAlignment(.center)
                            }
                            .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .move(edge: .leading).combined(with: .opacity)))
                        } else if step == 1 {
                            SetupCustomizationStage()
                                .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .move(edge: .leading).combined(with: .opacity)))
                        } else {
                            VStack(spacing: 12) {
                                Text("Ready to glide the web")
                                    .font(.system(size: 36, weight: .black))
                                    .foregroundStyle(theme.color(.text))
                                    .multilineTextAlignment(.center)

                                VStack(spacing: 0) {
                                    TutorialFeatureRow(
                                        symbol: "person.2.fill",
                                        title: "Two profile instances",
                                        detail: "Main Glide and Alt Glide keep separate tabs, history, downloads, passwords, themes, and cookies.",
                                        tint: .accent
                                    )

                                    TutorialDivider()

                                    TutorialFeatureRow(
                                        symbol: "rectangle.resize",
                                        title: "Resolution changer",
                                        detail: "Switch between phone, tablet, and desktop resolution profiles for websites and chrome.",
                                        tint: .accent
                                    )

                                    TutorialDivider()

                                    TutorialFeatureRow(
                                        symbol: "point.topleft.down.curvedto.point.bottomright.up",
                                        title: "Movable gradients",
                                        detail: "Drag the gradient start and end points to change how color flows through Glide.",
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
                    if step < finalStep {
                        withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) {
                            step += 1
                        }
                    } else {
                        model.completeTutorial()
                        model.openFloatingSearch()
                    }
                } label: {
                    HStack(spacing: 10) {
                        Text(step < finalStep ? "Next" : "Start browsing")
                            .font(.system(size: 16, weight: .bold))
                        Image(systemName: "arrow.right")
                            .font(.system(size: 14, weight: .black))
                    }
                    .frame(maxWidth: 560)
                    .frame(height: 54)
                    .foregroundStyle(theme.color(.canvas))
                    .background(ButtonGradientBackground(cornerRadius: 14, prominence: .primary))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(step < finalStep ? "Next" : "Start browsing")
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
                    model.enterFullscreenBrowsing()
                } label: {
                    Label("Fullscreen", systemImage: "rectangle.expand.vertical")
                }

                Button {
                    model.enableGlideMaxProtection()
                } label: {
                    Label("Shields", systemImage: "shield.lefthalf.filled")
                }

                Button {
                    model.openAIPanel()
                } label: {
                    Label("AI", systemImage: "sparkles")
                }
            }
            .font(.system(size: 13, weight: .bold))
            .buttonStyle(GlideGradientButtonStyle(prominence: .standard))
        }
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(theme.color(.border).opacity(0.65), lineWidth: 1)
        }
    }
}

private struct SetupCustomizationStage: View {
    @EnvironmentObject private var theme: BrowserTheme

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Make it yours")
                        .font(.system(size: 32, weight: .black))
                        .foregroundStyle(theme.color(.text))
                    Text("Pick the browser resolution, add color, and place each gradient dot before browsing.")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(theme.color(.mutedText))
                        .fixedSize(horizontal: false, vertical: true)
                }

                WebsiteResolutionControl()
                QuickColorStudio()
            }
            .padding(14)
        }
        .frame(maxHeight: 500)
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
                .background(ButtonGradientBackground(cornerRadius: 8, prominence: .quiet))

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

private struct GlideFeatureUpdateSection<Content: View>: View {
    @EnvironmentObject private var theme: BrowserTheme
    let title: String
    let symbol: String
    let content: Content

    init(title: String, symbol: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.symbol = symbol
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Label(title, systemImage: symbol)
                .font(.system(size: 14, weight: .black))
                .foregroundStyle(theme.color(.text))
                .padding(.horizontal, 14)
                .padding(.vertical, 12)

            content
        }
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(theme.color(.border).opacity(0.72), lineWidth: 1)
        }
    }
}

private struct GlideFeatureUpdateView: View {
    @EnvironmentObject private var model: BrowserViewModel
    @EnvironmentObject private var theme: BrowserTheme
    @EnvironmentObject private var profiles: BrowserProfileManager

    var body: some View {
        ZStack {
            BrowserBackground()

            VStack(spacing: 18) {
                Spacer(minLength: 20)

                VStack(spacing: 16) {
                    Image(systemName: "wand.and.stars.inverse")
                        .font(.system(size: 30, weight: .black))
                        .frame(width: 72, height: 72)
                        .foregroundStyle(theme.color(.canvas))
                        .background(ButtonGradientBackground(cornerRadius: 18, prominence: .primary))
                        .shadow(color: theme.color(.accent).opacity(0.24), radius: 26, y: 14)

                    VStack(spacing: 8) {
                        Text("Gliders & Displays")
                            .font(.system(size: 38, weight: .black))
                            .foregroundStyle(theme.color(.text))
                            .multilineTextAlignment(.center)

                        Text("Existing Glide installs now get cleaner profile instances, whole-browser resolution, and per-color gradient canvases.")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(theme.color(.mutedText))
                            .multilineTextAlignment(.center)
                    }
                }
                .frame(maxWidth: 560)
                .padding(.horizontal, 22)

                VStack(spacing: 12) {
                    GlideFeatureUpdateSection(title: "Gliders", symbol: "person.2.fill") {
                        TutorialFeatureRow(
                            symbol: "person.2.fill",
                            title: "\(profiles.profiles.count) Profile Instances",
                            detail: "Switch between \(profiles.profiles.map(\.name).joined(separator: " and ")) with separate Glide state and saved cookies.",
                            tint: .accent
                        )

                        TutorialDivider()

                        TutorialFeatureRow(
                            symbol: "paintpalette.fill",
                            title: "Per-Color Gradients",
                            detail: "Each color opens into its own gradient canvas with a draggable position dot.",
                            tint: .accent
                        )
                    }

                    GlideFeatureUpdateSection(title: "Displays", symbol: "rectangle.resize") {
                        TutorialFeatureRow(
                            symbol: "rectangle.resize",
                            title: "Whole-Browser Resolution",
                            detail: "Switch websites, tabs, search, and chrome between phone, tablet, and desktop resolution profiles.",
                            tint: .createTab
                        )

                        TutorialDivider()

                        TutorialFeatureRow(
                            symbol: "macwindow.on.rectangle",
                            title: "Chrome-Matched Layout",
                            detail: "The browser frame now follows the selected resolution profile instead of page zoom.",
                            tint: .createTab
                        )
                    }
                }
                .frame(maxWidth: 560)
                .padding(.horizontal, 22)

                Spacer(minLength: 8)

                VStack(spacing: 10) {
                    Button {
                        model.dismissFeatureUpdate()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                            model.isSettingsPresented = true
                        }
                    } label: {
                        Label("Open Customization", systemImage: "slider.horizontal.3")
                            .frame(maxWidth: 560)
                    }
                    .buttonStyle(GlideGradientButtonStyle(prominence: .primary, minHeight: 52, cornerRadius: 14))

                    Button {
                        model.dismissFeatureUpdate()
                    } label: {
                        Text("Start browsing")
                            .frame(maxWidth: 560)
                    }
                    .buttonStyle(GlideGradientButtonStyle(prominence: .standard, minHeight: 46, cornerRadius: 12))
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 24)
            }
        }
    }
}

private enum TabFinderScope: String, CaseIterable, Identifiable {
    case all
    case tabs
    case essentials
    case contained

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all:
            return "All"
        case .tabs:
            return "Tabs"
        case .essentials:
            return "Essentials"
        case .contained:
            return "Contained"
        }
    }
}

private struct BrowserTabFinderView: View {
    @EnvironmentObject private var model: BrowserViewModel
    @EnvironmentObject private var theme: BrowserTheme
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var scope: TabFinderScope = .all

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if availableScopes.count > 1 {
                    scopePicker
                }

                if visibleTabCount == 0 {
                    VStack(spacing: 12) {
                        Image(systemName: "square.grid.2x2")
                            .font(.system(size: 34, weight: .semibold))
                        Text(emptyTitle)
                            .font(.headline)
                    }
                    .foregroundStyle(theme.color(.mutedText))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        if model.isPrivateModeEnabled {
                            tabSection("Private Mode", tabs: filtered(model.visiblePrivateTabs), isContained: false)
                        } else {
                            if showsTabSections {
                                tabSection("Normal", tabs: filtered(model.normalTabs), isContained: false)
                            }

                            if showsEssentials {
                                essentialsSection(filteredEssentials)
                            }

                            if showsContainedTabs {
                                tabSection("Contained", tabs: filtered(model.containedTabs), isContained: true)
                            }
                        }
                    }
                    .scrollContentBackground(.hidden)
                }
            }
            .background(theme.color(.canvas))
            .navigationTitle(model.isPrivateModeEnabled ? "Private Mode" : "Tab Finder")
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Find tabs")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        model.openNewTabAndSearch(private: model.isPrivateModeEnabled)
                        dismiss()
                    } label: {
                        Label(model.isPrivateModeEnabled ? "New Private Tab" : "New Tab", systemImage: model.isPrivateModeEnabled ? "theatermasks" : "plus")
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .onAppear(perform: normalizeScope)
            .onChange(of: model.isPrivateModeEnabled) { _, _ in
                normalizeScope()
            }
        }
    }

    private var scopePicker: some View {
        Picker("Scope", selection: $scope) {
            ForEach(availableScopes) { finderScope in
                Text(finderScope.title).tag(finderScope)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(theme.color(.canvas))
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

    @ViewBuilder
    private func essentialsSection(_ items: [BrowserEssentialItem]) -> some View {
        if items.isEmpty == false {
            Section("Essentials (\(items.count))") {
                ForEach(items) { item in
                    EssentialFinderRow(item: item) {
                        model.openEssential(item)
                        dismiss()
                    } openInNewTabAction: {
                        model.openEssentialInNewTab(item)
                        dismiss()
                    } removeAction: {
                        model.removeEssential(item)
                    }
                    .listRowBackground(theme.color(.surface))
                }
            }
        }
    }

    private var visibleTabCount: Int {
        if model.isPrivateModeEnabled {
            return filtered(model.visiblePrivateTabs).count
        }

        var count = 0
        if showsTabSections {
            count += filtered(model.normalTabs).count
        }
        if showsEssentials {
            count += filteredEssentials.count
        }
        if showsContainedTabs {
            count += filtered(model.containedTabs).count
        }
        return count
    }

    private var availableScopes: [TabFinderScope] {
        model.isPrivateModeEnabled ? [.all] : TabFinderScope.allCases
    }

    private var showsTabSections: Bool {
        scope == .all || scope == .tabs
    }

    private var showsEssentials: Bool {
        model.isPrivateModeEnabled == false && (scope == .all || scope == .essentials)
    }

    private var showsContainedTabs: Bool {
        model.isPrivateModeEnabled == false && (scope == .all || scope == .contained)
    }

    private var emptyTitle: String {
        guard query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return "No matching items"
        }

        switch scope {
        case .essentials:
            return "No essentials yet"
        case .contained:
            return "No contained tabs"
        default:
            return "No tabs open"
        }
    }

    private var filteredEssentials: [BrowserEssentialItem] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard trimmedQuery.isEmpty == false else { return model.visibleEssentials }

        return model.visibleEssentials.filter { item in
            [
                item.title,
                item.urlString,
                item.url?.host ?? ""
            ]
            .joined(separator: " ")
            .lowercased()
            .contains(trimmedQuery)
        }
    }

    private func filtered(_ tabs: [BrowserTab]) -> [BrowserTab] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard trimmedQuery.isEmpty == false else { return tabs }

        return tabs.filter { tab in
            [
                tab.title,
                tab.url?.absoluteString ?? "",
                tab.url?.host ?? "",
                model.folderName(for: tab) ?? ""
            ]
            .joined(separator: " ")
            .lowercased()
            .contains(trimmedQuery)
        }
    }

    private func normalizeScope() {
        guard availableScopes.contains(scope) == false else { return }
        scope = .all
    }
}

private struct BrowserTabFoldersView: View {
    @EnvironmentObject private var model: BrowserViewModel
    @EnvironmentObject private var theme: BrowserTheme
    @Environment(\.dismiss) private var dismiss
    @State private var newFolderName = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Create") {
                    HStack(spacing: 10) {
                        TextField("Folder name", text: $newFolderName)
                            .textInputAutocapitalization(.words)

                        Button {
                            createFolder()
                        } label: {
                            Label("Create", systemImage: "folder.badge.plus")
                        }
                        .buttonStyle(GlideGradientButtonStyle(prominence: .primary))
                    }
                }

                if let currentTab = model.selectedTab, currentTab.isPrivate == false {
                    Section("Current Tab") {
                        FolderTabRow(tab: currentTab, isSelected: true) {
                            dismiss()
                        }

                        if model.tabFolders.isEmpty {
                            Button {
                                model.createFolder(from: currentTab)
                            } label: {
                                Label("Create Folder from Current Tab", systemImage: "folder.badge.plus")
                            }
                        } else {
                            ForEach(model.tabFolders) { folder in
                                Button {
                                    model.assign(currentTab, to: folder)
                                } label: {
                                    Label("Move to \(folder.name)", systemImage: "folder")
                                }
                            }
                        }

                        if currentTab.folderID != nil {
                            Button {
                                model.removeFromFolder(currentTab)
                            } label: {
                                Label("Remove from Folder", systemImage: "folder.badge.minus")
                            }
                        }
                    }
                }

                if model.unfiledNormalTabs.isEmpty == false {
                    Section("Unfiled Tabs") {
                        ForEach(model.unfiledNormalTabs) { tab in
                            FolderTabRow(tab: tab, isSelected: model.selectedTabID == tab.id) {
                                model.select(tab)
                                dismiss()
                            }
                        }
                    }
                }

                Section("Folders") {
                    if model.tabFolders.isEmpty {
                        Label("No folders yet", systemImage: "folder")
                            .foregroundStyle(theme.color(.mutedText))
                    } else {
                        ForEach(model.tabFolders) { folder in
                            DisclosureGroup {
                                let tabs = model.tabs(in: folder)

                                if tabs.isEmpty {
                                    Text("Empty")
                                        .foregroundStyle(theme.color(.mutedText))
                                } else {
                                    ForEach(tabs) { tab in
                                        FolderTabRow(tab: tab, isSelected: model.selectedTabID == tab.id) {
                                            model.select(tab)
                                            dismiss()
                                        }
                                        .contextMenu {
                                            Button {
                                                model.removeFromFolder(tab)
                                            } label: {
                                                Label("Remove from Folder", systemImage: "folder.badge.minus")
                                            }
                                        }
                                    }
                                }

                                Button(role: .destructive) {
                                    model.delete(folder)
                                } label: {
                                    Label("Delete Folder", systemImage: "trash")
                                }
                            } label: {
                                Label("\(folder.name) (\(model.tabs(in: folder).count))", systemImage: "folder")
                            }
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(theme.color(.canvas))
            .foregroundStyle(theme.color(.text))
            .navigationTitle("Tab Folders")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        model.resetFolders()
                    } label: {
                        Label("Reset Folders", systemImage: "arrow.counterclockwise")
                    }
                    .disabled(model.tabFolders.isEmpty && model.normalTabs.allSatisfy { $0.folderID == nil })
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func createFolder() {
        model.createTabFolder(named: newFolderName)
        newFolderName = ""
    }
}

private struct FolderTabRow: View {
    @EnvironmentObject private var theme: BrowserTheme
    @ObservedObject var tab: BrowserTab
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: tab.folderID == nil ? "globe" : "folder.fill")
                    .font(.system(size: 14, weight: .bold))
                    .frame(width: 32, height: 32)
                    .foregroundStyle(theme.color(.accent))
                    .background(ButtonGradientBackground(cornerRadius: 7, prominence: .quiet))

                VStack(alignment: .leading, spacing: 3) {
                    Text(tab.title)
                        .font(.system(size: 15, weight: .semibold))
                        .lineLimit(1)
                    Text(BrowserTab.isStartPageURL(tab.url) ? "Start Page" : (tab.url?.host ?? "Tab"))
                        .font(.caption)
                        .foregroundStyle(theme.color(.mutedText))
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(theme.color(.createTab))
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct EssentialFinderRow: View {
    @EnvironmentObject private var theme: BrowserTheme
    let item: BrowserEssentialItem
    let selectAction: () -> Void
    let openInNewTabAction: () -> Void
    let removeAction: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: selectAction) {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(theme.color(.createTab).opacity(0.28))
                        Image(systemName: "pin.fill")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(theme.color(.text))
                    }
                    .frame(width: 36, height: 36)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.title)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(theme.color(.text))
                            .lineLimit(1)

                        Text(item.url?.host ?? item.urlString)
                            .font(.caption)
                            .foregroundStyle(theme.color(.mutedText))
                            .lineLimit(1)
                    }

                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button(action: openInNewTabAction) {
                Image(systemName: "plus")
                    .font(.system(size: 11, weight: .bold))
                    .frame(width: 30, height: 30)
            }
            .buttonStyle(.plain)
            .foregroundStyle(theme.color(.mutedText))
            .accessibilityLabel("Open \(item.title) in a new tab")

            Button(role: .destructive, action: removeAction) {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
                    .frame(width: 30, height: 30)
            }
            .buttonStyle(.plain)
            .foregroundStyle(theme.color(.mutedText))
            .accessibilityLabel("Remove \(item.title) from Essentials")
        }
        .padding(.vertical, 4)
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
                            PrivateRedactedText(text: tab.title, isPrivate: tab.isPrivate, minWidth: 84, maxWidth: 210, height: 11)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(theme.color(.text))
                                .lineLimit(1)

                            if isSelected {
                                Text("ACTIVE")
                                    .font(.system(size: 9, weight: .black))
                                    .foregroundStyle(theme.color(.canvas))
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 3)
                                    .background(ButtonGradientBackground(cornerRadius: 5, prominence: .primary))
                            }
                        }

                        PrivateRedactedText(text: subtitle, isPrivate: tab.isPrivate, minWidth: 72, maxWidth: 190, height: 9)
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

private struct DownloadShelf: View {
    @EnvironmentObject private var model: BrowserViewModel
    @EnvironmentObject private var theme: BrowserTheme
    let item: BrowserDownloadItem

    var body: some View {
        HStack(spacing: 10) {
            Button {
                model.isDownloadsPresented = true
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: symbolName)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(tintColor)
                        .frame(width: 28, height: 28)
                        .background(ButtonGradientBackground(cornerRadius: 7, prominence: .quiet))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.filename)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(theme.color(.text))
                            .lineLimit(1)

                        Text(subtitle)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(theme.color(.mutedText))
                            .lineLimit(1)
                    }

                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if item.state == .inProgress {
                ProgressView()
                    .controlSize(.small)
                    .tint(theme.color(.accent))
            }

            Button {
                model.dismissDownloadShelf()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .black))
                    .frame(width: 30, height: 30)
                    .foregroundStyle(theme.color(.mutedText))
                    .background(ControlGlassBackground(cornerRadius: 7))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Hide download shelf")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(theme.color(.border).opacity(0.68), lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.34), radius: 18, y: 10)
    }

    private var symbolName: String {
        switch item.state {
        case .inProgress:
            return "arrow.down.circle"
        case .finished:
            return "checkmark.circle.fill"
        case .failed:
            return "exclamationmark.triangle.fill"
        }
    }

    private var tintColor: Color {
        switch item.state {
        case .inProgress:
            return theme.color(.accent)
        case .finished:
            return .green
        case .failed:
            return .red
        }
    }

    private var subtitle: String {
        var parts = [item.state.title]
        if item.isEncrypted {
            parts.append("Encrypted")
        }
        if let byteCount = item.originalByteCount {
            parts.append(ByteCountFormatter.string(fromByteCount: byteCount, countStyle: .file))
        }
        return parts.joined(separator: "  ")
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
                        .buttonStyle(GlideGradientButtonStyle(prominence: .primary))
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
                                        .buttonStyle(GlideGradientButtonStyle(prominence: .standard))

                                        Button {
                                            requestExport(item, intent: .share)
                                        } label: {
                                            Label("Share", systemImage: "square.and.arrow.up")
                                        }
                                        .buttonStyle(GlideGradientButtonStyle(prominence: .standard))
                                    }

                                    if item.sourceURLString.isEmpty == false {
                                        Button {
                                            model.retryDownload(item)
                                        } label: {
                                            Label(item.state == .failed ? "Retry" : "Download Again", systemImage: "arrow.clockwise")
                                        }
                                        .buttonStyle(GlideGradientButtonStyle(prominence: .standard))
                                    }

                                    Button(role: .destructive) {
                                        model.deleteDownload(item)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                    .buttonStyle(GlideGradientButtonStyle(prominence: .standard))
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
            Text("Real downloads open from Glide's Downloads folder. Older encrypted downloads create a temporary decrypted copy before opening or sharing.")
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

private struct ProfileCustomizationPanel: View {
    @EnvironmentObject private var profiles: BrowserProfileManager
    @EnvironmentObject private var theme: BrowserTheme

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Profiles", systemImage: "person.2.fill")
                    .font(.system(size: 14, weight: .black))
                Spacer()
                Text(profiles.isSwitchingProfiles ? "Switching..." : profiles.activeProfile.name)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(theme.color(.mutedText))
            }

            ForEach(profiles.profiles) { profile in
                ProfileSlotEditor(profile: profile)
            }

            Button {
                profiles.createProfile()
            } label: {
                Label("Add Glider", systemImage: "plus.circle.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(GlideGradientButtonStyle(prominence: .primary, minHeight: 40))
            .disabled(profiles.isSwitchingProfiles)

            if profiles.statusMessage.isEmpty == false {
                Label(profiles.statusMessage, systemImage: "checkmark.circle")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(theme.color(.mutedText))
            }
        }
        .padding(.vertical, 4)
    }
}

private struct ProfileSlotEditor: View {
    @EnvironmentObject private var profiles: BrowserProfileManager
    @EnvironmentObject private var theme: BrowserTheme
    let profile: BrowserProfile

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: profile.symbolName)
                    .font(.system(size: 16, weight: .bold))
                    .frame(width: 34, height: 34)
                    .foregroundStyle(theme.color(.canvas))
                    .background(profile.tintColor, in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    TextField("Profile name", text: profileNameBinding)
                        .font(.system(size: 15, weight: .bold))
                        .textInputAutocapitalization(.words)

                    Text(profile.isPrimary ? "Original Glide state" : "Separate tabs, history, passwords, theme, cookies")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(theme.color(.mutedText))
                        .lineLimit(2)
                }

                Spacer(minLength: 0)

                ColorPicker("Profile color", selection: profileTintBinding, supportsOpacity: false)
                    .labelsHidden()
            }

            HStack(spacing: 8) {
                Button {
                    profiles.switchTo(profile)
                } label: {
                    Label(profiles.isActive(profile) ? "Active Profile" : "Switch to \(profile.name)", systemImage: profiles.isActive(profile) ? "checkmark.circle.fill" : "arrow.triangle.2.circlepath")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(GlideGradientButtonStyle(prominence: profiles.isActive(profile) ? .primary : .standard, minHeight: 38))
                .disabled(profiles.isActive(profile) || profiles.isSwitchingProfiles)

                if profile.isPrimary == false {
                    Button(role: .destructive) {
                        profiles.delete(profile)
                    } label: {
                        Image(systemName: "trash")
                            .frame(width: 42)
                    }
                    .buttonStyle(GlideGradientButtonStyle(prominence: .standard, minHeight: 38))
                    .disabled(profiles.isActive(profile) || profiles.isSwitchingProfiles)
                    .accessibilityLabel("Delete \(profile.name)")
                }
            }
        }
        .padding(10)
        .background(ControlGlassBackground(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(profiles.isActive(profile) ? profile.tintColor.opacity(0.75) : theme.color(.border).opacity(0.45), lineWidth: 1)
        }
    }

    private var profileNameBinding: Binding<String> {
        Binding(
            get: {
                profiles.profiles.first { $0.id == profile.id }?.name ?? profile.name
            },
            set: {
                profiles.rename(profile, to: $0)
            }
        )
    }

    private var profileTintBinding: Binding<Color> {
        Binding(
            get: {
                profiles.profiles.first { $0.id == profile.id }?.tintColor ?? profile.tintColor
            },
            set: {
                profiles.setTint($0, for: profile)
            }
        )
    }
}

private struct WebsiteResolutionControl: View {
    @EnvironmentObject private var model: BrowserViewModel
    @EnvironmentObject private var theme: BrowserTheme

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Resolution", systemImage: "rectangle.resize")
                    .font(.system(size: 14, weight: .black))
                Spacer()
                Text(model.browserResolutionLabel)
                    .font(.caption.weight(.black))
                    .foregroundStyle(theme.color(.mutedText))
            }

            VStack(spacing: 8) {
                ForEach(BrowserResolutionPreset.allCases) { preset in
                    resolutionPreset(preset)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func resolutionPreset(_ preset: BrowserResolutionPreset) -> some View {
        Button {
            model.setBrowserResolutionPreset(preset)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: preset.symbolName)
                    .font(.system(size: 13, weight: .black))
                    .frame(width: 20)

                VStack(alignment: .leading, spacing: 2) {
                    Text(preset.title)
                        .font(.system(size: 13, weight: .black))
                    Text(preset.detail)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(theme.color(.mutedText))
                }

                Spacer(minLength: 0)

                if model.browserResolutionPreset == preset {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14, weight: .black))
                }
            }
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(GlideGradientButtonStyle(prominence: model.browserResolutionPreset == preset ? .primary : .standard, minHeight: 42))
    }
}

private struct QuickColorStudio: View {
    @EnvironmentObject private var theme: BrowserTheme

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Color Studio", systemImage: "paintpalette.fill")
                .font(.system(size: 14, weight: .black))

            HStack(spacing: 8) {
                paletteButton("Prism", accent: "#8DD7FF", glow: "#C4B5FD", create: "#D6E2FF", canvas: "#07090D", start: (0.0, 0.0), end: (1.0, 1.0))
                paletteButton("Aurora", accent: "#7DD3FC", glow: "#A7F3D0", create: "#FDE68A", canvas: "#07110F", start: (0.08, 0.12), end: (0.9, 0.72))
                paletteButton("Signal", accent: "#F0ABFC", glow: "#67E8F9", create: "#F9A8D4", canvas: "#090816", start: (0.82, 0.05), end: (0.12, 0.95))
            }

            VStack(spacing: 8) {
                ThemeColorGradientMenu(token: .accent)
                ThemeColorGradientMenu(token: .createTab)
                ThemeColorGradientMenu(token: .chrome)
            }

            CustomColorStopsEditor()
        }
        .padding(.vertical, 4)
    }

    private func paletteButton(
        _ title: String,
        accent: String,
        glow: String,
        create: String,
        canvas: String,
        start: (Double, Double),
        end: (Double, Double)
    ) -> some View {
        Button {
            theme.setColor(Color(hex: accent), for: .accent)
            theme.setGradientColor(Color(hex: glow), for: .accent)
            theme.setColor(Color(hex: create), for: .createTab)
            theme.setGradientColor(Color(hex: accent), for: .createTab)
            theme.setColor(Color(hex: canvas), for: .canvas)
            theme.setGradientColor(Color(hex: glow), for: .chrome)
        } label: {
            Text(title)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(GlideGradientButtonStyle(prominence: .standard, minHeight: 34))
    }
}

private struct ThemeColorGradientMenu: View {
    @EnvironmentObject private var theme: BrowserTheme
    let token: BrowserThemeToken
    @State private var isExpanded = false

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            VStack(alignment: .leading, spacing: 10) {
                ColorPicker("Base color", selection: theme.binding(for: token), supportsOpacity: false)

                GradientCircleCanvas(
                    baseColor: theme.color(token),
                    circles: theme.gradientCircles(for: token)
                ) { circle, x, y in
                    theme.setGradientCirclePosition(x: x, y: y, circle: circle, for: token)
                }

                HStack(spacing: 8) {
                    Label("Gradient circles", systemImage: "circle.hexagongrid.fill")
                        .font(.caption.weight(.black))
                    Spacer()
                    Button {
                        theme.addGradientCircle(for: token)
                    } label: {
                        Label("Add Circle", systemImage: "plus.circle.fill")
                    }
                    .font(.caption.weight(.bold))
                }

                ForEach(theme.gradientCircles(for: token)) { circle in
                    GradientCircleStopRow(
                        token: token,
                        circle: circle,
                        canRemove: theme.gradientCircles(for: token).count > 1
                    )
                }
            }
            .padding(.top, 10)
        } label: {
            HStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [theme.color(token)] + theme.gradientColors(for: token),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 34, height: 34)
                    .overlay {
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .stroke(theme.color(.border).opacity(0.6), lineWidth: 1)
                    }

                VStack(alignment: .leading, spacing: 2) {
                    Text(token.title)
                        .font(.system(size: 14, weight: .black))
                    Text("\(theme.gradientCircles(for: token).count) circle\(theme.gradientCircles(for: token).count == 1 ? "" : "s")")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(theme.color(.mutedText))
                }
            }
        }
        .padding(9)
        .background(ControlGlassBackground(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(theme.color(.border).opacity(isExpanded ? 0.82 : 0.42), lineWidth: 1)
        }
    }
}

private struct GradientCircleStopRow: View {
    @EnvironmentObject private var theme: BrowserTheme
    let token: BrowserThemeToken
    let circle: BrowserThemeGradientCircle
    let canRemove: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 10) {
                ColorPicker("Circle color", selection: colorBinding, supportsOpacity: false)
                    .labelsHidden()

                VStack(alignment: .leading, spacing: 2) {
                    Text("Circle \(circleNumber)")
                        .font(.caption.weight(.black))
                    Text("Intensity \(Int((currentCircle.intensity * 100).rounded()))%")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(theme.color(.mutedText))
                }

                Spacer()

                Button(role: .destructive) {
                    theme.removeGradientCircle(circle, for: token)
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.plain)
                .disabled(canRemove == false)
                .opacity(canRemove ? 1 : 0.36)
                .accessibilityLabel("Remove gradient circle")
            }

            Slider(value: intensityBinding, in: 0...1, step: 0.01)
        }
        .padding(8)
        .background(Color.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color(hex: currentCircle.colorHex).opacity(max(0.18, currentCircle.intensity)), lineWidth: 1)
        }
    }

    private var currentCircle: BrowserThemeGradientCircle {
        theme.gradientCircles(for: token).first { $0.id == circle.id } ?? circle
    }

    private var circleNumber: Int {
        (theme.gradientCircles(for: token).firstIndex { $0.id == circle.id } ?? 0) + 1
    }

    private var colorBinding: Binding<Color> {
        Binding(
            get: { Color(hex: currentCircle.colorHex) },
            set: { theme.setGradientCircleColor($0, circle: circle, for: token) }
        )
    }

    private var intensityBinding: Binding<Double> {
        Binding(
            get: { currentCircle.intensity },
            set: { theme.setGradientCircleIntensity($0, circle: circle, for: token) }
        )
    }
}

private struct CustomColorStopsEditor: View {
    @EnvironmentObject private var theme: BrowserTheme

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Added Gradients", systemImage: "plus.square.on.square")
                    .font(.system(size: 14, weight: .black))
                Spacer()
                Button {
                    theme.addCustomColor()
                } label: {
                    Label("Add Gradient", systemImage: "plus.circle.fill")
                }
                .font(.caption.weight(.bold))
            }

            if theme.customColors.isEmpty {
                Text("No added gradients yet.")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(theme.color(.mutedText))
            } else {
                ForEach(theme.customColors) { color in
                    CustomColorStopRow(color: color)
                }
            }
        }
    }
}

private struct CustomColorStopRow: View {
    @EnvironmentObject private var theme: BrowserTheme
    let color: BrowserCustomThemeColor
    @State private var isExpanded = false

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            VStack(alignment: .leading, spacing: 12) {
                TextField("Color name", text: nameBinding)
                    .font(.system(size: 14, weight: .bold))
                    .textInputAutocapitalization(.words)

                HStack(spacing: 12) {
                    ColorPicker("Color", selection: baseColorBinding, supportsOpacity: false)
                    ColorPicker("Gradient", selection: gradientColorBinding, supportsOpacity: false)
                }

                GradientCircleCanvas(
                    baseColor: Color(hex: currentColor.colorHex),
                    circles: [
                        BrowserThemeGradientCircle(
                            colorHex: currentColor.gradientHex,
                            intensity: theme.customColorIntensity(currentColor)
                        )
                    ]
                )

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Intensity")
                        Spacer()
                        Text("\(Int((theme.customColorIntensity(currentColor) * 100).rounded()))%")
                            .foregroundStyle(theme.color(.mutedText))
                    }
                    .font(.caption.weight(.semibold))

                    Slider(value: intensityBinding, in: 0...1, step: 0.01)
                }

                Button(role: .destructive) {
                    theme.removeCustomColor(color)
                } label: {
                    Label("Remove Gradient", systemImage: "trash")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(GlideGradientButtonStyle(prominence: .quiet, minHeight: 34))
                .accessibilityLabel("Remove \(color.name)")
            }
            .padding(.top, 10)
        } label: {
            HStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: currentColor.colorHex), Color(hex: currentColor.gradientHex)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 34, height: 34)
                    .overlay {
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .stroke(Color(hex: currentColor.colorHex).opacity(0.72), lineWidth: 1)
                    }

                VStack(alignment: .leading, spacing: 2) {
                    Text(currentColor.name)
                        .font(.system(size: 14, weight: .black))
                    Text("Intensity \(Int((theme.customColorIntensity(currentColor) * 100).rounded()))%")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(theme.color(.mutedText))
                }
            }
        }
        .padding(10)
        .background(ControlGlassBackground(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color(hex: currentColor.colorHex).opacity(isExpanded ? 0.82 : 0.52), lineWidth: 1)
        }
    }

    private var nameBinding: Binding<String> {
        Binding(
            get: { currentColor.name },
            set: { theme.renameCustomColor(color, to: $0) }
        )
    }

    private var baseColorBinding: Binding<Color> {
        Binding(
            get: { Color(hex: currentColor.colorHex) },
            set: { theme.setCustomColor($0, for: color) }
        )
    }

    private var gradientColorBinding: Binding<Color> {
        Binding(
            get: { Color(hex: currentColor.gradientHex) },
            set: { theme.setCustomGradientColor($0, for: color) }
        )
    }

    private var intensityBinding: Binding<Double> {
        Binding(
            get: { theme.customColorIntensity(currentColor) },
            set: { theme.setCustomColorIntensity($0, for: color) }
        )
    }

    private var currentColor: BrowserCustomThemeColor {
        theme.customColors.first { $0.id == color.id } ?? color
    }
}

private struct GradientCircleCanvas: View {
    @EnvironmentObject private var theme: BrowserTheme
    let baseColor: Color
    let circles: [BrowserThemeGradientCircle]
    var onMove: ((BrowserThemeGradientCircle, Double, Double) -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Text("Gradient canvas")
                Spacer()
                Text("\(circles.count) circle\(circles.count == 1 ? "" : "s")")
                    .foregroundStyle(theme.color(.mutedText))
            }
            .font(.caption.weight(.semibold))

            GeometryReader { proxy in
                ZStack {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [baseColor] + circles.map { Color(hex: $0.colorHex).opacity(max(0.08, $0.intensity)) } + [baseColor.opacity(0.72)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: 9, style: .continuous)
                                .stroke(theme.color(.border).opacity(0.65), lineWidth: 1)
                        }

                    ForEach(circles) { circle in
                        Circle()
                            .fill(Color(hex: circle.colorHex).opacity(max(0.48, circle.intensity)))
                            .frame(width: circleDiameter(for: circle), height: circleDiameter(for: circle))
                            .overlay {
                                Circle()
                                    .stroke(Color.white.opacity(0.86), lineWidth: 2)
                            }
                            .shadow(color: Color(hex: circle.colorHex).opacity(max(0.18, circle.intensity * 0.44)), radius: 6, y: 3)
                            .position(circlePosition(circle, in: proxy.size))
                            .gesture(circleDrag(circle, in: proxy.size))
                    }
                }
            }
            .frame(height: 92)
        }
    }

    private func circleDiameter(for circle: BrowserThemeGradientCircle) -> CGFloat {
        18 + CGFloat(circle.intensity) * 10
    }

    private func circlePosition(_ circle: BrowserThemeGradientCircle, in size: CGSize) -> CGPoint {
        let inset = circleDiameter(for: circle) / 2
        return CGPoint(
            x: min(max(CGFloat(circle.x) * size.width, inset), max(inset, size.width - inset)),
            y: min(max(CGFloat(circle.y) * size.height, inset), max(inset, size.height - inset))
        )
    }

    private func circleDrag(_ circle: BrowserThemeGradientCircle, in size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                guard size.width > 0, size.height > 0 else { return }
                onMove?(
                    circle,
                    Double(min(max(value.location.x / size.width, 0), 1)),
                    Double(min(max(value.location.y / size.height, 0), 1))
                )
            }
    }
}

private struct GradientMotionControl: View {
    @EnvironmentObject private var theme: BrowserTheme

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Gradient Motion", systemImage: "point.topleft.down.curvedto.point.bottomright.up")
                    .font(.system(size: 14, weight: .black))
                Spacer()
                Button("Reset") {
                    theme.resetGradientMotion()
                }
                .font(.caption.weight(.bold))
            }

            GeometryReader { proxy in
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    theme.color(.accent),
                                    theme.gradientColor(.accent)
                                ] + theme.customGradientColors + [
                                    theme.color(.createTab)
                                ],
                                startPoint: theme.gradientStartPoint,
                                endPoint: theme.gradientEndPoint
                            )
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(theme.color(.border).opacity(0.65), lineWidth: 1)
                        }

                    GradientHandle(title: "Start", color: theme.color(.accent))
                        .position(handlePosition(x: theme.gradientStartX, y: theme.gradientStartY, in: proxy.size))
                        .gesture(handleDrag(in: proxy.size) { x, y in
                            theme.updateGradientStart(x: x, y: y)
                        })

                    GradientHandle(title: "End", color: theme.color(.createTab))
                        .position(handlePosition(x: theme.gradientEndX, y: theme.gradientEndY, in: proxy.size))
                        .gesture(handleDrag(in: proxy.size) { x, y in
                            theme.updateGradientEnd(x: x, y: y)
                        })
                }
            }
            .frame(height: 170)
            .frame(maxWidth: .infinity)
        }
        .padding(.vertical, 4)
    }

    private func handlePosition(x: Double, y: Double, in size: CGSize) -> CGPoint {
        CGPoint(
            x: min(max(CGFloat(x) * size.width, 22), max(22, size.width - 22)),
            y: min(max(CGFloat(y) * size.height, 22), max(22, size.height - 22))
        )
    }

    private func handleDrag(in size: CGSize, update: @escaping (Double, Double) -> Void) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                guard size.width > 0, size.height > 0 else { return }
                update(
                    Double(min(max(value.location.x / size.width, 0), 1)),
                    Double(min(max(value.location.y / size.height, 0), 1))
                )
            }
    }
}

private struct GradientHandle: View {
    @EnvironmentObject private var theme: BrowserTheme
    let title: String
    let color: Color

    var body: some View {
        VStack(spacing: 3) {
            Circle()
                .fill(color)
                .frame(width: 24, height: 24)
                .overlay {
                    Circle()
                        .stroke(Color.white.opacity(0.85), lineWidth: 2)
                }
                .shadow(color: Color.black.opacity(0.32), radius: 8, y: 4)

            Text(title)
                .font(.system(size: 9, weight: .black))
                .foregroundStyle(theme.color(.canvas))
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Color.white.opacity(0.86), in: RoundedRectangle(cornerRadius: 5, style: .continuous))
        }
    }
}

private struct ThreeDotMenuCustomizationPanel: View {
    @EnvironmentObject private var model: BrowserViewModel
    @EnvironmentObject private var theme: BrowserTheme
    @EnvironmentObject private var profiles: BrowserProfileManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Menu Presets")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(theme.color(.mutedText))

                HStack(spacing: 8) {
                    presetButton("Minimal", actions: [.tabFinder, .compact, .settings])
                    presetButton("Browser", actions: [.back, .forward, .reload, .tabFinder, .history, .downloads, .websiteMode, .settings])
                    presetButton("Everything", actions: BrowserToolbarAction.customizationCases)
                }
            }

            HStack(spacing: 8) {
                Button {
                    dismiss()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                        model.beginPageControlsMove()
                    }
                } label: {
                    Label("Move Button", systemImage: "hand.draw")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(GlideGradientButtonStyle(prominence: .standard, minHeight: 38))

                Button {
                    model.resetPageControlsPosition()
                } label: {
                    Label("Reset Spot", systemImage: "arrow.counterclockwise")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(GlideGradientButtonStyle(prominence: .standard, minHeight: 38))
            }

            Toggle("Start collapsed to a reveal handle", isOn: $model.arePageControlsCollapsed)

            Button {
                let profile = profiles.createProfile()
                profiles.switchTo(profile)
            } label: {
                Label("Add Glider Profile", systemImage: "plus.circle.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(GlideGradientButtonStyle(prominence: .primary, minHeight: 40))

            VStack(alignment: .leading, spacing: 8) {
                Text("Actions In Menu")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(theme.color(.mutedText))

                ForEach(BrowserToolbarAction.customizationCases) { action in
                    Toggle(isOn: moreMenuBinding(for: action)) {
                        Label(action.title, systemImage: action.symbolName)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func presetButton(_ title: String, actions: [BrowserToolbarAction]) -> some View {
        Button {
            let actionSet = Set(actions.map(\.rawValue))
            for action in BrowserToolbarAction.customizationCases {
                model.setMoreMenuAction(action, enabled: actionSet.contains(action.rawValue))
            }
        } label: {
            Text(title)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(GlideGradientButtonStyle(prominence: .standard, minHeight: 34))
    }

    private func moreMenuBinding(for action: BrowserToolbarAction) -> Binding<Bool> {
        Binding(
            get: { model.isInMoreMenu(action) },
            set: { model.setMoreMenuAction(action, enabled: $0) }
        )
    }
}

private struct PasswordManagerView: View {
    @EnvironmentObject private var model: BrowserViewModel
    @EnvironmentObject private var theme: BrowserTheme
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var host = ""
    @State private var username = ""
    @State private var password = ""
    @State private var notes = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Current Site") {
                    LabeledContent("Site") {
                        Text(currentHostLabel)
                            .foregroundStyle(theme.color(.mutedText))
                    }

                    if matchingEntries.isEmpty {
                        Label("No saved password for this site yet.", systemImage: "key")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(theme.color(.mutedText))
                    } else {
                        ForEach(matchingEntries) { entry in
                            passwordEntryRow(entry)
                        }
                    }
                }

                Section("Save Password") {
                    TextField("Label", text: $title)
                    TextField("Website", text: $host)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                    TextField("Username or email", text: $username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    SecureField("Password", text: $password)
                    TextField("Notes", text: $notes)

                    Button {
                        model.savePasswordEntry(title: title, host: host, username: username, password: password, notes: notes)
                        password = ""
                        notes = ""
                    } label: {
                        Label("Save Password", systemImage: "square.and.arrow.down")
                    }
                    .buttonStyle(GlideGradientButtonStyle(prominence: .primary))
                }

                Section("All Passwords") {
                    if model.passwordEntries.isEmpty {
                        Label("Password vault is empty.", systemImage: "lock")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(theme.color(.mutedText))
                    } else {
                        ForEach(model.passwordEntries) { entry in
                            passwordEntryRow(entry)
                        }
                    }
                }

                if model.passwordStatusMessage.isEmpty == false {
                    Section("Status") {
                        Label(model.passwordStatusMessage, systemImage: "info.circle")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(theme.color(.mutedText))
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(theme.color(.canvas))
            .foregroundStyle(theme.color(.text))
            .navigationTitle("Passwords")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                host = model.currentPasswordHost
                title = host
            }
        }
    }

    private var matchingEntries: [BrowserPasswordEntry] {
        model.matchingPasswordEntriesForCurrentSite()
    }

    private var currentHostLabel: String {
        model.currentPasswordHost.isEmpty ? "No website selected" : model.currentPasswordHost
    }

    private func passwordEntryRow(_ entry: BrowserPasswordEntry) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: "key.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(theme.color(.accent))
                    .frame(width: 30, height: 30)
                    .background(ButtonGradientBackground(cornerRadius: 7, prominence: .quiet))

                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.title)
                        .font(.system(size: 15, weight: .semibold))
                    Text("\(entry.username) at \(entry.host)")
                        .font(.caption)
                        .foregroundStyle(theme.color(.mutedText))
                        .lineLimit(1)
                }
            }

            HStack(spacing: 8) {
                Button {
                    model.fillPasswordEntry(entry)
                } label: {
                    Label("Fill", systemImage: "rectangle.and.pencil.and.ellipsis")
                }
                .buttonStyle(GlideGradientButtonStyle(prominence: .standard))

                Button(role: .destructive) {
                    model.deletePasswordEntry(entry)
                } label: {
                    Label("Delete", systemImage: "trash")
                }
                .buttonStyle(GlideGradientButtonStyle(prominence: .standard))
            }
            .font(.caption.weight(.bold))
        }
        .padding(.vertical, 4)
    }
}

private struct CustomVPNView: View {
    @EnvironmentObject private var model: BrowserViewModel
    @EnvironmentObject private var theme: BrowserTheme
    @Environment(\.dismiss) private var dismiss
    @State private var profile = CustomVPNProfile.empty
    @State private var selectedCountry = "United States"

    private let countryPresets = [
        "United States",
        "Canada",
        "United Kingdom",
        "Japan",
        "Germany",
        "France",
        "Netherlands",
        "Australia",
        "South Korea",
        "Brazil"
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section("Country Changer") {
                    Picker("Country", selection: countryBinding) {
                        ForEach(countryPresets, id: \.self) { country in
                            Text(country)
                                .tag(country)
                        }
                    }

                    Button {
                        profile.countryName = selectedCountry
                        model.changeVPNCountry(using: profile)
                    } label: {
                        Label("Change Country", systemImage: "globe.americas.fill")
                    }
                    .buttonStyle(GlideGradientButtonStyle(prominence: .primary))

                    Text("Pick a country, add a real VPN server in that country, then Glide asks iOS to switch the tunnel.")
                        .font(.caption)
                        .foregroundStyle(theme.color(.mutedText))
                }

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
                    SecureField("Password", text: vpnPasswordBinding)
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
                selectedCountry = model.selectedVPNCountry.isEmpty ? (profile.countryName.isEmpty ? "United States" : profile.countryName) : model.selectedVPNCountry
                if profile.countryName.isEmpty {
                    profile.countryName = selectedCountry
                }
            }
        }
    }

    private var countryBinding: Binding<String> {
        Binding(
            get: { selectedCountry },
            set: { country in
                selectedCountry = country
                profile.countryName = country
                model.prepareVPNCountry(country)
            }
        )
    }

    private var vpnPasswordBinding: Binding<String> {
        Binding(
            get: { profile.password ?? "" },
            set: { profile.password = $0.isEmpty ? nil : $0 }
        )
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

private struct GlideAIPanelView: View {
    @EnvironmentObject private var model: BrowserViewModel
    @EnvironmentObject private var theme: BrowserTheme
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 12) {
                        BrowserIcon(slot: .ai, systemName: "sparkles", size: 18, weight: .black)
                            .frame(width: 44, height: 44)
                            .foregroundStyle(theme.color(.canvas))
                            .background(ButtonGradientBackground(cornerRadius: 10, prominence: .primary))

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Glide AI")
                                .font(.system(size: 20, weight: .black))
                                .foregroundStyle(theme.color(.text))
                            Text("Works with the page you are viewing, then sends the prompt where you choose.")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(theme.color(.mutedText))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .listRowBackground(theme.color(.surface))

                Section("Page") {
                    LabeledContent("Title") {
                        Text(model.selectedTab?.title ?? "No page")
                            .foregroundStyle(theme.color(.mutedText))
                            .lineLimit(1)
                    }

                    LabeledContent("URL") {
                        Text(model.selectedTab?.url?.host ?? model.selectedTab?.addressText ?? "No URL")
                            .foregroundStyle(theme.color(.mutedText))
                            .lineLimit(1)
                    }
                }

                Section("Actions") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 132), spacing: 8)], spacing: 8) {
                        ForEach(BrowserAIAction.allCases) { action in
                            Button {
                                model.prepareAI(action)
                            } label: {
                                Label(action.title, systemImage: action.symbolName)
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(GlideGradientButtonStyle(prominence: .standard, minHeight: 40))
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section("Prompt") {
                    TextEditor(text: $model.aiPromptText)
                        .font(.system(size: 13, weight: .regular, design: .monospaced))
                        .frame(minHeight: 210)
                        .scrollContentBackground(.hidden)
                        .padding(8)
                        .background(theme.color(.field), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(theme.color(.border).opacity(0.7), lineWidth: 1)
                        }

                    if model.aiStatusMessage.isEmpty == false {
                        Label(model.aiStatusMessage, systemImage: "info.circle")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(theme.color(.mutedText))
                    }

                    Button {
                        model.copyAIPrompt()
                    } label: {
                        Label("Copy Prompt", systemImage: "doc.on.doc")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(GlideGradientButtonStyle(prominence: .primary, minHeight: 42))
                }

                Section("Send To") {
                    ForEach(AIAssistant.allCases) { assistant in
                        Button {
                            model.openAIAssistantWithPrompt(assistant)
                            dismiss()
                        } label: {
                            Label(assistant.title, systemImage: assistant.symbolName)
                        }
                    }

                    if model.localAIURLText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
                        Button {
                            model.copyAIPrompt()
                            model.openLocalAI()
                            dismiss()
                        } label: {
                            Label(model.localAIName, systemImage: "desktopcomputer")
                        }
                    }

                    Button {
                        dismiss()
                        model.isLocalAIImporterPresented = true
                    } label: {
                        Label("Configure Local AI", systemImage: "square.and.arrow.down")
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(theme.color(.canvas))
            .foregroundStyle(theme.color(.text))
            .navigationTitle("Glide AI")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                if model.aiPromptText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    model.prepareAI(.summarize)
                }
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
            if model.isPrivateModeEnabled == false {
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
                    .background(ButtonGradientBackground(cornerRadius: 8, prominence: .primary))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(theme.color(.border).opacity(0.45), lineWidth: 1)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("New Tab")
            }

            Button {
                model.openPrivateTab()
            } label: {
                HStack(spacing: 8) {
                    BrowserIcon(slot: .privateTab, systemName: "theatermasks", size: 15, weight: .semibold)
                        .frame(width: 24, height: 24)
                    if model.isPrivateModeEnabled {
                        Text("New Private Tab")
                            .font(.system(size: 14, weight: .bold))
                            .lineLimit(1)
                    }
                }
                .padding(.horizontal, model.isPrivateModeEnabled ? 12 : 0)
                .frame(width: model.isPrivateModeEnabled ? (layout == .strip ? 176 : nil) : 44, height: 44)
                .frame(maxWidth: model.isPrivateModeEnabled && layout == .sidebar ? .infinity : nil)
                .foregroundStyle(theme.chromeForegroundColor)
                .background(ControlGlassBackground(cornerRadius: 8))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(theme.color(.privateAccent).opacity(0.55), lineWidth: 1)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("New Private Tab")

            if model.isPrivateModeEnabled == false {
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
}

private struct EssentialsSection: View {
    @EnvironmentObject private var model: BrowserViewModel
    @EnvironmentObject private var theme: BrowserTheme

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                BrowserIcon(slot: .essentials, systemName: "pin.fill", size: 12, weight: .black)
                    .frame(width: 16, height: 16)
                Text("ESSENTIALS")
                    .font(.caption2.weight(.bold))
                Spacer(minLength: 0)
                Text("\(model.visibleEssentials.count)")
                    .font(.system(size: 10, weight: .black))
                    .foregroundStyle(theme.color(.canvas))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(ButtonGradientBackground(cornerRadius: 5, prominence: .primary))

                if let currentTab = model.selectedTab, currentTab.isPrivate == false {
                    Button {
                        model.addEssential(from: currentTab)
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 10, weight: .black))
                            .frame(width: 22, height: 22)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(theme.color(.text))
                    .background(ControlGlassBackground(cornerRadius: 6))
                    .accessibilityLabel("Add current tab to Essentials")
                }
            }
            .foregroundStyle(theme.color(.mutedText))
            .padding(.horizontal, 4)

            if model.visibleEssentials.isEmpty {
                Button {
                    if let currentTab = model.selectedTab {
                        model.addEssential(from: currentTab)
                    }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(theme.color(.accent))

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Add current tab")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(theme.color(.text))
                            Text("Pin it here for quick access")
                                .font(.caption2)
                                .foregroundStyle(theme.color(.mutedText))
                        }

                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 10)
                    .frame(height: 48)
                    .frame(maxWidth: .infinity)
                    .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(model.selectedTab?.isPrivate != false)
                .background(ControlGlassBackground(cornerRadius: 8))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(theme.color(.border).opacity(0.45), lineWidth: 1)
                }
            } else {
                ForEach(model.visibleEssentials) { item in
                    EssentialPill(item: item, layout: .vertical)
                }
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
                BrowserIcon(slot: .essentials, systemName: "pin.fill", size: 12, weight: .bold)
                    .frame(width: 28, height: 28)
                    .foregroundStyle(theme.color(.canvas))
                    .background(ButtonGradientBackground(cornerRadius: 7, prominence: .primary))

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
            Button {
                model.openEssentialInNewTab(item)
            } label: {
                Label("Open in New Tab", systemImage: "plus.square.on.square")
            }

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
                        PrivateRedactedText(text: tab.title, isPrivate: tab.isPrivate, minWidth: 78, maxWidth: layout == .horizontal ? 130 : 150, height: 10)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(theme.color(.text))
                            .lineLimit(1)

                        if layout == .vertical {
                            HStack(spacing: 5) {
                                if tab.usesDevWebKitProfile {
                                    Image(systemName: "hammer")
                                        .font(.caption2.weight(.bold))
                                        .foregroundStyle(theme.color(.createTab))
                                }
                                PrivateRedactedText(text: subtitle, isPrivate: tab.isPrivate, minWidth: 64, maxWidth: 130, height: 8)
                                    .font(.caption2)
                                    .foregroundStyle(theme.color(.mutedText))
                                    .lineLimit(1)
                            }
                        } else if let folderName = model.folderName(for: tab) {
                            Label(folderName, systemImage: "folder")
                                .font(.system(size: 9, weight: .bold))
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
        .background {
            if isSelected {
                ButtonGradientBackground(cornerRadius: 8, prominence: .quiet)
            }
        }
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

                if model.tabFolders.isEmpty == false {
                    Menu {
                        ForEach(model.tabFolders) { folder in
                            Button {
                                model.assign(tab, to: folder)
                            } label: {
                                Label(folder.name, systemImage: "folder")
                            }
                        }
                    } label: {
                        Label("Move to Folder", systemImage: "folder")
                    }
                }

                Button {
                    model.createFolder(from: tab)
                } label: {
                    Label("New Folder from Tab", systemImage: "folder.badge.plus")
                }

                if tab.folderID != nil {
                    Button {
                        model.removeFromFolder(tab)
                    } label: {
                        Label("Remove from Folder", systemImage: "folder.badge.minus")
                    }
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
            if model.isPrivateModeEnabled {
                Button {
                    model.openPrivateTab()
                } label: {
                    Label("New Private Tab", systemImage: "theatermasks")
                }
            } else {
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
            }

            Divider()

            ForEach(model.chromeTabs) { tab in
                Button {
                    model.select(tab)
                } label: {
                    HStack {
                        Image(systemName: tab.isPrivate ? "lock.shield" : "globe")
                        PrivateRedactedText(text: tab.title, isPrivate: tab.isPrivate, minWidth: 78, maxWidth: 180, height: 10)
                    }
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
                Text("\(model.chromeTabs.count)")
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
               let video = theme.userBackgroundVideo {
                LoopingBackgroundVideo(data: video.data, contentTypeIdentifier: video.contentType)
                    .ignoresSafeArea()
                theme.color(.canvas)
                    .opacity(0.38)
                    .ignoresSafeArea()
            } else if theme.isUserBackgroundEnabled,
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
                    ] + theme.gradientColors(for: .chrome) + theme.customGradientColors.map { $0.opacity(0.72) } + [
                        theme.color(.canvas)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
            }
        }
    }
}

private struct LoopingBackgroundVideo: UIViewRepresentable {
    let data: Data
    let contentTypeIdentifier: String?

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> BackgroundVideoPlayerView {
        let view = BackgroundVideoPlayerView()
        context.coordinator.configure(view: view, data: data, contentTypeIdentifier: contentTypeIdentifier)
        return view
    }

    func updateUIView(_ uiView: BackgroundVideoPlayerView, context: Context) {
        context.coordinator.configure(view: uiView, data: data, contentTypeIdentifier: contentTypeIdentifier)
    }

    static func dismantleUIView(_ uiView: BackgroundVideoPlayerView, coordinator: Coordinator) {
        coordinator.stop()
    }

    final class Coordinator {
        private var signature = ""
        private var player: AVQueuePlayer?
        private var looper: AVPlayerLooper?
        private var loader: BackgroundVideoResourceLoader?
        private var loaderQueue: DispatchQueue?

        func configure(view: BackgroundVideoPlayerView, data: Data, contentTypeIdentifier: String?) {
            let newSignature = "\(data.count)-\(Array(data.prefix(32)).hashValue)-\(Array(data.suffix(32)).hashValue)-\(contentTypeIdentifier ?? "video")"
            guard newSignature != signature else {
                player?.play()
                return
            }

            stop()
            signature = newSignature

            let contentType = contentTypeIdentifier ?? UTType.mpeg4Movie.identifier
            let loader = BackgroundVideoResourceLoader(data: data, contentTypeIdentifier: contentType)
            let loaderQueue = DispatchQueue(label: "com.exlon360.glide.background-video.\(UUID().uuidString)")
            let asset = AVURLAsset(url: URL(string: "glide-background-video://background/\(UUID().uuidString)")!)
            asset.resourceLoader.setDelegate(loader, queue: loaderQueue)

            let item = AVPlayerItem(asset: asset)
            let player = AVQueuePlayer()
            player.isMuted = true
            player.actionAtItemEnd = .none
            player.allowsExternalPlayback = false
            player.preventsDisplaySleepDuringVideoPlayback = false

            self.loader = loader
            self.loaderQueue = loaderQueue
            self.player = player
            self.looper = AVPlayerLooper(player: player, templateItem: item)
            view.playerLayer.player = player
            view.playerLayer.videoGravity = .resizeAspectFill
            player.play()
        }

        func stop() {
            player?.pause()
            player = nil
            looper = nil
            loader = nil
            loaderQueue = nil
            signature = ""
        }
    }
}

private final class BackgroundVideoPlayerView: UIView {
    override static var layerClass: AnyClass {
        AVPlayerLayer.self
    }

    var playerLayer: AVPlayerLayer {
        layer as! AVPlayerLayer
    }
}

private final class BackgroundVideoResourceLoader: NSObject, AVAssetResourceLoaderDelegate {
    private let data: Data
    private let contentTypeIdentifier: String

    init(data: Data, contentTypeIdentifier: String) {
        self.data = data
        self.contentTypeIdentifier = contentTypeIdentifier
    }

    func resourceLoader(
        _ resourceLoader: AVAssetResourceLoader,
        shouldWaitForLoadingOfRequestedResource loadingRequest: AVAssetResourceLoadingRequest
    ) -> Bool {
        if let informationRequest = loadingRequest.contentInformationRequest {
            informationRequest.contentType = contentTypeIdentifier
            informationRequest.contentLength = Int64(data.count)
            informationRequest.isByteRangeAccessSupported = true
        }

        if let dataRequest = loadingRequest.dataRequest {
            let requestedOffset = dataRequest.currentOffset != 0 ? dataRequest.currentOffset : dataRequest.requestedOffset
            guard requestedOffset >= 0, requestedOffset < Int64(data.count) else {
                loadingRequest.finishLoading()
                return true
            }

            let start = Int(requestedOffset)
            let end = min(start + dataRequest.requestedLength, data.count)
            if start < end {
                dataRequest.respond(with: data.subdata(in: start..<end))
            }
        }

        loadingRequest.finishLoading()
        return true
    }
}

private struct BrowserSettingsView: View {
    @EnvironmentObject private var model: BrowserViewModel
    @EnvironmentObject private var theme: BrowserTheme
    @EnvironmentObject private var security: AppSecurityModel
    @EnvironmentObject private var profiles: BrowserProfileManager
    @Environment(\.dismiss) private var dismiss
    let currentExperience: GlideDeviceExperience
    @State private var isBackgroundImporterPresented = false
    @State private var isThemeImporterPresented = false
    @State private var isDeveloperModeWarningPresented = false
    @State private var themeExportItem: ThemeExportItem?
    @State private var themeImportMessage = ""
    @State private var savedThemeName = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Privacy") {
                    DisclosureGroup {
                        Toggle("Shields", isOn: adBlockerBinding)
                        Picker("Tracker blocking", selection: $model.trackerBlockingLevel) {
                            ForEach(BrowserTrackerBlockingLevel.allCases) { level in
                                Text(level.title)
                                    .tag(level)
                            }
                        }
                        .disabled(model.isAdBlockerEnabled == false)
                        Toggle("Upgrade connections to HTTPS", isOn: $model.isHTTPSUpgradeEnabled)
                        Toggle("Block scripts", isOn: $model.isScriptBlockingEnabled)
                        Toggle("Fingerprint protection", isOn: $model.isFingerprintProtectionEnabled)
                        Toggle("Block social trackers", isOn: $model.isSocialBlockingEnabled)
                        Toggle("Block pop-up ads", isOn: $model.isPopupBlockingEnabled)
                        Toggle("Strip tracking links", isOn: $model.isTrackingParameterStrippingEnabled)
                        Toggle("Block bounce tracking", isOn: $model.isBounceTrackingProtectionEnabled)
                        Toggle("Protect WebRTC IP", isOn: $model.isWebRTCProtectionEnabled)
                        Label("Never experience an ad again", systemImage: "shield.checkered")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(theme.color(.accent))

                        Button {
                            model.enableGlideMaxProtection()
                        } label: {
                            Label("Enable Glide Shields Max", systemImage: "shield.lefthalf.filled")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(GlideGradientButtonStyle(prominence: .primary, minHeight: 42))

                        Button {
                            model.enableGlideGhostMode()
                        } label: {
                            Label("Enable Ghost Mode", systemImage: "eye.slash")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(GlideGradientButtonStyle(prominence: .standard, minHeight: 42))

                        Button {
                            presentAfterDismiss {
                                model.isPasswordManagerPresented = true
                            }
                        } label: {
                            Label("Password Manager", systemImage: "key.fill")
                        }

                        Button {
                            model.clearPrivateBrowsingData()
                            security.clearCrashLogs()
                        } label: {
                            Label("Clear Private Data", systemImage: "trash")
                        }

                        if model.privacyStatusMessage.isEmpty == false {
                            Label(model.privacyStatusMessage, systemImage: "checkmark.shield")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(theme.color(.mutedText))
                        }
                    } label: {
                        Label("Privacy", systemImage: "hand.raised.fill")
                    }
                }

                Section("Customization Hub") {
                    DisclosureGroup {
                        ProfileCustomizationPanel()
                        WebsiteResolutionControl()
                        QuickColorStudio()

                        Button {
                            model.isFeatureUpdatePresented = true
                        } label: {
                            Label("Show New Features", systemImage: "sparkles")
                        }
                    } label: {
                        Label("Gliders & Displays", systemImage: "wand.and.stars.inverse")
                    }
                }

                Section("Region Tricks") {
                    DisclosureGroup {
                        Toggle("Enable Region Tricks", isOn: $model.isRegionTricksEnabled)

                        Picker("Browsing region", selection: $model.regionTrickProfile) {
                            ForEach(BrowserRegionTrickProfile.allCases) { profile in
                                Label(profile.title, systemImage: profile.symbolName)
                                    .tag(profile)
                            }
                        }
                        .disabled(model.isRegionTricksEnabled == false)

                        LabeledContent("Browser thinks") {
                            Label(model.regionTrickProfile.title, systemImage: model.regionTrickProfile.symbolName)
                                .foregroundStyle(model.isRegionTricksEnabled ? theme.color(.accent) : theme.color(.mutedText))
                        }

                        LabeledContent("Location APIs") {
                            Text(model.regionTrickProfile.countryCode)
                                .foregroundStyle(theme.color(.mutedText))
                        }

                        LabeledContent("Timezone") {
                            Text(model.regionTrickProfile.timeZoneIdentifier)
                                .foregroundStyle(theme.color(.mutedText))
                        }

                        LabeledContent("Currency") {
                            Text(model.regionTrickProfile.currencyCode)
                                .foregroundStyle(theme.color(.mutedText))
                        }

                        LabeledContent("Signals") {
                            Text("Location, time, Intl, requests")
                                .foregroundStyle(theme.color(.mutedText))
                        }

                        Label("Not a VPN", systemImage: "network.slash")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(theme.color(.mutedText))
                    } label: {
                        Label("Region Tricks", systemImage: "globe")
                    }
                }

                Section("Browsing") {
                    DisclosureGroup {
                    LabeledContent("Experience") {
                        Label(displayedExperience.title, systemImage: displayedExperience.symbolName)
                            .foregroundStyle(theme.color(.mutedText))
                    }
                    Toggle("Dark Reader style pages", isOn: darkReaderBinding)
                    if model.isDarkReaderEnabled {
                        Picker("Dark Reader theme", selection: $model.darkReaderTheme) {
                            ForEach(BrowserDarkReaderTheme.allCases) { readerTheme in
                                Label(readerTheme.title, systemImage: readerTheme.symbolName)
                                    .tag(readerTheme)
                            }
                        }
                    }
                    Button {
                        model.setDarkReaderEnabled(true)
                        model.setDarkReaderTheme(.catppuccinMochaDark)
                    } label: {
                        Label("Use Catppuccin Dark", systemImage: BrowserDarkReaderTheme.catppuccinMochaDark.symbolName)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(GlideGradientButtonStyle(prominence: .primary, minHeight: 42))
                    Toggle("Stylus Catppuccin styles", isOn: stylusCatppuccinBinding)
                    Toggle("FPS forcer", isOn: fpsForcerBinding)
                    if model.isFPSForcerEnabled {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Target FPS")
                                Spacer()
                                Text(model.forcedFPSLabel)
                                    .foregroundStyle(theme.color(.mutedText))
                            }
                            Slider(
                                value: Binding(
                                    get: { model.forcedFPS },
                                    set: { model.setForcedFPS($0) }
                                ),
                                in: BrowserViewModel.minimumForcedFPS...BrowserViewModel.infiniteForcedFPSValue,
                                step: 1
                            )
                        }
                    }
                    Toggle("Block ads and trackers", isOn: adBlockerBinding)
                    Toggle("Hide tab bar", isOn: $model.areSideTabsCollapsed)
                    Button {
                        model.enterFullscreenBrowsing()
                    } label: {
                        Label("Use Fullscreen Websites", systemImage: "arrow.down.right.and.arrow.up.left")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(GlideGradientButtonStyle(prominence: .primary, minHeight: 42))
                    if BrowserViewModel.supportsDesktopZenMode {
                        Toggle("Desktop Zen Mode", isOn: desktopZenModeBinding)
                    }
                    Toggle("Open search on new tab", isOn: $model.newTabOpensSearch)
                    Toggle("Top search bar", isOn: $model.isTopSearchBarEnabled)
                    if model.isTopSearchBarEnabled || model.isDesktopZenModeEnabled {
                        Picker("Search bar position", selection: topSearchBarPlacementBinding) {
                            ForEach(BrowserTopSearchBarPlacement.allCases) { placement in
                                Label(placement.title, systemImage: placement.symbolName)
                                    .tag(placement)
                            }
                        }

                        Button {
                            presentAfterDismiss {
                                model.beginTopSearchBarMove()
                            }
                        } label: {
                            Label("Move Top Search Bar", systemImage: "hand.draw")
                        }

                        Button {
                            model.setTopSearchBarPlacement(.top)
                        } label: {
                            Label("Reset Top Search Bar", systemImage: "arrow.counterclockwise")
                        }
                    }
                    DisclosureGroup {
                        Toggle("Auto compact after iPhone search", isOn: $model.autoCompactAfterSearchOnPhone)
                        Toggle("Hide quick buttons in compact", isOn: $model.compactModeHidesQuickControls)
                        Toggle("Hide top search bar in compact", isOn: $model.compactModeHidesTopSearchBar)
                        Toggle("Show top search bar on reveal", isOn: $model.compactModeRevealsTopSearchBar)
                        Toggle("Two-finger double tap on iPad", isOn: $model.isTwoFingerDoubleTapCompactEnabledOnIPad)

                        Button {
                            presentAfterDismiss {
                                model.beginPageControlsMove()
                            }
                        } label: {
                            Label("Move Reveal Arrow", systemImage: "arrow.up.left.and.arrow.down.right")
                        }

                        Button {
                            model.resetPageControlsPosition()
                        } label: {
                            Label("Reset Reveal Arrow", systemImage: "arrow.counterclockwise")
                        }

                        Button {
                            model.toggleCompactMode()
                        } label: {
                            Label(model.isCompactModeActive ? "Reveal Chrome" : "Enter Compact Mode", systemImage: model.isCompactModeActive ? "arrow.up.left.and.arrow.down.right" : "arrow.down.right.and.arrow.up.left")
                        }
                    } label: {
                        Label("Compact Mode", systemImage: "arrow.down.right.and.arrow.up.left")
                    }
                    Picker("Chrome placement", selection: $model.chromePlacement) {
                        ForEach(BrowserChromePlacement.allCases) { placement in
                            Label(placement.title, systemImage: placement.symbolName)
                                .tag(placement)
                        }
                    }
                    Button {
                        presentAfterDismiss {
                            model.beginChromeWidthResize()
                        }
                    } label: {
                        Label("Drag Chrome Width", systemImage: "arrow.left.and.right")
                    }

                    Picker("Search engine", selection: $model.searchEngine) {
                        ForEach(BrowserSearchEngine.allCases) { engine in
                            Text(engine.title)
                                .tag(engine)
                        }
                    }

                    Picker("Website mode", selection: websiteDisplayModeBinding) {
                        ForEach(BrowserWebsiteDisplayMode.allCases) { mode in
                            Label(mode.title, systemImage: mode.symbolName)
                                .tag(mode)
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

                    Button("Tab Folders") {
                        presentAfterDismiss {
                            model.isTabFoldersPresented = true
                        }
                    }
                    } label: {
                        Label("Browsing", systemImage: "safari")
                    }
                }

                Section {
                    DisclosureGroup {
                    Toggle("Show sidebar tabs", isOn: sidebarTabsVisibleBinding)

                    Picker("Sidebar side", selection: sidebarChromePlacementBinding) {
                        Label("Left", systemImage: "sidebar.left")
                            .tag(BrowserChromePlacement.left)
                        Label("Right", systemImage: "sidebar.right")
                            .tag(BrowserChromePlacement.right)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Sidebar width")
                            Spacer()
                            Text("\(Int(model.sideChromeWidthFraction * 100))%")
                                .foregroundStyle(theme.color(.mutedText))
                        }
                        Slider(value: sidebarWidthBinding, in: 0.22...0.46, step: 0.01)
                    }

                    Toggle("Top search bar", isOn: $model.isTopSearchBarEnabled)

                    Button {
                        presentAfterDismiss {
                            model.beginChromeWidthResize()
                        }
                    } label: {
                        Label("Drag Sidebar Width", systemImage: "arrow.left.and.right")
                    }

                    Button {
                        presentAfterDismiss {
                            model.isCustomIconsPresented = true
                        }
                    } label: {
                        Label("Customize Icons", systemImage: "app.badge")
                    }
                    } label: {
                        Label("Sidebar Tabs", systemImage: "sidebar.left")
                    }
                }

                Section {
                    DisclosureGroup {
                        LabeledContent("Saved files") {
                            Text("\(model.downloads.count)")
                                .foregroundStyle(theme.color(.mutedText))
                        }

                        Button {
                            model.downloadSelectedTab()
                        } label: {
                            Label("Download Current Tab", systemImage: "arrow.down.doc")
                        }

                        Button {
                            presentAfterDismiss {
                                model.isDownloadsPresented = true
                            }
                        } label: {
                            Label("Open Downloads", systemImage: "folder")
                        }

                        Button(role: .destructive) {
                            model.clearDownloads()
                        } label: {
                            Label("Clear Downloads", systemImage: "trash")
                        }
                        .disabled(model.downloads.isEmpty)
                    } label: {
                        Label("Downloads", systemImage: "arrow.down.circle")
                    }
                }

                Section {
                    DisclosureGroup {
                    Toggle("Dark Reader", isOn: darkReaderBinding)
                    Toggle("Stylus Catppuccin", isOn: stylusCatppuccinBinding)
                    Toggle("FPS forcer", isOn: fpsForcerBinding)
                    Toggle("Open search on new tab", isOn: $model.newTabOpensSearch)

                    Button {
                        model.setDarkReaderEnabled(true)
                        model.setDarkReaderTheme(.catppuccinMochaDark)
                    } label: {
                        Label("Catppuccin Dark Reader", systemImage: BrowserDarkReaderTheme.catppuccinMochaDark.symbolName)
                    }

                    Button {
                        presentAfterDismiss {
                            model.isTabFoldersPresented = true
                        }
                    } label: {
                        Label("Tab Folders", systemImage: "folder")
                    }

                    Button {
                        presentAfterDismiss {
                            model.isAdvancedConfigPresented = true
                        }
                    } label: {
                        Label("Config Mods", systemImage: "curlybraces")
                    }

                    Button {
                        presentAfterDismiss {
                            model.isCustomIconsPresented = true
                        }
                    } label: {
                        Label("Icon Mods", systemImage: "app.badge")
                    }
                    } label: {
                        Label("Glide Mods", systemImage: "sparkles.rectangle.stack")
                    }
                }

                Section {
                    DisclosureGroup {
                    Toggle("Dev Mode", isOn: developerModeBinding)

                    if model.isDeveloperModeEnabled {
                        Picker("Change Experience", selection: deviceExperienceOverrideBinding) {
                            ForEach(BrowserDeviceExperienceOverride.allCases) { experience in
                                Label(experience.title, systemImage: experience.symbolName)
                                    .tag(experience)
                            }
                        }

                        LabeledContent("Active Experience") {
                            Label(displayedExperience.title, systemImage: displayedExperience.symbolName)
                                .foregroundStyle(theme.color(.mutedText))
                        }

                        Toggle("Web Inspector", isOn: webInspectorBinding)
                        Toggle("Use Dev WebKit for new tabs", isOn: devWebKitBinding)

                        LabeledContent("Engine") {
                            Text(model.isDevWebKitEnabled ? "Dev WebKit" : "WKWebView")
                                .foregroundStyle(theme.color(.mutedText))
                        }

                        LabeledContent("Shields") {
                            Text(model.isAdBlockerEnabled ? "Ad blocker active" : "Ad blocker off")
                                .foregroundStyle(theme.color(.mutedText))
                        }

                        TextField("Alternative engine bundle ID", text: $model.devCustomEngineIdentifier)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .disabled(true)

                        Button {
                            model.openDevWebKitTab()
                        } label: {
                            Label("New Dev WebKit Tab", systemImage: "hammer")
                        }

                        Button {
                            model.requestWKEscapeMode()
                        } label: {
                            Label("Engine Escape Notes", systemImage: "escape")
                        }

                        if model.devModeStatusMessage.isEmpty == false {
                            Label(model.devModeStatusMessage, systemImage: "exclamationmark.triangle")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(theme.color(.mutedText))
                        }
                    }
                    } label: {
                        Label("Dev Mode", systemImage: "hammer")
                    }
                }

                Section {
                    DisclosureGroup {
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
                    } label: {
                        Label("Advanced", systemImage: "slider.horizontal.3")
                    }
                }

                Section("Three-Dot Menu") {
                    DisclosureGroup {
                    ThreeDotMenuCustomizationPanel()
                    } label: {
                        Label("Three-Dot Menu", systemImage: "ellipsis.circle")
                    }
                }

                Section {
                    DisclosureGroup {
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
                    } label: {
                        Label("Privacy Lock", systemImage: "lock.shield")
                    }
                }

                Section {
                    DisclosureGroup {
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
                    } label: {
                        Label("Safety", systemImage: "waveform.path.ecg.rectangle")
                    }
                }

                Section {
                    DisclosureGroup {
                    Toggle("Transparent tab bar", isOn: $theme.isTabBarTransparencyEnabled)

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Transparency")
                            Spacer()
                            Text("\(Int(theme.tabBarTransparency * 100))%")
                                .foregroundStyle(theme.color(.mutedText))
                        }
                        Slider(value: $theme.tabBarTransparency, in: 0...1.0)
                            .disabled(theme.isTabBarTransparencyEnabled == false)
                    }

                    Toggle("Use custom background", isOn: $theme.isUserBackgroundEnabled)
                        .disabled(theme.hasUserBackground == false)

                    if theme.isUserBackgroundEnabled,
                       let image = theme.userBackgroundImage {
                        ZStack(alignment: .bottomLeading) {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                            if let duration = theme.userBackgroundVideoDurationLabel {
                                Label(duration, systemImage: "play.rectangle.fill")
                                    .font(.caption.weight(.bold))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(.ultraThinMaterial, in: Capsule())
                                    .padding(10)
                            }
                        }
                        .frame(height: 92)
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(theme.color(.border).opacity(0.75), lineWidth: 1)
                        }
                    }

                    if theme.backgroundImportMessage.isEmpty == false {
                        Text(theme.backgroundImportMessage)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(theme.color(.mutedText))
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
                    } label: {
                        Label("Customizing", systemImage: "paintpalette")
                    }
                }

                Section {
                    DisclosureGroup {
                        ForEach(BrowserThemeToken.allCases) { token in
                            ThemeColorGradientMenu(token: token)
                        }

                        CustomColorStopsEditor()

                        Button("Reset to Zen dark defaults") {
                            theme.resetToZenDefaults()
                        }
                    } label: {
                        Label("Colors", systemImage: "eyedropper")
                    }
                }

                Section {
                    DisclosureGroup {
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
                        .buttonStyle(GlideGradientButtonStyle(prominence: .standard))

                        Button {
                            isThemeImporterPresented = true
                        } label: {
                            Label("Import from Files", systemImage: "square.and.arrow.down")
                        }
                        .buttonStyle(GlideGradientButtonStyle(prominence: .standard))
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
                                .buttonStyle(GlideGradientButtonStyle(prominence: .standard))

                                Button("Apply") {
                                    theme.applySavedTheme(savedTheme)
                                }
                                .buttonStyle(GlideGradientButtonStyle(prominence: .standard))

                                Button(role: .destructive) {
                                    theme.deleteSavedTheme(savedTheme)
                                } label: {
                                    Image(systemName: "trash")
                                }
                                .buttonStyle(GlideGradientButtonStyle(prominence: .standard))
                                .accessibilityLabel("Delete \(savedTheme.name)")
                            }
                        }
                    }
                    } label: {
                        Label("Saved Themes", systemImage: "square.stack.3d.up")
                    }
                }

                Section {
                    DisclosureGroup {
                    Button {
                        model.resetPrivacySettings()
                    } label: {
                        Label("Reset Privacy", systemImage: "hand.raised")
                    }

                    Button {
                        theme.resetToZenDefaults()
                    } label: {
                        Label("Reset Colors and Background", systemImage: "eyedropper")
                    }

                    Button {
                        model.resetLayoutSettings()
                    } label: {
                        Label("Reset Layout", systemImage: "rectangle.split.2x1")
                    }

                    Button {
                        model.resetBrowsingSettings()
                    } label: {
                        Label("Reset Browsing", systemImage: "safari")
                    }

                    Button {
                        model.resetGlideMods()
                    } label: {
                        Label("Reset Glide Mods", systemImage: "sparkles.rectangle.stack")
                    }

                    Button {
                        model.resetFolders()
                    } label: {
                        Label("Reset Folders", systemImage: "folder.badge.minus")
                    }

                    Button {
                        model.resetCustomIcons()
                    } label: {
                        Label("Reset Icons", systemImage: "app.badge")
                    }

                    Button("Reset Everything") {
                        model.resetToDefaults()
                        theme.resetToZenDefaults()
                    }
                    } label: {
                        Label("Reset", systemImage: "arrow.counterclockwise")
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
                allowedContentTypes: [.image, .movie, .video],
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
            .alert("Warning: Dev Mode", isPresented: $isDeveloperModeWarningPresented) {
                Button("Cancel", role: .cancel) {}
                Button("Enable Dev Mode") {
                    model.setDeveloperModeEnabled(true)
                }
            } message: {
                Text("This is Dev Mode. This can make your browsing experience lag and harder to use.")
            }
        }
    }

    private var displayedExperience: GlideDeviceExperience {
        guard model.isDeveloperModeEnabled else {
            return currentExperience
        }

        switch model.deviceExperienceOverride {
        case .automatic:
            return currentExperience
        case .phone:
            return .phone
        case .iPad:
            return .iPad
        }
    }

    private var darkReaderBinding: Binding<Bool> {
        Binding(
            get: { model.isDarkReaderEnabled },
            set: { model.setDarkReaderEnabled($0) }
        )
    }

    private var stylusCatppuccinBinding: Binding<Bool> {
        Binding(
            get: { model.isStylusCatppuccinEnabled },
            set: { model.setStylusCatppuccinEnabled($0) }
        )
    }

    private var fpsForcerBinding: Binding<Bool> {
        Binding(
            get: { model.isFPSForcerEnabled },
            set: { model.setFPSForcerEnabled($0) }
        )
    }

    private var adBlockerBinding: Binding<Bool> {
        Binding(
            get: { model.isAdBlockerEnabled },
            set: { model.setAdBlockerEnabled($0) }
        )
    }

    private var developerModeBinding: Binding<Bool> {
        Binding(
            get: { model.isDeveloperModeEnabled },
            set: { enabled in
                if enabled {
                    isDeveloperModeWarningPresented = true
                } else {
                    model.setDeveloperModeEnabled(false)
                }
            }
        )
    }

    private var webInspectorBinding: Binding<Bool> {
        Binding(
            get: { model.isWebInspectorEnabled },
            set: { model.setWebInspectorEnabled($0) }
        )
    }

    private var devWebKitBinding: Binding<Bool> {
        Binding(
            get: { model.isDevWebKitEnabled },
            set: { model.setDevWebKitEnabled($0) }
        )
    }

    private var websiteDisplayModeBinding: Binding<BrowserWebsiteDisplayMode> {
        Binding(
            get: { model.websiteDisplayMode },
            set: { model.setWebsiteDisplayMode($0) }
        )
    }

    private var desktopZenModeBinding: Binding<Bool> {
        Binding(
            get: { model.isDesktopZenModeEnabled },
            set: { model.setDesktopZenModeEnabled($0) }
        )
    }

    private var topSearchBarPlacementBinding: Binding<BrowserTopSearchBarPlacement> {
        Binding(
            get: { model.topSearchBarPlacement },
            set: { model.setTopSearchBarPlacement($0) }
        )
    }

    private var sidebarTabsVisibleBinding: Binding<Bool> {
        Binding(
            get: { model.areSideTabsCollapsed == false },
            set: { model.setTabBarCollapsed($0 == false) }
        )
    }

    private var sidebarChromePlacementBinding: Binding<BrowserChromePlacement> {
        Binding(
            get: { model.chromePlacement == .right ? .right : .left },
            set: { placement in
                model.chromePlacement = placement
                model.setTabBarCollapsed(false)
            }
        )
    }

    private var sidebarWidthBinding: Binding<Double> {
        Binding(
            get: { model.sideChromeWidthFraction },
            set: { model.sideChromeWidthFraction = $0 }
        )
    }

    private var deviceExperienceOverrideBinding: Binding<BrowserDeviceExperienceOverride> {
        Binding(
            get: { model.deviceExperienceOverride },
            set: { model.setDeviceExperienceOverride($0) }
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
    @State private var isWebExtensionImporterPresented = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Installed Add-ons") {
                    if model.installedWebExtensions.isEmpty {
                        Text("No add-ons installed.")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(theme.color(.mutedText))
                    } else {
                        ForEach(model.installedWebExtensions) { webExtension in
                            VStack(alignment: .leading, spacing: 10) {
                                Toggle(isOn: webExtensionEnabledBinding(for: webExtension)) {
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(webExtension.displayName)
                                            .font(.body.weight(.semibold))
                                            .foregroundStyle(theme.color(.text))
                                        Text(webExtension.detailText)
                                            .font(.caption)
                                            .foregroundStyle(theme.color(.mutedText))
                                    }
                                }

                                Button(role: .destructive) {
                                    model.deleteWebExtension(webExtension.id)
                                } label: {
                                    Label("Remove Add-on", systemImage: "trash")
                                }
                                .buttonStyle(.borderless)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }

                Section("Install") {
                    Button {
                        isWebExtensionImporterPresented = true
                    } label: {
                        Label("Install Add-on / User Script", systemImage: "square.and.arrow.down")
                    }

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
                                    .background(ControlGlassBackground(cornerRadius: 8))

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

                    if model.webExtensionImportMessage.isEmpty == false {
                        Label(
                            model.webExtensionImportMessage,
                            systemImage: model.webExtensionImportMessage.hasPrefix("Installed") || model.webExtensionImportMessage.hasPrefix("Updated")
                                ? "checkmark.circle"
                                : "info.circle"
                        )
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(theme.color(.mutedText))
                    }
                }

                Section("Compatibility") {
                    Text("Glide imports Firefox .xpi, Chrome/Brave .crx, .zip, manifest.json, .user.js, .js, and .css files. Content scripts run best; background scripts use Glide compatibility mode. Native messaging and full desktop-only APIs are not available in the WKWebView build.")
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
            .fileImporter(
                isPresented: $isWebExtensionImporterPresented,
                allowedContentTypes: [.item],
                allowsMultipleSelection: false
            ) { result in
                model.importWebExtension(from: result)
            }
        }
    }

    private func webExtensionEnabledBinding(for webExtension: BrowserWebExtension) -> Binding<Bool> {
        Binding(
            get: {
                model.installedWebExtensions.first(where: { $0.id == webExtension.id })?.isEnabled ?? false
            },
            set: { enabled in
                model.setWebExtension(webExtension.id, enabled: enabled)
            }
        )
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
                    .buttonStyle(GlideGradientButtonStyle(prominence: .standard))

                    Spacer()

                    Button("Apply") {
                        applyConfig(shouldDismiss: false)
                    }
                    .buttonStyle(GlideGradientButtonStyle(prominence: .primary))

                    Button("Save") {
                        applyConfig(shouldDismiss: true)
                    }
                    .buttonStyle(GlideGradientButtonStyle(prominence: .primary))
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
                                    .background(ControlGlassBackground(cornerRadius: 8))
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
                                .buttonStyle(GlideGradientButtonStyle(prominence: .standard))

                                Button("Clear Image") {
                                    model.clearCustomIconImage(for: slot)
                                }
                                .buttonStyle(GlideGradientButtonStyle(prominence: .standard))
                                .disabled(model.hasCustomIconImage(for: slot) == false)

                                Button("Default") {
                                    model.setCustomIconName("", for: slot)
                                    model.clearCustomIconImage(for: slot)
                                }
                                .buttonStyle(GlideGradientButtonStyle(prominence: .standard))
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
