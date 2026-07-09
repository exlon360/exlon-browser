import Combine
import AVFoundation
import Foundation
import UIKit
import WebKit

enum BrowserDefaults {
    static let homeURL = URL(string: "https://glide.local/start")!
    static let containedBrowserStartURL = URL(string: "https://lite.duckduckgo.com/lite/")!
}

enum BrowserWebKitProfile: String, Codable {
    case standard
    case dev

    var title: String {
        switch self {
        case .standard:
            return "WKWebView"
        case .dev:
            return "Dev WebKit"
        }
    }
}

@MainActor
final class BrowserTab: NSObject, Identifiable, ObservableObject {
    let id = UUID()
    let isPrivate: Bool
    let isContainedBrowser: Bool
    let webKitProfile: BrowserWebKitProfile
    let webView: WKWebView

    @Published var title: String
    @Published var url: URL?
    @Published var addressText: String
    @Published var isLoading = false
    @Published var estimatedProgress = 0.0
    @Published var canGoBack = false
    @Published var canGoForward = false
    @Published var isDarkReaderEnabled: Bool
    @Published var darkReaderTheme: BrowserDarkReaderTheme
    @Published var isStylusCatppuccinEnabled: Bool
    @Published var isAdBlockerEnabled: Bool
    @Published var trackerBlockingLevel: BrowserTrackerBlockingLevel
    @Published var isScriptBlockingEnabled: Bool
    @Published var isHTTPSUpgradeEnabled: Bool
    @Published var isFingerprintProtectionEnabled: Bool
    @Published var isSocialBlockingEnabled: Bool
    @Published var isPopupBlockingEnabled: Bool
    @Published var isTrackingParameterStrippingEnabled: Bool
    @Published var isBounceTrackingProtectionEnabled: Bool
    @Published var isWebRTCProtectionEnabled: Bool
    @Published var isRegionTricksEnabled: Bool
    @Published var regionTrickProfile: BrowserRegionTrickProfile
    @Published var isFPSForcerEnabled: Bool
    @Published var forcedFPS: Double
    @Published var websiteResolutionScale: Double
    @Published var websiteDisplayMode: BrowserWebsiteDisplayMode
    @Published var browserResolutionPreset: BrowserResolutionPreset
    @Published var browserResolutionWidth: Double
    @Published var webExtensions: [BrowserWebExtension]
    @Published var folderID: UUID?
    @Published private(set) var pageIconURLString: String?
    @Published private(set) var pageThemeColorHex: String?

    var onNavigationFinished: (@MainActor (BrowserTab) -> Void)?
    var onDownloadUpdated: (@MainActor (BrowserDownloadItem) -> Void)?
    var onTwoFingerSwipe: (@MainActor (CGFloat, CGFloat) -> Void)?
    var onThreeFingerSwipe: (@MainActor (CGFloat) -> Void)?
    var onFilePickerRequested: (@MainActor (Bool, @escaping ([URL]?) -> Void) -> Void)?

    private var observations: [NSKeyValueObservation] = []
    private var activeDownloads: [ObjectIdentifier: BrowserDownloadItem] = [:]
    private static let sharedProcessPool = WKProcessPool()
    private static let devProcessPool = WKProcessPool()
    private static let customPanMinimumDistance: CGFloat = 172
    private static let customPanDirectionRatio: CGFloat = 1.6
    private nonisolated(unsafe) var navigationScriptBlockingEnabled: Bool
    private nonisolated(unsafe) var navigationHTTPSUpgradeEnabled: Bool
    private nonisolated(unsafe) var navigationTrackingParameterStrippingEnabled: Bool
    private nonisolated(unsafe) var navigationBounceTrackingProtectionEnabled: Bool
    private nonisolated(unsafe) var navigationRegionTricksEnabled: Bool
    private nonisolated(unsafe) var navigationRegionTrickProfile: BrowserRegionTrickProfile
    private nonisolated(unsafe) var navigationWebsiteDisplayMode: BrowserWebsiteDisplayMode
    private nonisolated(unsafe) var navigationProtectionWhitelistDomains: [String]
    private var blockedPersistenceDomains: [String]
    private var protectionWhitelistDomains: [String]

    init(
        startURL: URL = BrowserDefaults.homeURL,
        isPrivate: Bool = false,
        usesPersistentStorage: Bool = true,
        isContainedBrowser: Bool = false,
        isDarkReaderEnabled: Bool = false,
        darkReaderTheme: BrowserDarkReaderTheme = .zenCopy,
        isStylusCatppuccinEnabled: Bool = false,
        isAdBlockerEnabled: Bool = true,
        trackerBlockingLevel: BrowserTrackerBlockingLevel = .aggressive,
        isScriptBlockingEnabled: Bool = false,
        isHTTPSUpgradeEnabled: Bool = true,
        isFingerprintProtectionEnabled: Bool = true,
        isSocialBlockingEnabled: Bool = true,
        isPopupBlockingEnabled: Bool = true,
        isTrackingParameterStrippingEnabled: Bool = true,
        isBounceTrackingProtectionEnabled: Bool = true,
        isWebRTCProtectionEnabled: Bool = true,
        isRegionTricksEnabled: Bool = false,
        regionTrickProfile: BrowserRegionTrickProfile = .unitedStates,
        isFPSForcerEnabled: Bool = false,
        forcedFPS: Double = 60,
        websiteResolutionScale: Double = 1.0,
        websiteDisplayMode: BrowserWebsiteDisplayMode = .automatic,
        browserResolutionPreset: BrowserResolutionPreset = .automatic,
        browserResolutionWidth: Double = BrowserResolutionPreset.defaultScreenScale,
        folderID: UUID? = nil,
        webExtensions: [BrowserWebExtension] = [],
        websiteBlacklist: [String] = [],
        websiteProtectionWhitelist: [String] = [],
        webKitProfile: BrowserWebKitProfile = .standard
    ) {
        self.isPrivate = isPrivate
        self.isContainedBrowser = isContainedBrowser
        self.webKitProfile = webKitProfile
        self.isDarkReaderEnabled = isDarkReaderEnabled
        self.darkReaderTheme = darkReaderTheme
        self.isStylusCatppuccinEnabled = isStylusCatppuccinEnabled
        self.isAdBlockerEnabled = isAdBlockerEnabled
        self.trackerBlockingLevel = trackerBlockingLevel
        self.isScriptBlockingEnabled = isScriptBlockingEnabled
        self.isHTTPSUpgradeEnabled = isHTTPSUpgradeEnabled
        self.isFingerprintProtectionEnabled = isFingerprintProtectionEnabled
        self.isSocialBlockingEnabled = isSocialBlockingEnabled
        self.isPopupBlockingEnabled = isPopupBlockingEnabled
        self.isTrackingParameterStrippingEnabled = isTrackingParameterStrippingEnabled
        self.isBounceTrackingProtectionEnabled = isBounceTrackingProtectionEnabled
        self.isWebRTCProtectionEnabled = isWebRTCProtectionEnabled
        self.isRegionTricksEnabled = isRegionTricksEnabled
        self.regionTrickProfile = regionTrickProfile
        self.navigationScriptBlockingEnabled = isScriptBlockingEnabled
        self.navigationHTTPSUpgradeEnabled = isHTTPSUpgradeEnabled
        self.navigationTrackingParameterStrippingEnabled = isTrackingParameterStrippingEnabled
        self.navigationBounceTrackingProtectionEnabled = isBounceTrackingProtectionEnabled
        self.navigationRegionTricksEnabled = isRegionTricksEnabled
        self.navigationRegionTrickProfile = regionTrickProfile
        self.navigationWebsiteDisplayMode = websiteDisplayMode
        self.navigationProtectionWhitelistDomains = BrowserWebsitePrivacyPolicy.normalizedDomains(websiteProtectionWhitelist)
        self.isFPSForcerEnabled = isFPSForcerEnabled
        self.forcedFPS = forcedFPS
        self.websiteResolutionScale = websiteResolutionScale
        self.websiteDisplayMode = websiteDisplayMode
        self.browserResolutionPreset = browserResolutionPreset
        self.browserResolutionWidth = BrowserResolutionPreset.clampedScreenScale(browserResolutionWidth)
        self.webExtensions = webExtensions
        self.folderID = folderID
        self.pageIconURLString = nil
        self.pageThemeColorHex = nil
        self.blockedPersistenceDomains = BrowserWebsitePrivacyPolicy.normalizedDomains(websiteBlacklist)
        self.protectionWhitelistDomains = BrowserWebsitePrivacyPolicy.normalizedDomains(websiteProtectionWhitelist)
        self.title = isContainedBrowser ? "Contained Browser" : (webKitProfile == .dev ? "Dev WebKit" : (isPrivate ? "Private Start" : "Start"))
        self.url = startURL
        self.addressText = startURL.absoluteString

        Self.configureAudioPlayback()

        let configuration = WKWebViewConfiguration()
        configuration.processPool = webKitProfile == .dev ? Self.devProcessPool : Self.sharedProcessPool
        configuration.userContentController = WKUserContentController()
        configuration.allowsInlineMediaPlayback = true
        configuration.allowsAirPlayForMediaPlayback = true
        configuration.allowsPictureInPictureMediaPlayback = true
        configuration.suppressesIncrementalRendering = false
        configuration.mediaTypesRequiringUserActionForPlayback = []
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = true
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        configuration.defaultWebpagePreferences.preferredContentMode = Self.webpageContentMode(for: websiteDisplayMode)
        if #available(iOS 14.0, *) {
            configuration.limitsNavigationsToAppBoundDomains = false
        }
        configuration.websiteDataStore = (isPrivate || usesPersistentStorage == false) ? .nonPersistent() : .default()

        self.webView = WKWebView(frame: .zero, configuration: configuration)
        super.init()

        webView.customUserAgent = Self.userAgent(for: websiteDisplayMode)
        webView.pageZoom = 1.0
        if #available(iOS 16.4, *), webKitProfile == .dev {
            webView.isInspectable = true
        }
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.allowsBackForwardNavigationGestures = true
        webView.allowsLinkPreview = false
        webView.scrollView.keyboardDismissMode = .interactive
        bindWebViewState()
        installGestureControls()

        rebuildWebKitUserContent(reloadAfterChange: false) { [weak self] in
            self?.loadInitialContent(startURL)
        }
    }

    static var homeURL: URL {
        BrowserDefaults.homeURL
    }

    var usesDevWebKitProfile: Bool {
        webKitProfile == .dev
    }

    func load(_ url: URL) {
        let destination = privacyAdjustedURL(for: url)
        if isContainedBrowser == false,
           Self.isStartPageURL(destination) {
            loadStartPage()
            return
        }

        webView.load(Self.websiteRequest(for: destination, regionProfile: activeRegionTrickProfile))
    }

    func submitAddress(searchEngine: BrowserSearchEngine, customSearchTemplate: String) {
        let destination = Self.destinationURL(
            from: addressText,
            searchEngine: searchEngine,
            customSearchTemplate: customSearchTemplate
        )
        addressText = destination.absoluteString
        load(destination)
    }

    func reloadOrStop() {
        if isLoading {
            webView.stopLoading()
        } else {
            webView.reload()
        }
    }

    func goBack() {
        guard webView.canGoBack else { return }
        webView.goBack()
        canGoBack = webView.canGoBack
        canGoForward = webView.canGoForward
    }

    func goForward() {
        guard webView.canGoForward else { return }
        webView.goForward()
        canGoBack = webView.canGoBack
        canGoForward = webView.canGoForward
    }

    func setWebsiteDisplayMode(_ mode: BrowserWebsiteDisplayMode, reloadAfterChange: Bool = true) {
        websiteDisplayMode = mode
        navigationWebsiteDisplayMode = mode
        webView.configuration.defaultWebpagePreferences.preferredContentMode = Self.webpageContentMode(for: mode)
        webView.customUserAgent = Self.userAgent(for: mode)

        guard reloadAfterChange,
              let url,
              Self.isStartPageURL(url) == false,
              ["http", "https"].contains(url.scheme?.lowercased() ?? "") else { return }
        webView.reload()
    }

    func setWebsiteResolutionScale(_ scale: Double) {
        let clamped = Self.clampedWebsiteResolutionScale(scale)
        websiteResolutionScale = clamped
        webView.pageZoom = 1.0
    }

    func setBrowserResolutionPreset(_ preset: BrowserResolutionPreset, reloadAfterChange: Bool = true) {
        let width = preset == .custom ? browserResolutionWidth : preset.screenScale
        setBrowserResolution(preset: preset, width: width, reloadAfterChange: reloadAfterChange)
    }

    func setBrowserResolution(
        preset: BrowserResolutionPreset,
        width: Double,
        reloadAfterChange: Bool = true
    ) {
        let clampedWidth = BrowserResolutionPreset.clampedScreenScale(width)
        guard browserResolutionPreset != preset || browserResolutionWidth != clampedWidth else { return }
        browserResolutionPreset = preset
        browserResolutionWidth = clampedWidth
        rebuildWebKitUserContent(reloadAfterChange: reloadAfterChange)
    }

    func fillCredentials(username: String, password: String) {
        webView.evaluateJavaScript(Self.credentialFillScript(username: username, password: password))
    }

    func extractReadablePageText(limit: Int = 4_000, completion: @escaping (String) -> Void) {
        let script = """
        (() => {
          const clone = document.body ? document.body.cloneNode(true) : document.documentElement.cloneNode(true);
          clone.querySelectorAll('script, style, noscript, svg, canvas, iframe, nav, footer, form, input, button, select, textarea').forEach((node) => node.remove());
          const title = document.title || '';
          const meta = document.querySelector('meta[name="description"], meta[property="og:description"]')?.content || '';
          const headings = Array.from(document.querySelectorAll('h1, h2, h3')).map((node) => node.innerText || '').join('\\n');
          const text = [title, meta, headings, clone.innerText || '']
            .join('\\n')
            .replace(/\\s+/g, ' ')
            .trim();
          return text.slice(0, \(limit));
        })();
        """
        webView.evaluateJavaScript(script) { result, _ in
            let text = (result as? String) ?? ""
            Task { @MainActor in
                completion(text)
            }
        }
    }

    func setDarkReaderEnabled(_ enabled: Bool) {
        isDarkReaderEnabled = enabled
        rebuildWebKitUserContent()
        applyPageStyleOverrides(forceCleanup: true)
    }

    func setDarkReaderTheme(_ theme: BrowserDarkReaderTheme) {
        darkReaderTheme = theme
        rebuildWebKitUserContent()
        applyPageStyleOverrides(forceCleanup: true)
    }

    func setStylusCatppuccinEnabled(_ enabled: Bool) {
        isStylusCatppuccinEnabled = enabled
        rebuildWebKitUserContent()
        applyPageStyleOverrides(forceCleanup: true)
    }

    func setFPSForcerEnabled(_ enabled: Bool) {
        isFPSForcerEnabled = enabled
        rebuildWebKitUserContent()
        applyPageStyleOverrides(forceCleanup: true)
    }

    func setForcedFPS(_ fps: Double) {
        forcedFPS = fps
        rebuildWebKitUserContent()
        applyPageStyleOverrides(forceCleanup: true)
    }

    func setWebInspectorEnabled(_ enabled: Bool) {
        if #available(iOS 16.4, *) {
            webView.isInspectable = enabled
        }
    }

    func setAdBlockerEnabled(_ enabled: Bool, reloadAfterChange: Bool = true) {
        isAdBlockerEnabled = enabled
        rebuildWebKitUserContent(reloadAfterChange: reloadAfterChange)
    }

    func setTrackerBlockingLevel(_ level: BrowserTrackerBlockingLevel) {
        trackerBlockingLevel = level
        rebuildWebKitUserContent(reloadAfterChange: true)
    }

    func setScriptBlockingEnabled(_ enabled: Bool) {
        isScriptBlockingEnabled = enabled
        navigationScriptBlockingEnabled = enabled
        rebuildWebKitUserContent(reloadAfterChange: true)
    }

    func setHTTPSUpgradeEnabled(_ enabled: Bool) {
        isHTTPSUpgradeEnabled = enabled
        navigationHTTPSUpgradeEnabled = enabled
    }

    func setFingerprintProtectionEnabled(_ enabled: Bool) {
        isFingerprintProtectionEnabled = enabled
        rebuildWebKitUserContent()
        applyPrivacyOverrides(forceCleanup: true)
    }

    func setSocialBlockingEnabled(_ enabled: Bool) {
        isSocialBlockingEnabled = enabled
        rebuildWebKitUserContent()
        applyPrivacyOverrides(forceCleanup: true)
    }

    func setPopupBlockingEnabled(_ enabled: Bool) {
        isPopupBlockingEnabled = enabled
        rebuildWebKitUserContent()
        applyPrivacyOverrides(forceCleanup: true)
    }

    func setTrackingParameterStrippingEnabled(_ enabled: Bool) {
        isTrackingParameterStrippingEnabled = enabled
        navigationTrackingParameterStrippingEnabled = enabled
    }

    func setBounceTrackingProtectionEnabled(_ enabled: Bool) {
        isBounceTrackingProtectionEnabled = enabled
        navigationBounceTrackingProtectionEnabled = enabled
    }

    func setWebRTCProtectionEnabled(_ enabled: Bool) {
        isWebRTCProtectionEnabled = enabled
        rebuildWebKitUserContent()
        applyPrivacyOverrides(forceCleanup: true)
    }

    func setRegionTricks(enabled: Bool, profile: BrowserRegionTrickProfile) {
        isRegionTricksEnabled = enabled
        regionTrickProfile = profile
        navigationRegionTricksEnabled = enabled
        navigationRegionTrickProfile = profile
        rebuildWebKitUserContent(reloadAfterChange: true)
    }

    func setWebExtensions(_ extensions: [BrowserWebExtension], reloadAfterChange: Bool = true) {
        webExtensions = extensions
        rebuildWebKitUserContent(reloadAfterChange: reloadAfterChange)
    }

    func setWebsiteBlacklist(_ domains: [String]) {
        let normalized = BrowserWebsitePrivacyPolicy.normalizedDomains(domains)
        guard normalized != blockedPersistenceDomains else { return }
        let wasCurrentWebsiteBlocked = BrowserWebsitePrivacyPolicy.matches(
            url: url,
            blockedDomains: blockedPersistenceDomains
        )
        blockedPersistenceDomains = normalized
        let isCurrentWebsiteBlocked = BrowserWebsitePrivacyPolicy.matches(
            url: url,
            blockedDomains: normalized
        )
        rebuildWebKitUserContent(reloadAfterChange: wasCurrentWebsiteBlocked && isCurrentWebsiteBlocked == false)
        if let script = Self.websiteBlacklistScript(for: normalized) {
            webView.evaluateJavaScript(script)
        }
    }

    func setWebsiteProtectionWhitelist(_ domains: [String]) {
        let normalized = BrowserWebsitePrivacyPolicy.normalizedDomains(domains)
        guard normalized != protectionWhitelistDomains else { return }
        let wasCurrentWebsiteWhitelisted = BrowserWebsitePrivacyPolicy.matches(
            url: url,
            blockedDomains: protectionWhitelistDomains
        )
        protectionWhitelistDomains = normalized
        navigationProtectionWhitelistDomains = normalized
        let isCurrentWebsiteWhitelisted = BrowserWebsitePrivacyPolicy.matches(
            url: url,
            blockedDomains: normalized
        )
        rebuildWebKitUserContent(
            reloadAfterChange: wasCurrentWebsiteWhitelisted != isCurrentWebsiteWhitelisted
        )
    }

    private func applyPageStyleOverrides(forceCleanup: Bool = false) {
        guard forceCleanup || hasActivePageStyleOverrides else { return }
        webView.evaluateJavaScript(Self.pageControlsScript(
            darkReaderCSS: activeDarkReaderCSS,
            stylusCSS: activeStylusCSS,
            fpsLimit: activeFPSLimit
        ))
    }

    private func applyPrivacyOverrides(forceCleanup: Bool = false) {
        guard forceCleanup || hasActivePrivacyOverrides else { return }
        webView.evaluateJavaScript(Self.privacyProtectionScript(
            fingerprintProtection: isFingerprintProtectionEnabled,
            socialBlocking: isSocialBlockingEnabled,
            popupBlocking: isPopupBlockingEnabled,
            webRTCProtection: isWebRTCProtectionEnabled
        ))
        applyRegionTricks()
    }

    private func applyRegionTricks() {
        guard let profile = activeRegionTrickProfile else { return }
        webView.evaluateJavaScript(Self.regionTricksScript(profile: profile))
    }

    private func capturePageIdentity(completion: @escaping () -> Void) {
        guard let url,
              Self.isStartPageURL(url) == false,
              ["http", "https"].contains(url.scheme?.lowercased() ?? "") else {
            pageIconURLString = nil
            pageThemeColorHex = nil
            completion()
            return
        }

        let script = """
        (() => {
          const iconLink = Array.from(document.querySelectorAll('link[rel]')).find((node) => {
            const rel = String(node.rel || '').toLowerCase().split(/\\s+/);
            return rel.includes('icon') || rel.includes('apple-touch-icon');
          });
          let faviconURL = '';
          try {
            faviconURL = iconLink?.href || new URL('/favicon.ico', location.origin).href;
          } catch (_) {}

          const toHex = (value) => {
            if (!value) return '';
            const probe = document.createElement('span');
            probe.style.cssText = 'position:fixed;visibility:hidden;pointer-events:none;color:' + value;
            if (!probe.style.color) return '';
            (document.documentElement || document.body).appendChild(probe);
            const resolved = getComputedStyle(probe).color;
            probe.remove();
            const match = resolved.match(/rgba?\\(\\s*([\\d.]+)[,\\s]+([\\d.]+)[,\\s]+([\\d.]+)(?:[,\\s\\/]+([\\d.]+))?/i);
            if (!match || (match[4] !== undefined && Number(match[4]) < 0.08)) return '';
            return '#' + [match[1], match[2], match[3]]
              .map((part) => Math.max(0, Math.min(255, Math.round(Number(part)))).toString(16).padStart(2, '0'))
              .join('')
              .toUpperCase();
          };

          const themeMeta = Array.from(document.querySelectorAll('meta[name="theme-color" i]'))
            .find((node) => !node.media || matchMedia(node.media).matches);
          const candidates = [
            themeMeta?.content,
            document.body ? getComputedStyle(document.body).backgroundColor : '',
            document.documentElement ? getComputedStyle(document.documentElement).backgroundColor : ''
          ];
          let accentColorHex = '';
          for (const candidate of candidates) {
            accentColorHex = toHex(candidate);
            if (accentColorHex) break;
          }
          return { faviconURL, accentColorHex };
        })();
        """

        webView.evaluateJavaScript(script) { [weak self] result, _ in
            Task { @MainActor in
                guard let self else {
                    completion()
                    return
                }
                let values = result as? [String: Any]
                let iconValue = (values?["faviconURL"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
                let colorValue = (values?["accentColorHex"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
                self.pageIconURLString = iconValue?.isEmpty == false ? iconValue : BrowserWebsitePrivacyPolicy.defaultFaviconURL(for: url)?.absoluteString
                self.pageThemeColorHex = colorValue?.range(
                    of: "^#[0-9A-Fa-f]{6}$",
                    options: .regularExpression
                ) != nil ? colorValue : nil
                completion()
            }
        }
    }

    private func privacyAdjustedURL(for url: URL) -> URL {
        let isProtectionWhitelisted = BrowserWebsitePrivacyPolicy.matches(
            url: url,
            blockedDomains: protectionWhitelistDomains
        )
        return Self.privacyAdjustedURL(
            for: url,
            upgradeHTTPS: isHTTPSUpgradeEnabled,
            stripTrackingParameters: isTrackingParameterStrippingEnabled && isProtectionWhitelisted == false,
            blockBounceTracking: isBounceTrackingProtectionEnabled && isProtectionWhitelisted == false
        )
    }

    private func rebuildWebKitUserContent(
        reloadAfterChange: Bool = false,
        completion: (() -> Void)? = nil
    ) {
        BrowserContentBlocker.setEnabled(
            isAdBlockerEnabled,
            level: trackerBlockingLevel,
            on: webView.configuration.userContentController,
            whitelistedDomains: protectionWhitelistDomains,
            additionalUserScripts: additionalUserScripts()
        ) { [weak self] _ in
            guard let self = self else {
                completion?()
                return
            }

            completion?()
            if reloadAfterChange {
                self.webView.reload()
            }
        }
    }

    private func additionalUserScripts() -> [WKUserScript] {
        var scripts: [WKUserScript] = []

        if let blacklistScript = Self.websiteBlacklistScript(for: blockedPersistenceDomains) {
            scripts.append(
                WKUserScript(
                    source: blacklistScript,
                    injectionTime: .atDocumentStart,
                    forMainFrameOnly: false
                )
            )
        }

        if let viewportScript = Self.viewportResolutionScript(for: browserResolutionPreset, width: browserResolutionWidth) {
            scripts.append(
                WKUserScript(
                    source: viewportScript,
                    injectionTime: .atDocumentStart,
                    forMainFrameOnly: false
                )
            )
        }

        if hasActivePageStyleOverrides {
            scripts.append(
                WKUserScript(
                    source: Self.pageControlsScript(
                        darkReaderCSS: activeDarkReaderCSS,
                        stylusCSS: activeStylusCSS,
                        fpsLimit: activeFPSLimit
                    ),
                    injectionTime: .atDocumentStart,
                    forMainFrameOnly: false
                )
            )
        }

        if hasActivePrivacyOverrides {
            scripts.append(
                WKUserScript(
                    source: Self.privacyProtectionScript(
                        fingerprintProtection: isFingerprintProtectionEnabled,
                        socialBlocking: isSocialBlockingEnabled,
                        popupBlocking: isPopupBlockingEnabled,
                        webRTCProtection: isWebRTCProtectionEnabled
                    ),
                    injectionTime: .atDocumentStart,
                    forMainFrameOnly: false
                )
            )
        }

        if let profile = activeRegionTrickProfile {
            scripts.append(
                WKUserScript(
                    source: Self.regionTricksScript(profile: profile),
                    injectionTime: .atDocumentStart,
                    forMainFrameOnly: false
                )
            )
        }

        scripts.append(contentsOf: Self.webExtensionUserScripts(for: webExtensions))

        return scripts
    }

    private static func websiteBlacklistScript(for domains: [String]) -> String? {
        let normalized = BrowserWebsitePrivacyPolicy.normalizedDomains(domains)
        guard normalized.isEmpty == false,
              let data = try? JSONSerialization.data(withJSONObject: normalized),
              let payload = String(data: data, encoding: .utf8) else { return nil }

        return """
        (() => {
          const blockedDomains = \(payload);
          const host = String(location.hostname || '').toLowerCase().replace(/^www\\./, '');
          const isBlocked = blockedDomains.some((domain) => host === domain || host.endsWith(`.${domain}`));
          if (!isBlocked) return;

          const clearStorage = (storage) => {
            try { storage.clear(); } catch (_) {}
          };
          clearStorage(window.localStorage);
          clearStorage(window.sessionStorage);

          try {
            Object.defineProperty(Document.prototype, 'cookie', {
              configurable: true,
              get() { return ''; },
              set(_) { return true; }
            });
          } catch (_) {}

          try {
            const denied = () => undefined;
            Object.defineProperties(Storage.prototype, {
              setItem: { configurable: true, value: denied },
              removeItem: { configurable: true, value: denied },
              clear: { configurable: true, value: denied }
            });
          } catch (_) {}

          try {
            if (window.caches) {
              window.caches.keys().then((keys) => keys.forEach((key) => window.caches.delete(key)));
            }
          } catch (_) {}
        })();
        """
    }

    private func pageControlUserScripts() -> [WKUserScript] {
        guard hasActivePageStyleOverrides else { return [] }
        return [
            WKUserScript(
                source: Self.pageControlsScript(
                    darkReaderCSS: activeDarkReaderCSS,
                    stylusCSS: activeStylusCSS,
                    fpsLimit: activeFPSLimit
                ),
                injectionTime: .atDocumentStart,
                forMainFrameOnly: false
            )
        ]
    }

    private var activeDarkReaderCSS: String {
        isDarkReaderEnabled ? Self.darkReaderCSS(for: darkReaderTheme) : ""
    }

    private var activeStylusCSS: String {
        isStylusCatppuccinEnabled ? Self.stylusCatppuccinCSS() : ""
    }

    private var activeFPSLimit: Double? {
        guard isFPSForcerEnabled,
              forcedFPS < BrowserViewModel.infiniteForcedFPSValue else { return nil }
        return max(BrowserViewModel.minimumForcedFPS, min(BrowserViewModel.maximumFiniteForcedFPS, forcedFPS))
    }

    private var hasActivePageStyleOverrides: Bool {
        isDarkReaderEnabled || isStylusCatppuccinEnabled || activeFPSLimit != nil
    }

    private var hasActivePrivacyOverrides: Bool {
        isFingerprintProtectionEnabled || isSocialBlockingEnabled || isPopupBlockingEnabled || isWebRTCProtectionEnabled
    }

    private var activeRegionTrickProfile: BrowserRegionTrickProfile? {
        isRegionTricksEnabled ? regionTrickProfile : nil
    }

    private func loadInitialContent(_ startURL: URL) {
        if isContainedBrowser {
            loadContainedBrowserStartPage(defaultURL: startURL)
        } else if Self.isStartPageURL(startURL) {
            loadStartPage()
        } else {
            load(startURL)
        }
    }

    private func loadStartPage() {
        addressText = ""
        webView.loadHTMLString(
            Self.startPageHTML(),
            baseURL: BrowserDefaults.homeURL
        )
    }

    private func loadContainedBrowserStartPage(defaultURL: URL) {
        addressText = defaultURL.absoluteString
        webView.loadHTMLString(
            Self.containedBrowserHTML(defaultURLString: defaultURL.absoluteString),
            baseURL: URL(string: "https://browser.local/contained-browser")!
        )
    }

    private static func configureAudioPlayback() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
        } catch {
            // Web audio still works without the session; this only improves iOS routing behavior.
        }
    }

    private nonisolated static let containedCompatibilityDomains: Set<String> = [
        "youtube.com",
        "youtu.be",
        "googlevideo.com",
        "ytimg.com",
        "open.spotify.com",
        "spotify.com",
        "music.apple.com",
        "soundcloud.com",
        "bandcamp.com",
        "netflix.com",
        "hulu.com",
        "disneyplus.com",
        "primevideo.com",
        "max.com",
        "hbomax.com",
        "peacocktv.com",
        "paramountplus.com",
        "tv.apple.com",
        "appletv.apple.com",
        "crunchyroll.com",
        "twitch.tv",
        "kick.com",
        "rumble.com",
        "vimeo.com",
        "dailymotion.com",
        "tiktok.com",
        "x.com",
        "twitter.com",
        "instagram.com",
        "facebook.com",
        "reddit.com",
        "gmail.com",
        "accounts.google.com",
        "google.com",
        "github.com",
        "gitlab.com",
        "stackoverflow.com",
        "stackexchange.com",
        "notion.so",
        "figma.com",
        "discord.com",
        "chatgpt.com",
        "claude.ai",
        "gemini.google.com",
        "grok.com",
        "perplexity.ai",
        "login.microsoftonline.com",
        "appleid.apple.com",
        "amazon.com",
        "ebay.com",
        "walmart.com",
        "target.com",
        "bestbuy.com",
        "linkedin.com",
        "pinterest.com",
        "medium.com",
        "nytimes.com",
        "cnn.com",
        "bbc.com",
        "microsoft.com",
        "office.com",
        "live.com",
        "icloud.com",
        "dropbox.com"
    ]

    private nonisolated static let containedCompatibilityPathHints = [
        "/login",
        "/signin",
        "/sign-in",
        "/auth",
        "/oauth",
        "/authorize",
        "/checkout",
        "/payment",
        "/watch",
        "/embed",
        "/player",
        "/stream",
        "/video",
        "/videos",
        "/live"
    ]

    private nonisolated static let containedShellHosts: Set<String> = [
        "browser.local",
        "duckduckgo.com",
        "lite.duckduckgo.com",
        "html.duckduckgo.com",
        "www.duckduckgo.com"
    ]

    private nonisolated static func websiteRequest(
        for url: URL,
        regionProfile: BrowserRegionTrickProfile? = nil
    ) -> URLRequest {
        var request = URLRequest(url: url, cachePolicy: .useProtocolCachePolicy, timeoutInterval: 30)
        request.setValue("text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8", forHTTPHeaderField: "Accept")
        if let regionProfile {
            request.setValue(regionProfile.acceptLanguageHeader, forHTTPHeaderField: "Accept-Language")
        }
        if #available(iOS 12.0, *) {
            request.networkServiceType = .responsiveData
        }
        return request
    }

    private static func userAgent(for mode: BrowserWebsiteDisplayMode) -> String {
        switch mode {
        case .automatic:
            return safariCompatibleUserAgent()
        case .mobile:
            return mobileSafariUserAgent()
        case .desktop:
            return desktopSafariUserAgent()
        }
    }

    private static func viewportResolutionScript(
        for preset: BrowserResolutionPreset,
        width rawWidth: Double
    ) -> String? {
        guard preset != .automatic,
              preset != .custom else { return nil }

        let width = preset.viewportWidth ?? Int(BrowserResolutionPreset.clampedSliderWidth(rawWidth))
        let height = preset.viewportHeight ?? Int(BrowserResolutionPreset.sliderHeight(forWidth: Double(width)).rounded())

        return """
        (() => {
          const applyGlideResolution = () => {
            const content = "width=\(width), height=\(height), initial-scale=1.0, maximum-scale=5.0, viewport-fit=cover";
            let viewport = document.querySelector('meta[name="viewport"]');
            if (!viewport) {
              viewport = document.createElement("meta");
              viewport.setAttribute("name", "viewport");
              if (document.head.firstChild) {
                document.head.insertBefore(viewport, document.head.firstChild);
              } else {
                document.head.appendChild(viewport);
              }
            }
            viewport.setAttribute("content", content);
            document.documentElement.dataset.glideResolution = "\(preset.rawValue)";
            document.documentElement.style.setProperty("--glide-resolution-width", "\(width)px");
            document.documentElement.style.setProperty("--glide-resolution-height", "\(height)px");
          };

          if (document.head) {
            applyGlideResolution();
          } else {
            document.addEventListener("DOMContentLoaded", applyGlideResolution, { once: true });
          }
        })();
        """
    }

    private nonisolated static func webpageContentMode(for mode: BrowserWebsiteDisplayMode) -> WKWebpagePreferences.ContentMode {
        switch mode {
        case .automatic:
            return .recommended
        case .mobile:
            return .mobile
        case .desktop:
            return .desktop
        }
    }

    static func clampedWebsiteResolutionScale(_ scale: Double) -> Double {
        min(max(scale, 0.72), 1.36)
    }

    private static func safariCompatibleUserAgent() -> String {
        UIDevice.current.userInterfaceIdiom == .pad ? desktopSafariUserAgent() : mobileSafariUserAgent()
    }

    private static func desktopSafariUserAgent() -> String {
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Safari/605.1.15"
    }

    private static func mobileSafariUserAgent() -> String {
        "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1"
    }

    private static func webExtensionUserScripts(for extensions: [BrowserWebExtension]) -> [WKUserScript] {
        var scripts: [WKUserScript] = []

        for webExtension in extensions where webExtension.isEnabled {
            for contentScript in webExtension.contentScripts where contentScript.hasRunnableContent {
                let injectionTime = webExtensionInjectionTime(for: contentScript.runAt)
                let forMainFrameOnly = contentScript.allFrames == false

                for cssPath in contentScript.css {
                    guard let css = webExtension.resourceText(for: cssPath) else { continue }
                    scripts.append(
                        WKUserScript(
                            source: webExtensionWrappedSource(
                                extension: webExtension,
                                contentScript: contentScript,
                                resourcePath: cssPath,
                                body: webExtensionCSSInjectionBody(css, path: cssPath)
                            ),
                            injectionTime: injectionTime,
                            forMainFrameOnly: forMainFrameOnly
                        )
                    )
                }

                for jsPath in contentScript.js {
                    guard let source = webExtension.resourceText(for: jsPath) else { continue }
                    scripts.append(
                        WKUserScript(
                            source: webExtensionWrappedSource(
                                extension: webExtension,
                                contentScript: contentScript,
                                resourcePath: jsPath,
                                body: webExtensionJavaScriptBody(source, path: jsPath)
                            ),
                            injectionTime: injectionTime,
                            forMainFrameOnly: forMainFrameOnly
                        )
                    )
                }
            }
        }

        return scripts
    }

    private static func webExtensionInjectionTime(for runAt: BrowserWebExtensionRunAt) -> WKUserScriptInjectionTime {
        switch runAt {
        case .documentStart:
            return .atDocumentStart
        case .documentEnd, .documentIdle:
            return .atDocumentEnd
        }
    }

    private static func webExtensionWrappedSource(
        extension webExtension: BrowserWebExtension,
        contentScript: BrowserWebExtensionContentScript,
        resourcePath: String,
        body: String
    ) -> String {
        let matchesLiteral = javascriptJSONLiteral(contentScript.matches)
        let excludeMatchesLiteral = javascriptJSONLiteral(contentScript.excludeMatches)
        let extensionIDLiteral = javascriptJSONLiteral(webExtension.extensionIdentifier)
        let extensionNameLiteral = javascriptJSONLiteral(webExtension.displayName)
        let resourcePathLiteral = javascriptJSONLiteral(resourcePath)

        return """
        (() => {
          const glideExtensionName = \(extensionNameLiteral);
          const glideExtensionID = \(extensionIDLiteral);
          const glideResourcePath = \(resourcePathLiteral);
          const glideMatches = \(matchesLiteral);
          const glideExcludeMatches = \(excludeMatchesLiteral);
          const glideEscapeRegex = (value) => String(value).replace(/[|\\\\{}()[\\]^$+*?.-]/g, '\\\\$&');
          const glidePathRegex = (patternPath) => new RegExp('^' + glideEscapeRegex(patternPath || '/*').replace(/\\\\\\*/g, '.*') + '$');
          const glidePatternMatches = (pattern, href) => {
            try {
              if (pattern === '<all_urls>') {
                return /^(https?|file):/i.test(href);
              }
              const parsed = new URL(href);
              const match = String(pattern).match(/^(\\*|http|https|file):\\/\\/([^/]*)(\\/.*)$/);
              if (!match) { return false; }
              const scheme = match[1];
              const hostPattern = match[2];
              const pathPattern = match[3] || '/*';
              if (scheme !== '*' && parsed.protocol.replace(':', '') !== scheme) { return false; }
              if (scheme === '*' && !['http:', 'https:'].includes(parsed.protocol)) { return false; }
              const host = parsed.hostname.toLowerCase();
              const wantedHost = hostPattern.toLowerCase();
              const hostMatches = wantedHost === '*' ||
                (wantedHost.startsWith('*.') &&
                  (host === wantedHost.slice(2) || host.endsWith('.' + wantedHost.slice(2)))) ||
                host === wantedHost;
              return hostMatches && glidePathRegex(pathPattern).test(parsed.pathname + parsed.search + parsed.hash);
            } catch (_) {
              return false;
            }
          };
          const glideShouldRun = () => {
            const href = String(location.href || '');
            const included = glideMatches.length === 0 || glideMatches.some((pattern) => glidePatternMatches(pattern, href));
            const excluded = glideExcludeMatches.some((pattern) => glidePatternMatches(pattern, href));
            return included && !excluded;
          };
          if (!glideShouldRun()) { return; }
          \(webExtensionCompatibilityBridgeScript())
          try {
            \(body)
          } catch (error) {
            console.warn('[Glide WebExtension]', glideExtensionName, glideResourcePath, error);
          }
        })();
        """
    }

    private static func webExtensionCSSInjectionBody(_ css: String, path: String) -> String {
        let cssLiteral = javascriptJSONLiteral(css)
        let pathLiteral = javascriptJSONLiteral(path)
        return """
        const glideCSS = \(cssLiteral);
        const glideCSSPath = \(pathLiteral);
        const style = document.createElement('style');
        style.dataset.glideWebExtension = glideExtensionID;
        style.dataset.glideWebExtensionResource = glideCSSPath;
        style.textContent = glideCSS;
        (document.head || document.documentElement).appendChild(style);
        """
    }

    private static func webExtensionJavaScriptBody(_ source: String, path: String) -> String {
        let pathLiteral = javascriptJSONLiteral(path)
        return """
        const glideJavaScriptPath = \(pathLiteral);
        \(source)
        """
    }

    private static func webExtensionCompatibilityBridgeScript() -> String {
        """
        const glideStoragePrefix = '__glide_webextension_' + glideExtensionID + '_';
        const glideMakeEvent = () => {
          const listeners = new Set();
          return {
            addListener(listener) {
              if (typeof listener === 'function') { listeners.add(listener); }
            },
            removeListener(listener) {
              listeners.delete(listener);
            },
            hasListener(listener) {
              return listeners.has(listener);
            },
            hasListeners() {
              return listeners.size > 0;
            },
            __dispatch(...args) {
              listeners.forEach((listener) => {
                try { listener(...args); } catch (error) { console.warn('[Glide WebExtension event]', error); }
              });
            }
          };
        };
        const glideResolveWithCallback = (promise, callback) => {
          if (typeof callback === 'function') {
            promise.then((value) => callback(value)).catch(() => callback(undefined));
            return undefined;
          }
          return promise;
        };
        const glideReadStorage = (key) => {
          const value = localStorage.getItem(glideStoragePrefix + key);
          if (value === null) { return undefined; }
          try { return JSON.parse(value); } catch (_) { return value; }
        };
        const glideStorageGet = (keys) => {
          if (keys == null) {
            const all = {};
            for (let index = 0; index < localStorage.length; index += 1) {
              const key = localStorage.key(index);
              if (key && key.startsWith(glideStoragePrefix)) {
                all[key.slice(glideStoragePrefix.length)] = glideReadStorage(key.slice(glideStoragePrefix.length));
              }
            }
            return all;
          }
          if (typeof keys === 'string') {
            return { [keys]: glideReadStorage(keys) };
          }
          if (Array.isArray(keys)) {
            return keys.reduce((result, key) => {
              result[key] = glideReadStorage(key);
              return result;
            }, {});
          }
          return Object.keys(keys).reduce((result, key) => {
            const value = glideReadStorage(key);
            result[key] = value === undefined ? keys[key] : value;
            return result;
          }, {});
        };
        const browserRoot = window.browser = window.browser || {};
        browserRoot.runtime = browserRoot.runtime || {};
        browserRoot.runtime.id = browserRoot.runtime.id || glideExtensionID;
        browserRoot.runtime.lastError = browserRoot.runtime.lastError || null;
        browserRoot.runtime.getURL = browserRoot.runtime.getURL || ((path = '') => 'glide-extension://' + glideExtensionID + '/' + String(path).replace(/^\\/+/, ''));
        browserRoot.runtime.getManifest = browserRoot.runtime.getManifest || (() => ({
          manifest_version: 3,
          name: glideExtensionName,
          version: '',
          browser_specific_settings: { gecko: { id: glideExtensionID } }
        }));
        browserRoot.runtime.onMessage = browserRoot.runtime.onMessage || glideMakeEvent();
        browserRoot.runtime.onConnect = browserRoot.runtime.onConnect || glideMakeEvent();
        browserRoot.runtime.onInstalled = browserRoot.runtime.onInstalled || glideMakeEvent();
        browserRoot.runtime.onStartup = browserRoot.runtime.onStartup || glideMakeEvent();
        browserRoot.runtime.sendMessage = browserRoot.runtime.sendMessage || ((...args) => {
          const callback = args.find((value) => typeof value === 'function');
          const message = args.find((value) => value && typeof value !== 'function' && typeof value !== 'string') ?? args[0];
          let response;
          if (browserRoot.runtime.onMessage.__dispatch) {
            try { response = browserRoot.runtime.onMessage.__dispatch(message, { id: glideExtensionID, url: location.href }, () => {}); } catch (_) {}
          }
          return glideResolveWithCallback(Promise.resolve(response), callback);
        });
        browserRoot.runtime.connect = browserRoot.runtime.connect || (() => ({
          name: 'glide',
          onMessage: glideMakeEvent(),
          onDisconnect: glideMakeEvent(),
          postMessage() {},
          disconnect() {}
        }));
        browserRoot.i18n = browserRoot.i18n || {
          getMessage(messageName, substitutions) {
            if (Array.isArray(substitutions)) {
              return substitutions.reduce((result, value, index) => result.replace('$' + (index + 1), value), String(messageName || ''));
            }
            if (substitutions != null) {
              return String(messageName || '').replace('$1', String(substitutions));
            }
            return String(messageName || '');
          }
        };
        browserRoot.storage = browserRoot.storage || {};
        browserRoot.storage.onChanged = browserRoot.storage.onChanged || glideMakeEvent();
        browserRoot.storage.local = browserRoot.storage.local || {};
        browserRoot.storage.sync = browserRoot.storage.sync || browserRoot.storage.local;
        browserRoot.storage.local.get = browserRoot.storage.local.get || ((keys, callback) => {
          return glideResolveWithCallback(Promise.resolve(glideStorageGet(keys)), callback);
        });
        browserRoot.storage.local.set = browserRoot.storage.local.set || ((items, callback) => {
          Object.entries(items || {}).forEach(([key, value]) => {
            localStorage.setItem(glideStoragePrefix + key, JSON.stringify(value));
          });
          browserRoot.storage.onChanged.__dispatch({}, 'local');
          return glideResolveWithCallback(Promise.resolve(), callback);
        });
        browserRoot.storage.local.remove = browserRoot.storage.local.remove || ((keys, callback) => {
          (Array.isArray(keys) ? keys : [keys]).filter((key) => key != null).forEach((key) => {
            localStorage.removeItem(glideStoragePrefix + key);
          });
          browserRoot.storage.onChanged.__dispatch({}, 'local');
          return glideResolveWithCallback(Promise.resolve(), callback);
        });
        browserRoot.storage.local.clear = browserRoot.storage.local.clear || ((callback) => {
          const keys = [];
          for (let index = 0; index < localStorage.length; index += 1) {
            const key = localStorage.key(index);
            if (key && key.startsWith(glideStoragePrefix)) { keys.push(key); }
          }
          keys.forEach((key) => localStorage.removeItem(key));
          browserRoot.storage.onChanged.__dispatch({}, 'local');
          return glideResolveWithCallback(Promise.resolve(), callback);
        });
        browserRoot.tabs = browserRoot.tabs || {};
        const glideCurrentTab = () => ({ id: 1, active: true, currentWindow: true, title: document.title || '', url: location.href });
        browserRoot.tabs.query = browserRoot.tabs.query || ((queryInfo, callback) => glideResolveWithCallback(Promise.resolve([glideCurrentTab()]), callback));
        browserRoot.tabs.create = browserRoot.tabs.create || ((createProperties, callback) => {
          const tab = { ...glideCurrentTab(), url: createProperties?.url || location.href };
          return glideResolveWithCallback(Promise.resolve(tab), callback);
        });
        browserRoot.tabs.update = browserRoot.tabs.update || ((tabID, updateProperties, callback) => {
          const tab = { ...glideCurrentTab(), url: updateProperties?.url || location.href };
          return glideResolveWithCallback(Promise.resolve(tab), callback);
        });
        browserRoot.tabs.sendMessage = browserRoot.tabs.sendMessage || ((tabID, message, options, callback) => {
          const responseCallback = [message, options, callback].find((value) => typeof value === 'function');
          return glideResolveWithCallback(Promise.resolve(undefined), responseCallback);
        });
        browserRoot.scripting = browserRoot.scripting || {};
        browserRoot.scripting.executeScript = browserRoot.scripting.executeScript || ((details, callback) => {
          const files = details?.files || [];
          const func = details?.func || details?.function;
          try {
            if (typeof func === 'function') { func(...(details?.args || [])); }
          } catch (error) {
            console.warn('[Glide WebExtension scripting]', error);
          }
          return glideResolveWithCallback(Promise.resolve(files.map((file) => ({ frameId: 0, result: file }))), callback);
        });
        browserRoot.alarms = browserRoot.alarms || {
          onAlarm: glideMakeEvent(),
          create() {},
          clear(name, callback) { if (callback) { callback(true); } return Promise.resolve(true); },
          clearAll(callback) { if (callback) { callback(true); } return Promise.resolve(true); },
          get(name, callback) { return glideResolveWithCallback(Promise.resolve(undefined), callback); },
          getAll(callback) { return glideResolveWithCallback(Promise.resolve([]), callback); }
        };
        browserRoot.action = browserRoot.action || {
          onClicked: glideMakeEvent(),
          setBadgeText() {},
          setTitle() {},
          setIcon() {},
          enable() {},
          disable() {}
        };
        browserRoot.declarativeNetRequest = browserRoot.declarativeNetRequest || {
          updateDynamicRules(callback) { if (callback) { callback(); } return Promise.resolve(); },
          getDynamicRules(callback) { return glideResolveWithCallback(Promise.resolve([]), callback); }
        };
        window.chrome = window.chrome || {};
        window.chrome.runtime = window.chrome.runtime || browserRoot.runtime;
        window.chrome.i18n = window.chrome.i18n || browserRoot.i18n;
        window.chrome.storage = window.chrome.storage || browserRoot.storage;
        window.chrome.tabs = window.chrome.tabs || browserRoot.tabs;
        window.chrome.scripting = window.chrome.scripting || browserRoot.scripting;
        window.chrome.alarms = window.chrome.alarms || browserRoot.alarms;
        window.chrome.action = window.chrome.action || browserRoot.action;
        window.chrome.declarativeNetRequest = window.chrome.declarativeNetRequest || browserRoot.declarativeNetRequest;
        """
    }
    private static func javascriptJSONLiteral<T: Encodable>(_ value: T) -> String {
        guard let data = try? JSONEncoder().encode(value),
              let literal = String(data: data, encoding: .utf8) else {
            return "null"
        }
        return literal
    }

    private static func credentialFillScript(username: String, password: String) -> String {
        let usernameLiteral = javascriptStringLiteral(username)
        let passwordLiteral = javascriptStringLiteral(password)
        return """
        (() => {
          const username = \(usernameLiteral);
          const password = \(passwordLiteral);
          const fire = (input) => {
            input.dispatchEvent(new Event('input', { bubbles: true }));
            input.dispatchEvent(new Event('change', { bubbles: true }));
          };
          const visible = (input) => {
            const style = window.getComputedStyle(input);
            const rect = input.getBoundingClientRect();
            return style.visibility !== 'hidden' && style.display !== 'none' && rect.width > 0 && rect.height > 0 && !input.disabled && !input.readOnly;
          };
          const passwords = Array.from(document.querySelectorAll('input[type="password"]')).filter(visible);
          if (passwords[0]) {
            passwords[0].focus();
            passwords[0].value = password;
            fire(passwords[0]);
          }
          const scope = passwords[0]?.form || document;
          const usernameSelectors = [
            'input[autocomplete="username"]',
            'input[autocomplete="email"]',
            'input[type="email"]',
            'input[name*="user" i]',
            'input[name*="email" i]',
            'input[id*="user" i]',
            'input[id*="email" i]',
            'input[type="text"]'
          ];
          const candidates = usernameSelectors.flatMap((selector) => Array.from(scope.querySelectorAll(selector)));
          const target = candidates.find((input) => visible(input) && input.type !== 'password');
          if (target) {
            target.focus();
            target.value = username;
            fire(target);
          }
          return Boolean(target || passwords[0]);
        })();
        """
    }

    private static func javascriptStringLiteral(_ value: String) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: [value]),
              let text = String(data: data, encoding: .utf8),
              text.count >= 2 else { return "\"\"" }
        return String(text.dropFirst().dropLast())
    }

    private nonisolated static func normalizedHost(for url: URL?) -> String {
        url?.host?.lowercased().replacingOccurrences(of: #"^www\."#, with: "", options: .regularExpression) ?? ""
    }

    private nonisolated static func domain(_ host: String, matches domains: Set<String>) -> Bool {
        domains.contains(host) || domains.contains(where: { host.hasSuffix("." + $0) })
    }

    private nonisolated static func isContainedCompatibilityURL(_ url: URL) -> Bool {
        let host = normalizedHost(for: url)
        let path = url.path.lowercased()
        return domain(host, matches: containedCompatibilityDomains) ||
            containedCompatibilityPathHints.contains { hint in
                path == hint || path.hasPrefix(hint + "/") || path.contains(hint + "/")
            }
    }

    private nonisolated static func redirectedDestinationURL(from url: URL) -> URL? {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return nil }
        let host = normalizedHost(for: url)
        let searchRedirectHosts: Set<String> = [
            "duckduckgo.com",
            "lite.duckduckgo.com",
            "html.duckduckgo.com",
            "google.com",
            "bing.com"
        ]
        guard domain(host, matches: searchRedirectHosts) else { return nil }

        let redirectKeys = ["uddg", "q", "url", "u"]
        for key in redirectKeys {
            guard let value = components.queryItems?.first(where: { $0.name.lowercased() == key })?.value,
                  let decodedURL = URL(string: value),
                  decodedURL.scheme?.hasPrefix("http") == true else {
                continue
            }
            return decodedURL
        }

        return nil
    }

    private nonisolated static func promotedContainedURL(from navigationAction: WKNavigationAction) -> URL? {
        guard navigationAction.targetFrame?.isMainFrame == false,
              let requestURL = navigationAction.request.url else {
            return nil
        }

        let mainHost = normalizedHost(for: navigationAction.request.mainDocumentURL)
        let sourceHost = normalizedHost(for: navigationAction.sourceFrame.request.url)
        guard domain(mainHost, matches: containedShellHosts) || domain(sourceHost, matches: containedShellHosts) else {
            return nil
        }

        if isContainedCompatibilityURL(requestURL) {
            return requestURL
        }

        if let redirectedURL = redirectedDestinationURL(from: requestURL),
           isContainedCompatibilityURL(redirectedURL) {
            return redirectedURL
        }

        return nil
    }

    private static func containedBrowserHTML(defaultURLString: String) -> String {
        let escapedDefaultURL = htmlEscaped(defaultURLString)
        let scriptDefaultURL = javaScriptEscaped(defaultURLString)

        return """
        <!doctype html>
        <html lang="en">
        <head>
          <meta charset="utf-8">
          <meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
          <meta http-equiv="x-dns-prefetch-control" content="on">
          <link rel="preconnect" href="https://lite.duckduckgo.com">
          <link rel="dns-prefetch" href="//lite.duckduckgo.com">
          <link rel="preconnect" href="https://duckduckgo.com">
          <link rel="dns-prefetch" href="//duckduckgo.com">
          <title>Contained Web Browser</title>
          <style>
            :root {
              color-scheme: dark;
              font-family: -apple-system, BlinkMacSystemFont, "SF Pro Display", "Segoe UI", sans-serif;
              background: #07090d;
              color: #f4f7fb;
            }
            * { box-sizing: border-box; }
            html {
              width: 100%;
              height: 100%;
              overflow: hidden;
            }
            body {
              margin: 0;
              width: 100%;
              height: 100%;
              overflow: hidden;
              background: #07090d;
            }
            .browser {
              position: relative;
              display: block;
              width: 100%;
              height: 100%;
              background:
                radial-gradient(circle at 84% 12%, rgba(169, 180, 200, 0.16), transparent 28%),
                linear-gradient(135deg, #07090d 0%, #101218 46%, #07090d 100%);
            }
            header {
              position: absolute;
              top: 0;
              left: 0;
              right: 0;
              z-index: 3;
              display: grid;
              gap: 9px;
              padding: calc(env(safe-area-inset-top) + 12px) 12px 12px;
              border-bottom: 1px solid rgba(169, 180, 200, 0.22);
              background: rgba(16, 18, 24, 0.82);
              backdrop-filter: blur(24px);
            }
            .topline {
              display: flex;
              align-items: center;
              gap: 10px;
            }
            .brand {
              width: 30px;
              height: 30px;
              border-radius: 8px;
              display: grid;
              place-items: center;
              font-size: 15px;
              font-weight: 950;
              color: #07090d;
              background: linear-gradient(135deg, #f4f7fb, #9fb7ff);
              flex: none;
            }
            .title {
              display: grid;
              min-width: 0;
            }
            .title strong {
              font-size: 14px;
              line-height: 1.1;
            }
            .title span {
              margin-top: 2px;
              font-size: 11px;
              color: #a9b4c8;
              white-space: nowrap;
              overflow: hidden;
              text-overflow: ellipsis;
            }
            .toolbar {
              display: grid;
              grid-template-columns: auto 1fr auto;
              gap: 8px;
              align-items: center;
            }
            .nav {
              display: flex;
              gap: 6px;
            }
            .actions {
              display: flex;
              gap: 6px;
            }
            form {
              display: flex;
              gap: 8px;
              min-width: 0;
              padding: 6px;
              border: 1px solid rgba(169, 180, 200, 0.32);
              border-radius: 8px;
              background: rgba(32, 36, 45, 0.86);
            }
            input {
              min-width: 0;
              flex: 1;
              height: 36px;
              border: 0;
              outline: 0;
              color: #f4f7fb;
              background: transparent;
              font-size: 15px;
            }
            button {
              border: 0;
              border-radius: 8px;
              min-height: 36px;
              padding: 0 11px;
              font-weight: 800;
              color: #07090d;
              background: #d6e2ff;
              touch-action: manipulation;
            }
            button.icon {
              width: 36px;
              padding: 0;
              color: #f4f7fb;
              background: rgba(32, 36, 45, 0.92);
              border: 1px solid rgba(169, 180, 200, 0.26);
            }
            button.secondary {
              color: #f4f7fb;
              background: rgba(32, 36, 45, 0.92);
              border: 1px solid rgba(169, 180, 200, 0.26);
            }
            .chips {
              display: flex;
              flex-wrap: wrap;
              gap: 8px;
            }
            .chips button {
              min-height: 30px;
              padding: 0 10px;
              color: #f4f7fb;
              background: rgba(32, 36, 45, 0.9);
              border: 1px solid rgba(169, 180, 200, 0.22);
              font-size: 12px;
            }
            .viewport {
              position: absolute;
              inset: 0;
              z-index: 1;
              background: #05070a;
            }
            iframe {
              position: absolute;
              inset: 0;
              width: 100%;
              height: 100%;
              border: 0;
              background: #fff;
            }
            .status {
              position: absolute;
              left: 12px;
              bottom: calc(env(safe-area-inset-bottom) + 12px);
              max-width: min(560px, calc(100% - 24px));
              padding: 8px 10px;
              border-radius: 8px;
              color: #f4f7fb;
              background: rgba(7, 9, 13, 0.76);
              border: 1px solid rgba(169, 180, 200, 0.22);
              font-size: 12px;
              font-weight: 700;
              opacity: 0;
              transform: translateY(8px);
              transition: opacity 160ms ease, transform 160ms ease;
              pointer-events: none;
            }
            .status.visible {
              opacity: 1;
              transform: translateY(0);
            }
            @media (max-width: 680px) {
              header { padding: calc(env(safe-area-inset-top) + 10px) 10px 10px; }
              .toolbar { grid-template-columns: 1fr; }
              .nav { order: 2; }
              form { order: 1; }
              .actions { order: 3; }
              .chips { overflow-x: auto; flex-wrap: nowrap; padding-bottom: 2px; }
            }
          </style>
        </head>
        <body>
          <main class="browser">
            <header>
              <div class="topline">
                <div class="brand">B</div>
                <div class="title">
                  <strong>Contained Web Browser</strong>
                  <span id="currentLabel">Browser website inside this tab</span>
                </div>
              </div>
              <div class="toolbar">
                <div class="nav" aria-label="Inner browser controls">
                  <button class="icon" id="backButton" type="button" aria-label="Back">&lt;</button>
                  <button class="icon" id="forwardButton" type="button" aria-label="Forward">&gt;</button>
                  <button class="icon" id="reloadButton" type="button" aria-label="Reload">R</button>
                </div>
                <form id="browserForm">
                  <input id="address" value="\(escapedDefaultURL)" autocomplete="url" autocapitalize="none" spellcheck="false" aria-label="Website or search">
                  <button type="submit">Open</button>
                </form>
                <div class="actions">
                  <button class="secondary" id="audioButton" type="button">Audio</button>
                  <button class="secondary" id="fullPageButton" type="button">Open Page</button>
                </div>
              </div>
            <div class="chips">
              <button type="button" data-url="https://youtube.com/">YouTube</button>
              <button type="button" data-url="https://open.spotify.com/">Spotify</button>
              <button type="button" data-url="https://wikipedia.org/">Wikipedia</button>
              <button type="button" data-url="https://lite.duckduckgo.com/lite/">Search</button>
            </div>
            </header>
            <section class="viewport">
              <iframe
                id="viewport"
                title="Contained website viewport"
                allow="autoplay; fullscreen; encrypted-media; picture-in-picture; clipboard-read; clipboard-write; camera; microphone; geolocation; gamepad; accelerometer; gyroscope; magnetometer; payment; xr-spatial-tracking"
                referrerpolicy="no-referrer-when-downgrade"
                loading="eager"
                allowfullscreen>
              </iframe>
              <div class="status" id="status"></div>
            </section>
          </main>
          <script>
            const initialURL = "\(scriptDefaultURL)";
            const input = document.getElementById("address");
            const form = document.getElementById("browserForm");
            const frame = document.getElementById("viewport");
            const status = document.getElementById("status");
            const label = document.getElementById("currentLabel");
            const backButton = document.getElementById("backButton");
            const forwardButton = document.getElementById("forwardButton");
            const reloadButton = document.getElementById("reloadButton");
            const audioButton = document.getElementById("audioButton");
            const fullPageButton = document.getElementById("fullPageButton");
            try { frame.fetchPriority = "high"; } catch (_) {}
            const directDomains = [
              "youtube.com",
              "youtu.be",
              "open.spotify.com",
              "spotify.com",
              "music.apple.com",
              "soundcloud.com",
              "bandcamp.com",
              "netflix.com",
              "hulu.com",
              "disneyplus.com",
              "primevideo.com",
              "max.com",
              "hbomax.com",
              "peacocktv.com",
              "paramountplus.com",
              "tv.apple.com",
              "appletv.apple.com",
              "crunchyroll.com",
              "twitch.tv",
              "kick.com",
              "rumble.com",
              "vimeo.com",
              "dailymotion.com",
              "tiktok.com",
              "x.com",
              "twitter.com",
              "instagram.com",
              "facebook.com",
              "reddit.com",
              "gmail.com",
              "accounts.google.com",
              "google.com",
              "github.com",
              "gitlab.com",
              "stackoverflow.com",
              "stackexchange.com",
              "notion.so",
              "figma.com",
              "discord.com",
              "chatgpt.com",
              "claude.ai",
              "gemini.google.com",
              "grok.com",
              "perplexity.ai",
              "login.microsoftonline.com",
              "appleid.apple.com",
              "amazon.com",
              "ebay.com",
              "walmart.com",
              "target.com",
              "bestbuy.com",
              "linkedin.com",
              "pinterest.com",
              "medium.com",
              "nytimes.com",
              "cnn.com",
              "bbc.com",
              "microsoft.com",
              "office.com",
              "live.com",
              "icloud.com",
              "dropbox.com"
            ];
            const directPathHints = [
              "/login",
              "/signin",
              "/sign-in",
              "/auth",
              "/oauth",
              "/authorize",
              "/checkout",
              "/payment",
              "/watch",
              "/embed",
              "/player",
              "/stream",
              "/video",
              "/videos",
              "/live"
            ];
            let stack = [];
            let index = -1;
            let statusTimer = undefined;
            let frameStatusTimer = undefined;
            let warmTimer = undefined;
            const warmedOrigins = new Set();
            let audioContext = undefined;

            function destination(raw) {
              const value = raw.trim();
              if (!value) return initialURL;
              if (/^(https?|file):\\/\\//i.test(value)) return value;
              if (/^(localhost|127\\.0\\.0\\.1)(:|\\/|$)/i.test(value)) return "http://" + value;
              if (value.includes(".") || value.includes(":")) return "https://" + value;
              return "https://lite.duckduckgo.com/lite/?q=" + encodeURIComponent(value);
            }

            function parsedURL(url) {
              try {
                return new URL(url);
              } catch (_) {
                return undefined;
              }
            }

            function warmDestination(url) {
              const parsed = parsedURL(url);
              if (!parsed || !/^https?:$/.test(parsed.protocol) || warmedOrigins.has(parsed.origin)) {
                return;
              }
              warmedOrigins.add(parsed.origin);

              const dns = document.createElement("link");
              dns.rel = "dns-prefetch";
              dns.href = "//" + parsed.host;
              document.head.appendChild(dns);

              const preconnect = document.createElement("link");
              preconnect.rel = "preconnect";
              preconnect.href = parsed.origin;
              preconnect.crossOrigin = "";
              document.head.appendChild(preconnect);
            }

            function scheduleWarmDestination(raw) {
              clearTimeout(warmTimer);
              warmTimer = setTimeout(() => {
                warmDestination(destination(raw || initialURL));
              }, 90);
            }

            function hostFor(url) {
              return parsedURL(url)?.hostname.replace(/^www\\./, "").toLowerCase() || "";
            }

            function shouldOpenDirect(url) {
              const parsed = parsedURL(url);
              if (parsed) {
                const host = parsed.hostname.replace(/^www\\./, "").toLowerCase();
                const path = parsed.pathname.toLowerCase();
                return directDomains.some(domain => host === domain || host.endsWith("." + domain)) ||
                  directPathHints.some(hint => path === hint || path.startsWith(hint + "/") || path.includes(hint + "/"));
              }
              const host = hostFor(url);
              return directDomains.some(domain => host === domain || host.endsWith("." + domain));
            }

            function isSearchStartURL(url) {
              const host = hostFor(url);
              return host === "duckduckgo.com" ||
                host === "lite.duckduckgo.com" ||
                host === "html.duckduckgo.com" ||
                host.endsWith(".duckduckgo.com");
            }

            function showStatus(message) {
              clearTimeout(statusTimer);
              status.textContent = message;
              status.classList.add("visible");
              statusTimer = setTimeout(() => status.classList.remove("visible"), 3600);
            }

            function updateButtons() {
              backButton.disabled = index <= 0;
              forwardButton.disabled = index >= stack.length - 1;
              label.textContent = input.value;
            }

            function openInner(raw, push = true) {
              const url = destination(raw);
              input.value = url;
              warmDestination(url);

              if (shouldOpenDirect(url)) {
                showStatus("Opening full site for media and compatibility");
                window.location.assign(url);
                return;
              }

              loadFrame(url);

              if (push) {
                stack = stack.slice(0, index + 1);
                stack.push(url);
                index = stack.length - 1;
              }

              updateButtons();
              showStatus("Loading inside contained browser");
            }

            function loadFrame(url) {
              clearTimeout(frameStatusTimer);
              frame.dataset.target = url;
              warmDestination(url);
              frame.src = url;
              frameStatusTimer = setTimeout(() => {
                if (frame.dataset.target === url) {
                  showStatus("Still loading. Open Page is fastest for protected sites");
                }
              }, 1400);
            }

            form.addEventListener("submit", event => {
              event.preventDefault();
              openInner(input.value);
            });

            input.addEventListener("input", () => scheduleWarmDestination(input.value));
            input.addEventListener("focus", () => scheduleWarmDestination(input.value || initialURL));

            document.querySelectorAll("[data-url]").forEach(button => {
              button.addEventListener("pointerdown", () => warmDestination(button.dataset.url), { passive: true });
              button.addEventListener("mouseenter", () => warmDestination(button.dataset.url));
              button.addEventListener("click", () => {
                openInner(button.dataset.url);
              });
            });

            backButton.addEventListener("click", () => {
              if (index <= 0) return;
              index -= 1;
              input.value = stack[index];
              loadFrame(stack[index]);
              updateButtons();
            });

            forwardButton.addEventListener("click", () => {
              if (index >= stack.length - 1) return;
              index += 1;
              input.value = stack[index];
              loadFrame(stack[index]);
              updateButtons();
            });

            reloadButton.addEventListener("click", () => {
              if (!input.value) return;
              loadFrame(input.value);
              showStatus("Reloading");
            });

            audioButton.addEventListener("click", async () => {
              try {
                const AudioContextType = window.AudioContext || window.webkitAudioContext;
                if (!AudioContextType) {
                  showStatus("Audio is already handled by the browser");
                  return;
                }
                audioContext = audioContext || new AudioContextType();
                if (audioContext.state !== "running") {
                  await audioContext.resume();
                }
                const oscillator = audioContext.createOscillator();
                const gain = audioContext.createGain();
                gain.gain.value = 0.0001;
                oscillator.connect(gain);
                gain.connect(audioContext.destination);
                oscillator.start();
                oscillator.stop(audioContext.currentTime + 0.03);
                showStatus("Audio unlocked for this contained tab");
              } catch (_) {
                showStatus("Use Open Page for sites that require direct audio");
              }
            });

            fullPageButton.addEventListener("click", () => {
              window.location.assign(destination(input.value));
            });

            frame.addEventListener("load", () => {
              clearTimeout(frameStatusTimer);
              showStatus("Loaded");
            });

            warmDestination(initialURL);
            if (isSearchStartURL(initialURL)) {
              input.value = "";
              updateButtons();
              showStatus("Ready");
            } else {
              openInner(initialURL);
            }
            input.focus();
            input.select();
          </script>
        </body>
        </html>
        """
    }

    private static func htmlEscaped(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }

    private static func javaScriptEscaped(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\r")
    }

    private nonisolated static let trackingQueryKeys: Set<String> = [
        "utm_source", "utm_medium", "utm_campaign", "utm_term", "utm_content", "utm_id",
        "utm_name", "utm_cid", "utm_reader", "utm_viz_id", "utm_pubreferrer", "fbclid",
        "gclid", "gbraid", "wbraid", "dclid", "msclkid", "mc_cid", "mc_eid", "igshid",
        "twclid", "yclid", "_hsenc", "_hsmi", "mkt_tok", "vero_id", "spm", "scid",
        "wickedid", "oly_enc_id", "oly_anon_id"
    ]

    private nonisolated static let bounceRedirectKeys: Set<String> = [
        "url", "u", "to", "target", "destination", "dest", "redirect", "redirect_url",
        "redirect_uri", "r", "q"
    ]

    private nonisolated static func privacyAdjustedURL(
        for url: URL,
        upgradeHTTPS: Bool,
        stripTrackingParameters: Bool,
        blockBounceTracking: Bool
    ) -> URL {
        var destination = url

        if blockBounceTracking,
           let redirected = redirectedDestinationURL(from: destination) ?? bounceDestinationURL(from: destination) {
            destination = redirected
        }

        if stripTrackingParameters,
           let stripped = strippedTrackingURL(from: destination) {
            destination = stripped
        }

        if upgradeHTTPS,
           destination.scheme?.lowercased() == "http",
           var components = URLComponents(url: destination, resolvingAgainstBaseURL: false) {
            components.scheme = "https"
            destination = components.url ?? destination
        }

        return destination
    }

    private nonisolated static func strippedTrackingURL(from url: URL) -> URL? {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems,
              queryItems.isEmpty == false else { return nil }

        let filtered = queryItems.filter { trackingQueryKeys.contains($0.name.lowercased()) == false }
        guard filtered.count != queryItems.count else { return nil }
        components.queryItems = filtered.isEmpty ? nil : filtered
        return components.url
    }

    private nonisolated static func bounceDestinationURL(from url: URL) -> URL? {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return nil }
        let host = normalizedHost(for: url)
        let path = url.path.lowercased()
        let looksLikeBounce = path.contains("redirect") ||
            path.contains("outbound") ||
            path.contains("away") ||
            path.contains("leave") ||
            path.contains("go") ||
            host.contains("link.") ||
            host.contains("links.")
        guard looksLikeBounce else { return nil }

        for item in components.queryItems ?? [] where bounceRedirectKeys.contains(item.name.lowercased()) {
            guard let value = item.value?.removingPercentEncoding ?? item.value,
                  let destination = URL(string: value),
                  destination.scheme?.hasPrefix("http") == true else {
                continue
            }
            return destination
        }

        return nil
    }

    private static func privacyProtectionScript(
        fingerprintProtection: Bool,
        socialBlocking: Bool,
        popupBlocking: Bool,
        webRTCProtection: Bool
    ) -> String {
        let fingerprintLiteral = fingerprintProtection ? "true" : "false"
        let socialLiteral = socialBlocking ? "true" : "false"
        let popupLiteral = popupBlocking ? "true" : "false"
        let webRTCLiteral = webRTCProtection ? "true" : "false"

        return """
        (() => {
          if (window.__glideProtectionWhitelisted) { return; }
          const config = {
            fingerprintProtection: \(fingerprintLiteral),
            socialBlocking: \(socialLiteral),
            popupBlocking: \(popupLiteral),
            webRTCProtection: \(webRTCLiteral)
          };

          if (config.fingerprintProtection && !window.__glideFingerprintProtection) {
            window.__glideFingerprintProtection = true;
            const seed = Math.floor(Math.random() * 255);
            try {
              Object.defineProperty(navigator, "languages", { configurable: true, get: () => ["en-US", "en"] });
              Object.defineProperty(navigator, "language", { configurable: true, get: () => "en-US" });
              Object.defineProperty(navigator, "doNotTrack", { configurable: true, get: () => "1" });
              Object.defineProperty(navigator, "hardwareConcurrency", { configurable: true, get: () => Math.min(8, navigator.hardwareConcurrency || 4) });
              Object.defineProperty(navigator, "deviceMemory", { configurable: true, get: () => 4 });
            } catch (_) {}

            try {
              const canvasProto = HTMLCanvasElement && HTMLCanvasElement.prototype;
              const nativeToDataURL = canvasProto && canvasProto.toDataURL;
              const nativeToBlob = canvasProto && canvasProto.toBlob;
              const perturb = (canvas) => {
                try {
                  const ctx = canvas.getContext("2d");
                  if (!ctx || canvas.width < 8 || canvas.height < 8) { return; }
                  const x = seed % Math.max(1, Math.min(canvas.width, 32));
                  const y = (seed * 3) % Math.max(1, Math.min(canvas.height, 32));
                  const image = ctx.getImageData(x, y, 1, 1);
                  image.data[0] = image.data[0] ^ 1;
                  ctx.putImageData(image, x, y);
                } catch (_) {}
              };
              if (nativeToDataURL) {
                canvasProto.toDataURL = function(...args) {
                  perturb(this);
                  return nativeToDataURL.apply(this, args);
                };
              }
              if (nativeToBlob) {
                canvasProto.toBlob = function(...args) {
                  perturb(this);
                  return nativeToBlob.apply(this, args);
                };
              }
            } catch (_) {}

            try {
              const nativeGetParameter = WebGLRenderingContext.prototype.getParameter;
              WebGLRenderingContext.prototype.getParameter = function(parameter) {
                if (parameter === 37445) { return "Apple"; }
                if (parameter === 37446) { return "Apple GPU"; }
                return nativeGetParameter.call(this, parameter);
              };
            } catch (_) {}
          }

          if (config.webRTCProtection && !window.__glideWebRTCProtection) {
            window.__glideWebRTCProtection = true;
            try {
              window.RTCPeerConnection = undefined;
              window.webkitRTCPeerConnection = undefined;
            } catch (_) {}
          }

          if (config.socialBlocking && !window.__glideSocialBlocking) {
            window.__glideSocialBlocking = true;
            const selectors = [
              "iframe[src*='facebook.com/plugins']",
              "iframe[src*='platform.twitter.com']",
              "iframe[src*='x.com/widgets']",
              "iframe[src*='linkedin.com/embed']",
              "iframe[src*='tiktok.com/embed']",
              "script[src*='connect.facebook.net']",
              "script[src*='platform.twitter.com']",
              "script[src*='platform.linkedin.com']",
              "script[src*='assets.pinterest.com']",
              ".fb-like,.fb-share-button,.twitter-share-button,.IN-widget,.pinterest-button"
            ];
            const style = document.createElement("style");
            style.id = "glide-social-blocking";
            style.textContent = selectors.join(",") + "{display:none!important;visibility:hidden!important;}";
            const install = () => {
              if (!document.getElementById(style.id)) {
                (document.head || document.documentElement || document.body)?.appendChild(style);
              }
              try {
                document.querySelectorAll(selectors.join(",")).forEach((element) => element.remove());
              } catch (_) {}
            };
            install();
            window.addEventListener("DOMContentLoaded", install);
            window.addEventListener("load", install);
          }

          if (!config.popupBlocking && window.__glidePopupBlocking) {
            try { window.__glidePopupObserver?.disconnect(); } catch (_) {}
            try {
              if (window.__glideNativeOpen) {
                window.open = window.__glideNativeOpen;
              }
            } catch (_) {}
            try { document.getElementById("glide-popup-blocking")?.remove(); } catch (_) {}
            window.__glidePopupBlocking = false;
            window.__glidePopupCleanup = undefined;
          }

          if (config.popupBlocking) {
            const selectors = [
              "[class*='ad-modal']",
              "[class*='ad_modal']",
              "[class*='ad-popup']",
              "[class*='ad_popup']",
              "[class*='ad-overlay']",
              "[class*='ad_overlay']",
              "[class*='advert-modal']",
              "[class*='advert_popup']",
              "[class*='sponsor-modal']",
              "[class*='promo-modal']",
              "[class*='promo-popup']",
              "[class*='interstitial']",
              "[id*='ad-modal']",
              "[id*='ad_popup']",
              "[id*='ad-overlay']",
              "[id*='advert-modal']",
              "[id*='promo-popup']",
              "[id*='interstitial']",
              "[aria-label*='Close ad']",
              "[aria-label*='close ad']",
              "[aria-label*='Advertisement']",
              "[aria-label*='advertisement']",
              "iframe[src*='doubleclick']",
              "iframe[src*='googlesyndication']",
              "iframe[src*='googleadservices']"
            ];
            const popupWords = [
              "ads", "advert", "advertisement", "sponsor", "sponsored",
              "promo", "promotion", "popup", "pop-up", "modal", "overlay",
              "interstitial", "newsletter", "subscribe", "signup", "sign-up",
              "survey", "offer", "deal"
            ];
            const safeWords = [
              "login", "log in", "signin", "sign in", "sign-in", "auth",
              "account", "checkout", "payment", "cart", "password", "2fa",
              "verification", "captcha", "cookie", "consent"
            ];
            const textOf = (element) => {
              try {
                return [
                  element.id,
                  element.className,
                  element.getAttribute("aria-label"),
                  element.getAttribute("role"),
                  element.textContent
                ].join(" ").toLowerCase().slice(0, 900);
              } catch (_) {
                return "";
              }
            };
            const hasAny = (text, words) => words.some((word) => text.includes(word));
            const hasCloseAdControl = (element) => {
              try {
                return Array.from(element.querySelectorAll("button,a,[role='button'],[aria-label]")).some((control) => {
                  const label = [
                    control.getAttribute("aria-label"),
                    control.getAttribute("title"),
                    control.textContent
                  ].join(" ").toLowerCase();
                  return label.includes("close ad") ||
                    label.includes("close advertisement") ||
                    label.includes("skip ad") ||
                    label.includes("dismiss ad") ||
                    (label.includes("close") && hasAny(textOf(element), popupWords));
                });
              } catch (_) {
                return false;
              }
            };
            const looksLikePopupAd = (element) => {
              if (!element || element === document.documentElement || element === document.body) { return false; }
              const text = textOf(element);
              if (!text || hasAny(text, safeWords)) { return false; }
              const hasPopupSignal = hasAny(text, popupWords) || hasCloseAdControl(element);
              if (!hasPopupSignal) { return false; }
              try {
                const style = window.getComputedStyle(element);
                const rect = element.getBoundingClientRect();
                const zIndex = Number.parseInt(style.zIndex || "0", 10);
                const fixed = style.position === "fixed" || style.position === "sticky";
                const largeEnough = rect.width >= window.innerWidth * 0.22 && rect.height >= window.innerHeight * 0.14;
                const centeredOrCovering = rect.width >= window.innerWidth * 0.55 ||
                  rect.height >= window.innerHeight * 0.35 ||
                  (rect.left <= window.innerWidth * 0.12 && rect.right >= window.innerWidth * 0.88);
                return fixed && largeEnough && (centeredOrCovering || zIndex >= 900 || hasCloseAdControl(element));
              } catch (_) {
                return false;
              }
            };
            const removeElement = (element) => {
              try {
                element.setAttribute("data-glide-popup-blocked", "true");
                element.remove();
              } catch (_) {}
            };
            let cleanupScheduled = false;
            const unlockScroll = () => {
              try {
                document.documentElement.style.overflow = "";
                document.documentElement.style.position = "";
                if (document.body) {
                  document.body.style.overflow = "";
                  document.body.style.position = "";
                }
              } catch (_) {}
            };
            const cleanup = () => {
              try {
                document.querySelectorAll(selectors.join(",")).forEach(removeElement);
              } catch (_) {}
              try {
                let checked = 0;
                for (const element of document.querySelectorAll("body *")) {
                  checked += 1;
                  if (checked > 900) { break; }
                  if (looksLikePopupAd(element)) {
                    removeElement(element);
                  }
                }
              } catch (_) {}
              unlockScroll();
            };
            const scheduleCleanup = () => {
              if (cleanupScheduled) { return; }
              cleanupScheduled = true;
              requestAnimationFrame(() => {
                cleanupScheduled = false;
                cleanup();
              });
            };

            if (!window.__glidePopupBlocking) {
              window.__glidePopupBlocking = true;
              try {
                window.__glideNativeOpen = window.__glideNativeOpen || window.open;
                window.open = () => null;
              } catch (_) {}
              try {
                const style = document.createElement("style");
                style.id = "glide-popup-blocking";
                style.textContent = selectors.join(",") + "{display:none!important;visibility:hidden!important;pointer-events:none!important;}";
                (document.head || document.documentElement || document.body)?.appendChild(style);
              } catch (_) {}
              try {
                window.__glidePopupObserver = new MutationObserver(() => scheduleCleanup());
                window.__glidePopupObserver.observe(document.documentElement || document, {
                  childList: true,
                  subtree: true,
                  attributes: true,
                  attributeFilter: ["class", "style", "aria-label", "id"]
                });
              } catch (_) {}
              window.addEventListener("DOMContentLoaded", cleanup);
              window.addEventListener("load", cleanup);
            }
            window.__glidePopupCleanup = cleanup;
            cleanup();
          }
        })();
        """
    }

    private static func regionTricksScript(profile: BrowserRegionTrickProfile) -> String {
        let coordinate = profile.coordinate
        let languages = profile.languages
            .map { "\"\(javaScriptEscaped($0))\"" }
            .joined(separator: ", ")
        let locale = javaScriptEscaped(profile.localeIdentifier)
        let timeZone = javaScriptEscaped(profile.timeZoneIdentifier)
        let countryCode = javaScriptEscaped(profile.countryCode)
        let acceptLanguage = javaScriptEscaped(profile.acceptLanguageHeader)
        let currencyCode = javaScriptEscaped(profile.currencyCode)
        let measurementSystem = javaScriptEscaped(profile.measurementSystem)

        return """
        (() => {
          const profile = {
            countryCode: "\(countryCode)",
            locale: "\(locale)",
            language: "\(javaScriptEscaped(profile.languages.first ?? profile.localeIdentifier))",
            languages: [\(languages)],
            acceptLanguage: "\(acceptLanguage)",
            timeZone: "\(timeZone)",
            timeZoneOffsetMinutes: \(profile.timeZoneOffsetMinutes),
            currencyCode: "\(currencyCode)",
            measurementSystem: "\(measurementSystem)",
            latitude: \(coordinate.latitude),
            longitude: \(coordinate.longitude),
            accuracy: 24
          };

          window.__glideRegionTricks = profile;
          const defineGetter = (target, name, getter) => {
            try { Object.defineProperty(target, name, { configurable: true, get: getter }); } catch (_) {}
          };

          try {
            defineGetter(Navigator.prototype, "language", () => profile.language);
            defineGetter(Navigator.prototype, "languages", () => profile.languages.slice());
            defineGetter(Navigator.prototype, "webdriver", () => false);
            defineGetter(navigator, "language", () => profile.language);
            defineGetter(navigator, "languages", () => profile.languages.slice());
          } catch (_) {}

          try {
            document.documentElement.setAttribute("lang", profile.language);
            document.documentElement.setAttribute("data-glide-region", profile.countryCode);
          } catch (_) {}

          try {
            const nativeDateTimeFormat = Intl.DateTimeFormat;
            const wrappedDateTimeFormat = function(locale, options) {
              const nextOptions = Object.assign({}, options || {});
              if (!nextOptions.timeZone) { nextOptions.timeZone = profile.timeZone; }
              return new nativeDateTimeFormat(locale || profile.locale, nextOptions);
            };
            wrappedDateTimeFormat.prototype = nativeDateTimeFormat.prototype;
            wrappedDateTimeFormat.supportedLocalesOf = nativeDateTimeFormat.supportedLocalesOf.bind(nativeDateTimeFormat);
            Object.defineProperty(Intl, "DateTimeFormat", {
              configurable: true,
              writable: true,
              value: wrappedDateTimeFormat
            });
          } catch (_) {}

          try {
            const nativeResolvedOptions = Intl.DateTimeFormat.prototype.resolvedOptions;
            Intl.DateTimeFormat.prototype.resolvedOptions = function(...args) {
              const options = nativeResolvedOptions.apply(this, args);
              return Object.assign({}, options, {
                locale: options.locale || profile.locale,
                timeZone: profile.timeZone
              });
            };
          } catch (_) {}

          try {
            const nativeNumberFormat = Intl.NumberFormat;
            const wrappedNumberFormat = function(locale, options) {
              return new nativeNumberFormat(locale || profile.locale, options || {});
            };
            wrappedNumberFormat.prototype = nativeNumberFormat.prototype;
            wrappedNumberFormat.supportedLocalesOf = nativeNumberFormat.supportedLocalesOf.bind(nativeNumberFormat);
            Object.defineProperty(Intl, "NumberFormat", {
              configurable: true,
              writable: true,
              value: wrappedNumberFormat
            });
          } catch (_) {}

          try {
            const nativeNumberResolvedOptions = Intl.NumberFormat.prototype.resolvedOptions;
            Intl.NumberFormat.prototype.resolvedOptions = function(...args) {
              const options = nativeNumberResolvedOptions.apply(this, args);
              const next = Object.assign({}, options, { locale: options.locale || profile.locale });
              if (next.style === "currency" && !next.currency) { next.currency = profile.currencyCode; }
              return next;
            };
          } catch (_) {}

          try {
            const nativeLocale = Intl.Locale;
            if (nativeLocale) {
              const wrappedLocale = function(tag, options) {
                return new nativeLocale(tag || profile.locale, options || {});
              };
              wrappedLocale.prototype = nativeLocale.prototype;
              Object.defineProperty(Intl, "Locale", {
                configurable: true,
                writable: true,
                value: wrappedLocale
              });
            }
          } catch (_) {}

          try {
            Date.prototype.getTimezoneOffset = function() {
              return profile.timeZoneOffsetMinutes;
            };
          } catch (_) {}

          try {
            const nativeDateToLocaleString = Date.prototype.toLocaleString;
            const nativeDateToLocaleDateString = Date.prototype.toLocaleDateString;
            const nativeDateToLocaleTimeString = Date.prototype.toLocaleTimeString;
            const withRegionTimeZone = (options) => {
              const nextOptions = Object.assign({}, options || {});
              if (!nextOptions.timeZone) { nextOptions.timeZone = profile.timeZone; }
              return nextOptions;
            };
            Date.prototype.toLocaleString = function(locale, options) {
              return nativeDateToLocaleString.call(this, locale || profile.locale, withRegionTimeZone(options));
            };
            Date.prototype.toLocaleDateString = function(locale, options) {
              return nativeDateToLocaleDateString.call(this, locale || profile.locale, withRegionTimeZone(options));
            };
            Date.prototype.toLocaleTimeString = function(locale, options) {
              return nativeDateToLocaleTimeString.call(this, locale || profile.locale, withRegionTimeZone(options));
            };
          } catch (_) {}

          try {
            const nativeNumberToLocaleString = Number.prototype.toLocaleString;
            Number.prototype.toLocaleString = function(locale, options) {
              return nativeNumberToLocaleString.call(this, locale || profile.locale, options || {});
            };
          } catch (_) {}

          try {
            const makePosition = () => ({
              coords: {
                latitude: profile.latitude,
                longitude: profile.longitude,
                altitude: null,
                accuracy: profile.accuracy,
                altitudeAccuracy: null,
                heading: null,
                speed: null
              },
              timestamp: Date.now()
            });
            const activeWatches = new Map();
            const geolocation = navigator.geolocation || {};
            geolocation.getCurrentPosition = function(success, error, options) {
              if (typeof success === "function") {
                setTimeout(() => success(makePosition()), 0);
              }
            };
            geolocation.watchPosition = function(success, error, options) {
              const id = Math.floor(Math.random() * 1000000) + Date.now();
              const send = () => {
                if (typeof success === "function") { success(makePosition()); }
              };
              send();
              activeWatches.set(id, setInterval(send, 60000));
              return id;
            };
            geolocation.clearWatch = function(id) {
              const timer = activeWatches.get(id);
              if (timer) { clearInterval(timer); }
              activeWatches.delete(id);
            };
            defineGetter(Navigator.prototype, "geolocation", () => geolocation);
            defineGetter(navigator, "geolocation", () => geolocation);
          } catch (_) {}

          try {
            const permissions = navigator.permissions;
            const nativeQuery = permissions && permissions.query ? permissions.query.bind(permissions) : null;
            if (permissions && nativeQuery) {
              permissions.query = function(query) {
                if (query && query.name === "geolocation") {
                  return Promise.resolve({
                    name: "geolocation",
                    state: "granted",
                    onchange: null,
                    addEventListener: function() {},
                    removeEventListener: function() {},
                    dispatchEvent: function() { return false; }
                  });
                }
                return nativeQuery(query);
              };
            }
          } catch (_) {}

          try {
            const withRegionHeaders = (headers) => {
              try {
                const nextHeaders = new Headers(headers || {});
                nextHeaders.set("Accept-Language", profile.acceptLanguage);
                return nextHeaders;
              } catch (_) {
                return headers || {};
              }
            };
            if (window.fetch && !window.__glideRegionFetchWrapped) {
              window.__glideRegionFetchWrapped = true;
              const nativeFetch = window.fetch.bind(window);
              window.fetch = function(input, init) {
                const nextInit = Object.assign({}, init || {});
                nextInit.headers = withRegionHeaders(nextInit.headers || (input && input.headers));
                return nativeFetch(input, nextInit);
              };
            }
            if (window.XMLHttpRequest && !window.__glideRegionXHRWrapped) {
              window.__glideRegionXHRWrapped = true;
              const nativeOpen = XMLHttpRequest.prototype.open;
              const nativeSend = XMLHttpRequest.prototype.send;
              XMLHttpRequest.prototype.open = function(...args) {
                this.__glideRegionTricksOpen = true;
                return nativeOpen.apply(this, args);
              };
              XMLHttpRequest.prototype.send = function(...args) {
                try {
                  if (this.__glideRegionTricksOpen) {
                    this.setRequestHeader("Accept-Language", profile.acceptLanguage);
                  }
                } catch (_) {}
                return nativeSend.apply(this, args);
              };
            }
          } catch (_) {}
        })();
        """
    }

    private static func pageControlsScript(
        darkReaderCSS: String,
        stylusCSS: String,
        fpsLimit: Double?
    ) -> String {
        let fpsLiteral: String
        if let fpsLimit {
            fpsLiteral = String(format: "%.0f", fpsLimit)
        } else {
            fpsLiteral = "null"
        }

        return """
        (() => {
          const nextConfig = {
            darkReaderCSS: "\(javaScriptEscaped(darkReaderCSS))",
            stylusCSS: "\(javaScriptEscaped(stylusCSS))",
            fpsLimit: \(fpsLiteral)
          };

          const internalHosts = new Set(["glide.local", "browser.local"]);
          const mediaSelector = "img,picture,video,canvas,svg,iframe,object,embed";
          const emptyMarker = "__glide_empty__";

          const hostFrom = (value) => {
            try {
              if (!value) { return ""; }
              return new URL(value, location.href || document.baseURI || "https://invalid.local/").hostname.toLowerCase();
            } catch (_) {
              return "";
            }
          };

          const isInternalPage = () => {
            const hosts = [
              String(location.hostname || "").toLowerCase(),
              hostFrom(location.href),
              hostFrom(document.URL),
              hostFrom(document.baseURI)
            ];
            if (hosts.some((host) => internalHosts.has(host))) { return true; }
            return location.protocol !== "file:" && hosts.every((host) => !host);
          };

          const toggleRootFlags = (state) => {
            const root = document.documentElement;
            if (!root) { return; }
            const internal = isInternalPage();
            const hasDarkReader = !internal && !!state.config.darkReaderCSS;
            const hasStylus = !internal && !!state.config.stylusCSS;
            root.toggleAttribute("data-glide-internal-page", internal);
            root.toggleAttribute("data-glide-dark-reader", hasDarkReader);
            root.toggleAttribute("data-glide-stylus-catppuccin", hasStylus);
          };

          const installStyle = (id, css) => {
            let style = document.getElementById(id);
            const effectiveCSS = isInternalPage() ? "" : css;
            if (!effectiveCSS) {
              if (style) { style.remove(); }
              return;
            }

            if (!style) {
              style = document.createElement("style");
              style.id = id;
              style.setAttribute("data-glide-page-style", "true");
            }

            if (style.textContent !== effectiveCSS) {
              style.textContent = effectiveCSS;
            }

            const target = document.head || document.documentElement || document.body;
            if (target && style.parentNode !== target) {
              target.appendChild(style);
            }
          };

          const runtimeKey = (property) => "glideOriginal" + property.replace(/-([a-z])/g, (_, letter) => letter.toUpperCase());

          const rememberProperty = (element, property) => {
            const key = runtimeKey(property);
            if (key in element.dataset) { return; }
            const value = element.style.getPropertyValue(property);
            const priority = element.style.getPropertyPriority(property);
            element.dataset[key] = value || emptyMarker;
            element.dataset[key + "Priority"] = priority || emptyMarker;
          };

          const restoreProperty = (element, property) => {
            const key = runtimeKey(property);
            if (!(key in element.dataset)) { return; }
            const value = element.dataset[key];
            const priority = element.dataset[key + "Priority"];
            if (!value || value === emptyMarker) {
              element.style.removeProperty(property);
            } else {
              element.style.setProperty(property, value, priority === emptyMarker ? "" : priority);
            }
            delete element.dataset[key];
            delete element.dataset[key + "Priority"];
          };

          const setRuntimeProperty = (state, element, property, value) => {
            rememberProperty(element, property);
            element.style.setProperty(property, value, "important");
            state.darkenedElements.add(element);
          };

          const parseColor = (value) => {
            if (!value || value === "transparent") { return null; }
            const match = String(value).match(/rgba?\\(([^)]+)\\)/i);
            if (!match) { return null; }
            const parts = match[1]
              .replace(/,/g, " ")
              .replace("/", " ")
              .trim()
              .split(/\\s+/)
              .map(Number);
            if (parts.length < 3 || parts.slice(0, 3).some((part) => Number.isNaN(part))) {
              return null;
            }
            return {
              r: Math.max(0, Math.min(255, parts[0])),
              g: Math.max(0, Math.min(255, parts[1])),
              b: Math.max(0, Math.min(255, parts[2])),
              a: Number.isFinite(parts[3]) ? Math.max(0, Math.min(1, parts[3])) : 1
            };
          };

          const luminance = (color) => ((0.2126 * color.r) + (0.7152 * color.g) + (0.0722 * color.b)) / 255;

          const shouldSkipRuntimeElement = (element) => {
            if (!(element instanceof Element)) { return true; }
            if (element.matches(mediaSelector)) { return true; }
            if (element.closest("[data-glide-page-style]")) { return true; }
            return false;
          };

          const restoreRuntimeDarkening = (state) => {
            for (const element of state.darkenedElements) {
              if (!(element instanceof Element)) { continue; }
              restoreProperty(element, "background-color");
              restoreProperty(element, "color");
              restoreProperty(element, "border-top-color");
              restoreProperty(element, "border-right-color");
              restoreProperty(element, "border-bottom-color");
              restoreProperty(element, "border-left-color");
            }
            state.darkenedElements.clear();
          };

          const applyRuntimeDarkening = (state) => {
            if (isInternalPage() || !state.config.darkReaderCSS || !document.body) {
              restoreRuntimeDarkening(state);
              return;
            }

            const elements = [document.documentElement, document.body, ...document.body.querySelectorAll("*")];
            const count = Math.min(elements.length, 2400);
            for (let index = 0; index < count; index += 1) {
              const element = elements[index];
              if (shouldSkipRuntimeElement(element)) { continue; }

              const computed = getComputedStyle(element);
              const background = parseColor(computed.backgroundColor);
              if (background && background.a > 0.05) {
                const bgLuminance = luminance(background);
                if (bgLuminance > 0.72) {
                  setRuntimeProperty(state, element, "background-color", "var(--glide-dark-surface)");
                } else if (bgLuminance > 0.48) {
                  setRuntimeProperty(state, element, "background-color", "var(--glide-dark-surface-raised)");
                }
              }

              const foreground = parseColor(computed.color);
              if (foreground && foreground.a > 0.05 && luminance(foreground) < 0.38) {
                setRuntimeProperty(state, element, "color", "var(--glide-dark-text)");
              }

              for (const property of ["border-top-color", "border-right-color", "border-bottom-color", "border-left-color"]) {
                const border = parseColor(computed.getPropertyValue(property));
                if (border && border.a > 0.05 && luminance(border) > 0.5) {
                  setRuntimeProperty(state, element, property, "var(--glide-dark-border)");
                }
              }
            }
          };

          const restoreFPS = (state) => {
            if (!state || !state.fpsPatched) { return; }
            window.requestAnimationFrame = state.nativeRequestAnimationFrame;
            window.cancelAnimationFrame = state.nativeCancelAnimationFrame;
            state.fpsPatched = false;
            state.lastFrameTime = 0;
          };

          const applyFPS = (state) => {
            const fps = Number(state.config.fpsLimit || 0);
            if (!Number.isFinite(fps) || fps <= 0) {
              restoreFPS(state);
              return;
            }

            const minInterval = Math.max(1, 1000 / fps);
            state.minFrameInterval = minInterval;

            if (state.fpsPatched) { return; }

            state.fpsPatched = true;
            window.requestAnimationFrame = (callback) => {
              const handle = state.nativeRequestAnimationFrame((now) => {
                const elapsed = state.lastFrameTime ? now - state.lastFrameTime : minInterval;
                const wait = state.minFrameInterval - elapsed;
                if (wait <= 0) {
                  state.lastFrameTime = now;
                  callback(now);
                  return;
                }

                const timeout = window.setTimeout(() => {
                  state.pendingFrameTimeouts.delete(handle);
                  const adjustedNow = performance.now();
                  state.lastFrameTime = adjustedNow;
                  callback(adjustedNow);
                }, wait);
                state.pendingFrameTimeouts.set(handle, timeout);
              });
              return handle;
            };

            window.cancelAnimationFrame = (handle) => {
              const timeout = state.pendingFrameTimeouts.get(handle);
              if (timeout) {
                window.clearTimeout(timeout);
                state.pendingFrameTimeouts.delete(handle);
              }
              state.nativeCancelAnimationFrame(handle);
            };
          };

          const applyAll = () => {
            const state = window.__glidePageControls;
            if (!state) { return; }
            toggleRootFlags(state);
            installStyle("glide-dark-reader", state.config.darkReaderCSS);
            installStyle("glide-stylus-catppuccin", state.config.stylusCSS);
            applyRuntimeDarkening(state);
            applyFPS(state);
          };

          if (!window.__glidePageControls) {
            const state = {
              config: nextConfig,
              nativeRequestAnimationFrame: window.requestAnimationFrame.bind(window),
              nativeCancelAnimationFrame: window.cancelAnimationFrame.bind(window),
              fpsPatched: false,
              lastFrameTime: 0,
              minFrameInterval: 0,
              pendingFrameTimeouts: new Map(),
              darkenedElements: new Set(),
              observer: null,
              observerTimer: 0
            };

            window.__glidePageControls = state;
            window.__glideApplyPageControls = (config) => {
              state.config = config || nextConfig;
              applyAll();
            };

            const startObserver = () => {
              if (state.observer || !document.documentElement) { return; }
              state.observer = new MutationObserver(() => {
                if (state.observerTimer) { return; }
                state.observerTimer = window.setTimeout(() => {
                  state.observerTimer = 0;
                  applyAll();
                }, 80);
              });
              state.observer.observe(document.documentElement, {
                childList: true,
                subtree: true
              });
            };

            if (document.readyState === "loading") {
              document.addEventListener("DOMContentLoaded", () => {
                applyAll();
                startObserver();
              }, { once: true });
            } else {
              startObserver();
            }
          }

          window.__glideApplyPageControls(nextConfig);
        })();
        """
    }

    private static func darkReaderCSS(for theme: BrowserDarkReaderTheme) -> String {
        switch theme {
        case .zenCopy:
            return pageDarkCSS(
                background: "#1e1e2e",
                mantle: "#181825",
                surface: "#313244",
                surfaceRaised: "#45475a",
                text: "#e8e6e3",
                mutedText: "#bac2de",
                border: "#585b70",
                accent: "#89b4fa",
                visited: "#cba6f7",
                selection: "#585b70"
            )
        case .catppuccinMocha:
            return pageDarkCSS(
                background: "#1e1e2e",
                mantle: "#181825",
                surface: "#313244",
                surfaceRaised: "#45475a",
                text: "#cdd6f4",
                mutedText: "#bac2de",
                border: "#585b70",
                accent: "#89b4fa",
                visited: "#cba6f7",
                selection: "#45475a"
            )
        case .catppuccinMochaDark:
            return pageDarkCSS(
                background: "#0b0d16",
                mantle: "#06070d",
                surface: "#11111b",
                surfaceRaised: "#1e1e2e",
                text: "#e6e9ff",
                mutedText: "#a6adc8",
                border: "#313244",
                accent: "#89b4fa",
                visited: "#f5c2e7",
                selection: "#45475a"
            )
        }
    }

    private static func pageDarkCSS(
        background: String,
        mantle: String,
        surface: String,
        surfaceRaised: String,
        text: String,
        mutedText: String,
        border: String,
        accent: String,
        visited: String,
        selection: String
    ) -> String {
        """
        :root {
          color-scheme: dark !important;
          accent-color: \(accent) !important;
          --glide-dark-bg: \(background);
          --glide-dark-mantle: \(mantle);
          --glide-dark-surface: \(surface);
          --glide-dark-surface-raised: \(surfaceRaised);
          --glide-dark-text: \(text);
          --glide-dark-muted: \(mutedText);
          --glide-dark-border: \(border);
          --glide-dark-accent: \(accent);
          --glide-dark-visited: \(visited);
          --glide-dark-selection: \(selection);
        }

        html[data-glide-dark-reader="true"],
        html[data-glide-dark-reader="true"] body,
        html[data-glide-dark-reader="true"] body > * {
          background-color: var(--glide-dark-bg) !important;
          color: var(--glide-dark-text) !important;
        }

        html[data-glide-dark-reader="true"] :where(
          body,
          main,
          article,
          section,
          nav,
          aside,
          header,
          footer,
          dialog,
          form,
          [role="main"],
          [role="navigation"],
          [role="dialog"],
          [class*="page" i],
          [class*="layout" i],
          [class*="wrapper" i],
          [class*="container" i],
          [class*="content" i],
          [class*="card" i],
          [class*="panel" i],
          [class*="modal" i],
          [class*="popover" i],
          [class*="menu" i],
          [class*="sidebar" i],
          [class*="toolbar" i]
        ) {
          background-color: var(--glide-dark-bg) !important;
          color: var(--glide-dark-text) !important;
          border-color: var(--glide-dark-border) !important;
        }

        html[data-glide-dark-reader="true"] :where(
          div,
          span,
          p,
          li,
          label,
          summary,
          td,
          th,
          dd,
          dt
        ) {
          color: inherit;
          border-color: var(--glide-dark-border) !important;
        }

        html[data-glide-dark-reader="true"] :where(
          div,
          section,
          article,
          aside,
          header,
          footer,
          nav,
          form,
          ul,
          ol,
          li,
          table,
          tr,
          td,
          th,
          [style*="background" i],
          [bgcolor],
          [class*="surface" i],
          [class*="box" i],
          [class*="tile" i],
          [class*="item" i],
          [class*="result" i]
        ) {
          box-shadow: none !important;
          text-shadow: none !important;
        }

        html[data-glide-dark-reader="true"] a,
        html[data-glide-dark-reader="true"] a:link {
          color: var(--glide-dark-accent) !important;
        }

        html[data-glide-dark-reader="true"] a:visited {
          color: var(--glide-dark-visited) !important;
        }

        html[data-glide-dark-reader="true"] :where(
          input,
          textarea,
          select,
          button,
          [contenteditable="true"]
        ) {
          color-scheme: dark !important;
          background-color: var(--glide-dark-surface) !important;
          color: var(--glide-dark-text) !important;
          border-color: var(--glide-dark-border) !important;
          caret-color: var(--glide-dark-accent) !important;
        }

        html[data-glide-dark-reader="true"] :where(
          button,
          input[type="button"],
          input[type="submit"],
          input[type="reset"],
          [role="button"]
        ) {
          background-color: var(--glide-dark-surface-raised) !important;
          color: var(--glide-dark-text) !important;
        }

        html[data-glide-dark-reader="true"] :where(
          table,
          thead,
          tbody,
          tfoot,
          tr,
          pre,
          code,
          kbd,
          samp,
          blockquote
        ) {
          background-color: var(--glide-dark-mantle) !important;
          color: var(--glide-dark-text) !important;
          border-color: var(--glide-dark-border) !important;
        }

        html[data-glide-dark-reader="true"] hr {
          border-color: var(--glide-dark-border) !important;
          background-color: var(--glide-dark-border) !important;
        }

        html[data-glide-dark-reader="true"] ::selection {
          background-color: var(--glide-dark-selection) !important;
          color: var(--glide-dark-text) !important;
        }

        html[data-glide-dark-reader="true"] ::placeholder {
          color: var(--glide-dark-muted) !important;
          opacity: 0.82 !important;
        }

        html[data-glide-dark-reader="true"] :where(
          img,
          picture,
          video,
          canvas,
          svg,
          iframe,
          [style*="background-image" i]
        ) {
          filter: none !important;
        }
        """
    }

    private static func stylusCatppuccinCSS() -> String {
        """
        :root {
          --ctp-rosewater: #f5e0dc;
          --ctp-flamingo: #f2cdcd;
          --ctp-pink: #f5c2e7;
          --ctp-mauve: #cba6f7;
          --ctp-red: #f38ba8;
          --ctp-peach: #fab387;
          --ctp-yellow: #f9e2af;
          --ctp-green: #a6e3a1;
          --ctp-teal: #94e2d5;
          --ctp-sky: #89dceb;
          --ctp-sapphire: #74c7ec;
          --ctp-blue: #89b4fa;
          --ctp-lavender: #b4befe;
          --ctp-text: #cdd6f4;
          --ctp-subtext: #bac2de;
          --ctp-overlay: #6c7086;
          --ctp-surface2: #585b70;
          --ctp-surface1: #45475a;
          --ctp-surface0: #313244;
          --ctp-base: #1e1e2e;
          --ctp-mantle: #181825;
          --ctp-crust: #11111b;
        }

        html {
          background: var(--ctp-base) !important;
        }

        body {
          background:
            radial-gradient(circle at top right, rgba(203, 166, 247, 0.08), transparent 28rem),
            radial-gradient(circle at bottom left, rgba(137, 180, 250, 0.07), transparent 24rem),
            var(--ctp-base) !important;
          color: var(--ctp-text) !important;
        }

        main,
        article,
        section,
        nav,
        aside,
        header,
        footer,
        form,
        [class*="card"],
        [class*="panel"],
        [class*="modal"],
        [class*="dialog"],
        [class*="popover"],
        [class*="menu"],
        [class*="sidebar"],
        [class*="toolbar"],
        [class*="container"] {
          border-color: var(--ctp-surface1) !important;
        }

        h1,
        h2,
        h3,
        h4,
        h5,
        h6,
        strong,
        b {
          color: var(--ctp-text) !important;
        }

        small,
        time,
        figcaption,
        [class*="muted"],
        [class*="secondary"],
        [class*="subtitle"],
        [class*="description"] {
          color: var(--ctp-subtext) !important;
        }

        a,
        a:link,
        [role="link"] {
          color: var(--ctp-blue) !important;
        }

        a:visited {
          color: var(--ctp-mauve) !important;
        }

        input,
        textarea,
        select,
        button,
        [role="button"],
        [contenteditable="true"] {
          border-color: var(--ctp-surface2) !important;
          box-shadow: none !important;
        }

        input:focus,
        textarea:focus,
        select:focus,
        button:focus,
        [tabindex]:focus {
          outline-color: var(--ctp-mauve) !important;
        }

        pre,
        code,
        kbd,
        samp,
        blockquote {
          background-color: var(--ctp-mantle) !important;
          color: var(--ctp-text) !important;
          border-color: var(--ctp-surface1) !important;
        }

        mark,
        [aria-selected="true"],
        [class*="selected"],
        [class*="active"] {
          background-color: rgba(203, 166, 247, 0.22) !important;
          color: var(--ctp-text) !important;
        }

        [class*="success"],
        [class*="online"] {
          color: var(--ctp-green) !important;
        }

        [class*="warning"],
        [class*="notice"] {
          color: var(--ctp-yellow) !important;
        }

        [class*="danger"],
        [class*="error"] {
          color: var(--ctp-red) !important;
        }

        [data-testid*="sidebar"],
        [aria-label*="sidebar" i],
        [class*="sidebar"] {
          background-color: rgba(24, 24, 37, 0.88) !important;
        }

        [data-testid*="conversation"],
        [class*="message"],
        [class*="chat"] {
          border-color: rgba(88, 91, 112, 0.72) !important;
        }

        .g,
        [data-sokoban-container],
        #search,
        #links,
        #results,
        [class*="result"] {
          border-color: var(--ctp-surface1) !important;
        }
        """
    }

    private static func startPageHTML() -> String {
        """
        <!doctype html>
        <html lang="en">
        <head>
          <meta charset="utf-8">
          <meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
          <title>Start Page</title>
          <style>
            :root {
              color-scheme: dark;
              background: transparent;
            }
            * { box-sizing: border-box; }
            html, body {
              margin: 0;
              min-height: 100vh;
              background: transparent;
            }
            body {
              color: transparent;
            }
          </style>
        </head>
        <body aria-label="Blank start page"></body>
        </html>
        """
    }

    private func bindWebViewState() {
        observations = [
            webView.observe(\.title, options: [.initial, .new]) { [weak self] webView, _ in
                Task { @MainActor in
                    let fallback: String
                    if self?.isContainedBrowser == true {
                        fallback = "Contained Browser"
                    } else {
                        fallback = self?.isPrivate == true ? "Private Tab" : "New Tab"
                    }
                    let title = webView.title?.trimmingCharacters(in: .whitespacesAndNewlines)
                    self?.title = title?.isEmpty == false ? title ?? fallback : fallback
                }
            },
            webView.observe(\.url, options: [.initial, .new]) { [weak self] webView, _ in
                Task { @MainActor in
                    self?.url = webView.url
                    if self?.isContainedBrowser == true,
                       webView.url?.host == "browser.local" {
                        self?.addressText = BrowserDefaults.containedBrowserStartURL.absoluteString
                        return
                    }
                    if Self.isStartPageURL(webView.url) {
                        self?.addressText = ""
                        return
                    }
                    if let absoluteString = webView.url?.absoluteString {
                        self?.addressText = absoluteString
                    }
                }
            },
            webView.observe(\.isLoading, options: [.initial, .new]) { [weak self] webView, _ in
                Task { @MainActor in
                    self?.isLoading = webView.isLoading
                }
            },
            webView.observe(\.estimatedProgress, options: [.initial, .new]) { [weak self] webView, _ in
                Task { @MainActor in
                    self?.estimatedProgress = webView.estimatedProgress
                }
            },
            webView.observe(\.canGoBack, options: [.initial, .new]) { [weak self] webView, _ in
                Task { @MainActor in
                    self?.canGoBack = webView.canGoBack
                }
            },
            webView.observe(\.canGoForward, options: [.initial, .new]) { [weak self] webView, _ in
                Task { @MainActor in
                    self?.canGoForward = webView.canGoForward
                }
            }
        ]
    }

    static func destinationURL(
        from rawValue: String,
        searchEngine: BrowserSearchEngine,
        customSearchTemplate: String
    ) -> URL {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else {
            return homeURL
        }

        if let url = URL(string: trimmed),
           let scheme = url.scheme?.lowercased(),
           ["http", "https", "file"].contains(scheme) {
            return url
        }

        let lowercased = trimmed.lowercased()
        let localAddress = lowercased == "localhost" || lowercased.hasPrefix("localhost:") || lowercased.hasPrefix("127.0.0.1")
        let looksLikeHost = trimmed.contains(".") || trimmed.contains(":")
        let scheme = localAddress ? "http" : "https"

        if looksLikeHost,
           let encodedAddress = trimmed.addingPercentEncoding(withAllowedCharacters: .urlFragmentAllowed),
           let url = URL(string: "\(scheme)://\(encodedAddress)") {
            return url
        }

        return searchEngine.searchURL(for: trimmed, customTemplate: customSearchTemplate)
    }

    nonisolated static func isStartPageURL(_ url: URL?) -> Bool {
        url?.host == BrowserDefaults.homeURL.host
    }

    private func installGestureControls() {
        let twoFingerPan = UIPanGestureRecognizer(target: self, action: #selector(handleTwoFingerPan(_:)))
        twoFingerPan.minimumNumberOfTouches = 2
        twoFingerPan.maximumNumberOfTouches = 2
        twoFingerPan.cancelsTouchesInView = false
        twoFingerPan.delegate = self

        let threeFingerPan = UIPanGestureRecognizer(target: self, action: #selector(handleThreeFingerPan(_:)))
        threeFingerPan.minimumNumberOfTouches = 3
        threeFingerPan.maximumNumberOfTouches = 3
        threeFingerPan.cancelsTouchesInView = false
        threeFingerPan.delegate = self

        if let pinchGestureRecognizer = webView.scrollView.pinchGestureRecognizer {
            twoFingerPan.require(toFail: pinchGestureRecognizer)
            threeFingerPan.require(toFail: pinchGestureRecognizer)
        }

        webView.addGestureRecognizer(twoFingerPan)
        webView.addGestureRecognizer(threeFingerPan)
    }

    @objc private func handleTwoFingerPan(_ recognizer: UIPanGestureRecognizer) {
        guard recognizer.state == .ended else { return }
        guard shouldIgnoreCustomPanGestures() == false else { return }
        let translation = recognizer.translation(in: webView)
        let absX = abs(translation.x)
        let absY = abs(translation.y)
        let dominantDistance = max(absX, absY)
        guard dominantDistance >= Self.customPanMinimumDistance else { return }

        if absY >= absX * Self.customPanDirectionRatio {
            onTwoFingerSwipe?(0, translation.y)
        } else if absX >= absY * Self.customPanDirectionRatio {
            onTwoFingerSwipe?(translation.x, 0)
        }
    }

    @objc private func handleThreeFingerPan(_ recognizer: UIPanGestureRecognizer) {
        guard recognizer.state == .ended else { return }
        guard shouldIgnoreCustomPanGestures() == false else { return }
        let translation = recognizer.translation(in: webView)
        guard abs(translation.x) >= Self.customPanMinimumDistance,
              abs(translation.x) >= abs(translation.y) * Self.customPanDirectionRatio else { return }
        onThreeFingerSwipe?(translation.x)
    }

    private func shouldIgnoreCustomPanGestures() -> Bool {
        let scrollView = webView.scrollView
        if scrollView.isZooming || scrollView.isZoomBouncing {
            return true
        }

        if let pinch = scrollView.pinchGestureRecognizer {
            switch pinch.state {
            case .began, .changed, .ended, .cancelled:
                return true
            default:
                break
            }
        }

        return abs(scrollView.zoomScale - scrollView.minimumZoomScale) > 0.01
    }

    private func registerDownload(_ item: BrowserDownloadItem, for identifier: ObjectIdentifier) {
        activeDownloads[identifier] = item
        onDownloadUpdated?(item)
    }

    private func finishDownload(for identifier: ObjectIdentifier) {
        guard var item = activeDownloads[identifier] else { return }
        item.state = .finished
        activeDownloads[identifier] = item
        onDownloadUpdated?(item)
        activeDownloads.removeValue(forKey: identifier)
    }

    private func failDownload(for identifier: ObjectIdentifier, error: Error) {
        guard var item = activeDownloads[identifier] else { return }
        item.state = .failed
        item.errorMessage = error.localizedDescription
        activeDownloads[identifier] = item
        onDownloadUpdated?(item)
        activeDownloads.removeValue(forKey: identifier)
    }

    nonisolated static func downloadDestination(for suggestedFilename: String) throws -> URL {
        let directory = try downloadsDirectory()
        let safeName = safeFilename(suggestedFilename)
        var candidate = directory.appendingPathComponent(safeName)

        if FileManager.default.fileExists(atPath: candidate.path) == false {
            return candidate
        }

        let baseName = candidate.deletingPathExtension().lastPathComponent
        let pathExtension = candidate.pathExtension

        for index in 2...999 {
            let filename = pathExtension.isEmpty ? "\(baseName)-\(index)" : "\(baseName)-\(index).\(pathExtension)"
            candidate = directory.appendingPathComponent(filename)
            if FileManager.default.fileExists(atPath: candidate.path) == false {
                return candidate
            }
        }

        return directory.appendingPathComponent("\(UUID().uuidString)-\(safeName)")
    }

    nonisolated static func temporaryDownloadDestination(for suggestedFilename: String) throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("GlideIncomingDownloads", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let safeName = safeFilename(suggestedFilename)
        return directory.appendingPathComponent("\(UUID().uuidString)-\(safeName)")
    }

    nonisolated static func downloadFilename(for url: URL, suggestedFilename: String?) -> String {
        let trimmedSuggestion = suggestedFilename?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if trimmedSuggestion.isEmpty == false,
           Self.isStartPageURL(url) == false {
            return safeFilename(trimmedSuggestion)
        }

        let lastPathComponent = url.lastPathComponent.trimmingCharacters(in: .whitespacesAndNewlines)
        if lastPathComponent.isEmpty == false {
            return safeFilename(lastPathComponent)
        }

        return safeFilename(url.host ?? "download")
    }

    nonisolated private static func downloadsDirectory() throws -> URL {
        let documents = try FileManager.default.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directory = documents.appendingPathComponent("Downloads", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    nonisolated private static func safeFilename(_ filename: String) -> String {
        let trimmed = filename.trimmingCharacters(in: .whitespacesAndNewlines)
        let fallback = trimmed.isEmpty ? "download" : trimmed
        let illegal = CharacterSet(charactersIn: "/\\?%*|\"<>:")
        return fallback
            .components(separatedBy: illegal)
            .joined(separator: "-")
    }
}

extension BrowserTab: WKNavigationDelegate {
    nonisolated func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        preferences: WKWebpagePreferences,
        decisionHandler: @escaping (WKNavigationActionPolicy, WKWebpagePreferences) -> Void
    ) {
        let requestURL = navigationAction.request.url
        let isProtectionWhitelisted = BrowserWebsitePrivacyPolicy.matches(
            url: requestURL,
            blockedDomains: navigationProtectionWhitelistDomains
        )
        preferences.allowsContentJavaScript = isProtectionWhitelisted || !navigationScriptBlockingEnabled
        preferences.preferredContentMode = Self.webpageContentMode(for: navigationWebsiteDisplayMode)
        if let promotedURL = Self.promotedContainedURL(from: navigationAction) {
            decisionHandler(.cancel, preferences)
            webView.load(Self.websiteRequest(
                for: promotedURL,
                regionProfile: navigationRegionTricksEnabled ? navigationRegionTrickProfile : nil
            ))
        } else if let requestURL {
            let adjustedURL = Self.privacyAdjustedURL(
                for: requestURL,
                upgradeHTTPS: navigationHTTPSUpgradeEnabled,
                stripTrackingParameters: navigationTrackingParameterStrippingEnabled && isProtectionWhitelisted == false,
                blockBounceTracking: navigationBounceTrackingProtectionEnabled && isProtectionWhitelisted == false
            )
            if adjustedURL != requestURL {
                decisionHandler(.cancel, preferences)
                webView.load(Self.websiteRequest(
                    for: adjustedURL,
                    regionProfile: navigationRegionTricksEnabled ? navigationRegionTrickProfile : nil
                ))
                return
            }

            if navigationAction.shouldPerformDownload {
                decisionHandler(.download, preferences)
            } else {
                decisionHandler(.allow, preferences)
            }
        } else if navigationAction.shouldPerformDownload {
            decisionHandler(.download, preferences)
        } else {
            decisionHandler(.allow, preferences)
        }
    }

    nonisolated func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationResponse: WKNavigationResponse,
        decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void
    ) {
        if navigationResponse.canShowMIMEType {
            decisionHandler(.allow)
        } else {
            decisionHandler(.download)
        }
    }

    nonisolated func webView(_ webView: WKWebView, navigationAction: WKNavigationAction, didBecome download: WKDownload) {
        download.delegate = self
    }

    nonisolated func webView(_ webView: WKWebView, navigationResponse: WKNavigationResponse, didBecome download: WKDownload) {
        download.delegate = self
    }

    nonisolated func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            self.isLoading = false
            self.applyPageStyleOverrides()
            self.applyPrivacyOverrides()
            self.applyRegionTricks()
            self.capturePageIdentity { [weak self] in
                guard let self else { return }
                self.onNavigationFinished?(self)
            }
        }
    }

    nonisolated func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        Task { @MainActor [weak self] in
            self?.isLoading = false
        }
    }

    nonisolated func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        Task { @MainActor [weak self] in
            self?.isLoading = false
        }
    }
}

extension BrowserTab: WKDownloadDelegate {
    nonisolated func download(
        _ download: WKDownload,
        decideDestinationUsing response: URLResponse,
        suggestedFilename: String,
        completionHandler: @escaping (URL?) -> Void
    ) {
        let identifier = ObjectIdentifier(download)

        do {
            let destination = try Self.downloadDestination(for: suggestedFilename)
            let temporaryDestination = try Self.temporaryDownloadDestination(for: destination.lastPathComponent)
            let item = BrowserDownloadItem(
                filename: destination.lastPathComponent,
                sourceURLString: response.url?.absoluteString ?? "",
                localPath: temporaryDestination.path,
                state: .inProgress
            )

            Task { @MainActor [weak self] in
                self?.registerDownload(item, for: identifier)
            }
            completionHandler(temporaryDestination)
        } catch {
            Task { @MainActor [weak self] in
                self?.failDownload(for: identifier, error: error)
            }
            completionHandler(nil)
        }
    }

    nonisolated func downloadDidFinish(_ download: WKDownload) {
        let identifier = ObjectIdentifier(download)
        Task { @MainActor [weak self] in
            self?.finishDownload(for: identifier)
        }
    }

    nonisolated func download(_ download: WKDownload, didFailWithError error: Error, resumeData: Data?) {
        let identifier = ObjectIdentifier(download)
        Task { @MainActor [weak self] in
            self?.failDownload(for: identifier, error: error)
        }
    }
}

extension BrowserTab: WKUIDelegate {
    nonisolated func webView(
        _ webView: WKWebView,
        createWebViewWith configuration: WKWebViewConfiguration,
        for navigationAction: WKNavigationAction,
        windowFeatures: WKWindowFeatures
    ) -> WKWebView? {
        guard navigationAction.targetFrame == nil else { return nil }

        if let requestURL = navigationAction.request.url {
            webView.load(Self.websiteRequest(
                for: requestURL,
                regionProfile: navigationRegionTricksEnabled ? navigationRegionTrickProfile : nil
            ))
        }

        return nil
    }

    nonisolated func webView(
        _ webView: WKWebView,
        runJavaScriptAlertPanelWithMessage message: String,
        initiatedByFrame frame: WKFrameInfo,
        completionHandler: @escaping () -> Void
    ) {
        completionHandler()
    }

    nonisolated func webView(
        _ webView: WKWebView,
        runJavaScriptConfirmPanelWithMessage message: String,
        initiatedByFrame frame: WKFrameInfo,
        completionHandler: @escaping (Bool) -> Void
    ) {
        completionHandler(true)
    }

    nonisolated func webView(
        _ webView: WKWebView,
        runJavaScriptTextInputPanelWithPrompt prompt: String,
        defaultText: String?,
        initiatedByFrame frame: WKFrameInfo,
        completionHandler: @escaping (String?) -> Void
    ) {
        completionHandler(defaultText)
    }

    @available(iOS 15.0, *)
    nonisolated func webView(
        _ webView: WKWebView,
        requestMediaCapturePermissionFor origin: WKSecurityOrigin,
        initiatedByFrame frame: WKFrameInfo,
        type: WKMediaCaptureType,
        decisionHandler: @escaping (WKPermissionDecision) -> Void
    ) {
        decisionHandler(.prompt)
    }

    @available(iOS 18.4, *)
    nonisolated func webView(
        _ webView: WKWebView,
        runOpenPanelWith parameters: WKOpenPanelParameters,
        initiatedByFrame frame: WKFrameInfo,
        completionHandler: @escaping ([URL]?) -> Void
    ) {
        Task { @MainActor [weak self] in
            self?.onFilePickerRequested?(parameters.allowsMultipleSelection, completionHandler)
        }
    }
}

extension BrowserTab: UIGestureRecognizerDelegate {
    nonisolated func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        if gestureRecognizer is UIPinchGestureRecognizer || otherGestureRecognizer is UIPinchGestureRecognizer {
            return false
        }
        return true
    }
}
