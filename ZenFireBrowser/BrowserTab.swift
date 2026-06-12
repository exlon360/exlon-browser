import Combine
import AVFoundation
import Foundation
import UIKit
import WebKit

enum BrowserDefaults {
    static let homeURL = URL(string: "https://glide.local/start")!
    static let containedBrowserStartURL = URL(string: "https://lite.duckduckgo.com/lite/")!
}

@MainActor
final class BrowserTab: NSObject, Identifiable, ObservableObject {
    let id = UUID()
    let isPrivate: Bool
    let isContainedBrowser: Bool
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
    @Published var isFPSForcerEnabled: Bool
    @Published var forcedFPS: Double

    var onNavigationFinished: (@MainActor (BrowserTab) -> Void)?
    var onDownloadUpdated: (@MainActor (BrowserDownloadItem) -> Void)?
    var onTwoFingerSwipe: (@MainActor (CGFloat, CGFloat) -> Void)?
    var onThreeFingerSwipe: (@MainActor (CGFloat) -> Void)?
    var onFilePickerRequested: (@MainActor (Bool, @escaping ([URL]?) -> Void) -> Void)?

    private var observations: [NSKeyValueObservation] = []
    private var activeDownloads: [ObjectIdentifier: BrowserDownloadItem] = [:]
    private static let sharedProcessPool = WKProcessPool()

    init(
        startURL: URL = BrowserDefaults.homeURL,
        isPrivate: Bool = false,
        usesPersistentStorage: Bool = true,
        isContainedBrowser: Bool = false,
        isDarkReaderEnabled: Bool = false,
        darkReaderTheme: BrowserDarkReaderTheme = .zenCopy,
        isStylusCatppuccinEnabled: Bool = false,
        isAdBlockerEnabled: Bool = true,
        isFPSForcerEnabled: Bool = false,
        forcedFPS: Double = 60
    ) {
        self.isPrivate = isPrivate
        self.isContainedBrowser = isContainedBrowser
        self.isDarkReaderEnabled = isDarkReaderEnabled
        self.darkReaderTheme = darkReaderTheme
        self.isStylusCatppuccinEnabled = isStylusCatppuccinEnabled
        self.isAdBlockerEnabled = isAdBlockerEnabled
        self.isFPSForcerEnabled = isFPSForcerEnabled
        self.forcedFPS = forcedFPS
        self.title = isContainedBrowser ? "Contained Browser" : (isPrivate ? "Private Start" : "Start")
        self.url = startURL
        self.addressText = startURL.absoluteString

        Self.configureAudioPlayback()

        let configuration = WKWebViewConfiguration()
        configuration.processPool = Self.sharedProcessPool
        configuration.userContentController = WKUserContentController()
        configuration.allowsInlineMediaPlayback = true
        configuration.allowsAirPlayForMediaPlayback = true
        configuration.allowsPictureInPictureMediaPlayback = true
        configuration.suppressesIncrementalRendering = false
        configuration.mediaTypesRequiringUserActionForPlayback = []
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = true
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        if #available(iOS 14.0, *) {
            configuration.limitsNavigationsToAppBoundDomains = false
        }
        configuration.websiteDataStore = (isPrivate || usesPersistentStorage == false) ? .nonPersistent() : .default()

        self.webView = WKWebView(frame: .zero, configuration: configuration)
        super.init()

        webView.customUserAgent = Self.safariCompatibleUserAgent()
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

    func load(_ url: URL) {
        if isContainedBrowser == false,
           Self.isStartPageURL(url) {
            loadStartPage()
            return
        }

        webView.load(Self.websiteRequest(for: url))
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

    func setDarkReaderEnabled(_ enabled: Bool) {
        isDarkReaderEnabled = enabled
        rebuildWebKitUserContent()
        applyPageStyleOverrides()
    }

    func setDarkReaderTheme(_ theme: BrowserDarkReaderTheme) {
        darkReaderTheme = theme
        rebuildWebKitUserContent()
        applyPageStyleOverrides()
    }

    func setStylusCatppuccinEnabled(_ enabled: Bool) {
        isStylusCatppuccinEnabled = enabled
        rebuildWebKitUserContent()
        applyPageStyleOverrides()
    }

    func setFPSForcerEnabled(_ enabled: Bool) {
        isFPSForcerEnabled = enabled
        rebuildWebKitUserContent()
        applyPageStyleOverrides()
    }

    func setForcedFPS(_ fps: Double) {
        forcedFPS = fps
        rebuildWebKitUserContent()
        applyPageStyleOverrides()
    }

    func setAdBlockerEnabled(_ enabled: Bool, reloadAfterChange: Bool = true) {
        isAdBlockerEnabled = enabled
        rebuildWebKitUserContent(reloadAfterChange: reloadAfterChange)
    }

    private func applyPageStyleOverrides() {
        webView.evaluateJavaScript(Self.pageControlsScript(
            darkReaderCSS: activeDarkReaderCSS,
            stylusCSS: activeStylusCSS,
            fpsLimit: activeFPSLimit
        ))
    }

    private func rebuildWebKitUserContent(
        reloadAfterChange: Bool = false,
        completion: (() -> Void)? = nil
    ) {
        BrowserContentBlocker.setEnabled(
            isAdBlockerEnabled,
            on: webView.configuration.userContentController,
            additionalUserScripts: pageControlUserScripts()
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

    private func pageControlUserScripts() -> [WKUserScript] {
        [
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

    private nonisolated static func websiteRequest(for url: URL) -> URLRequest {
        var request = URLRequest(url: url, cachePolicy: .useProtocolCachePolicy, timeoutInterval: 30)
        request.setValue("text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8", forHTTPHeaderField: "Accept")
        if #available(iOS 12.0, *) {
            request.networkServiceType = .responsiveData
        }
        return request
    }

    private static func safariCompatibleUserAgent() -> String {
        if UIDevice.current.userInterfaceIdiom == .pad {
            return "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Safari/605.1.15"
        }

        return "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1"
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
              display: grid;
              grid-template-rows: auto 1fr;
              width: 100%;
              height: 100%;
              background:
                radial-gradient(circle at 84% 12%, rgba(169, 180, 200, 0.16), transparent 28%),
                linear-gradient(135deg, #07090d 0%, #101218 46%, #07090d 100%);
            }
            header {
              display: grid;
              gap: 9px;
              padding: 12px;
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
              position: relative;
              min-height: 0;
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
              bottom: 12px;
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
              header { padding: 10px; }
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
        guard webView.scrollView.isZooming == false,
              webView.scrollView.isZoomBouncing == false else { return }
        let translation = recognizer.translation(in: webView)
        let dominantDistance = max(abs(translation.x), abs(translation.y))
        guard dominantDistance > 72 else { return }
        onTwoFingerSwipe?(translation.x, translation.y)
    }

    @objc private func handleThreeFingerPan(_ recognizer: UIPanGestureRecognizer) {
        guard recognizer.state == .ended else { return }
        guard webView.scrollView.isZooming == false,
              webView.scrollView.isZoomBouncing == false else { return }
        let translation = recognizer.translation(in: webView)
        guard abs(translation.x) > 72, abs(translation.x) > abs(translation.y) else { return }
        onThreeFingerSwipe?(translation.x)
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
        preferences.allowsContentJavaScript = true
        if let promotedURL = Self.promotedContainedURL(from: navigationAction) {
            decisionHandler(.cancel, preferences)
            webView.load(Self.websiteRequest(for: promotedURL))
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
            self.onNavigationFinished?(self)
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
            webView.load(URLRequest(url: requestURL))
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
        true
    }
}
