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
    @Published var isAdBlockerEnabled: Bool

    var onNavigationFinished: (@MainActor (BrowserTab) -> Void)?
    var onDownloadUpdated: (@MainActor (BrowserDownloadItem) -> Void)?
    var onTwoFingerSwipe: (@MainActor (CGFloat) -> Void)?
    var onThreeFingerSwipe: (@MainActor (CGFloat) -> Void)?
    var onFilePickerRequested: (@MainActor (Bool, @escaping ([URL]?) -> Void) -> Void)?

    private var observations: [NSKeyValueObservation] = []
    private var activeDownloads: [ObjectIdentifier: BrowserDownloadItem] = [:]
    private static let sharedProcessPool = WKProcessPool()

    init(
        startURL: URL = BrowserDefaults.homeURL,
        isPrivate: Bool = false,
        usesPersistentStorage: Bool = false,
        isContainedBrowser: Bool = false,
        isDarkReaderEnabled: Bool = false,
        isAdBlockerEnabled: Bool = true
    ) {
        self.isPrivate = isPrivate
        self.isContainedBrowser = isContainedBrowser
        self.isDarkReaderEnabled = isDarkReaderEnabled
        self.isAdBlockerEnabled = isAdBlockerEnabled
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

        if isAdBlockerEnabled {
            BrowserContentBlocker.setEnabled(true, on: webView.configuration.userContentController) { [weak self] _ in
                Task { @MainActor in
                    self?.loadInitialContent(startURL)
                }
            }
        } else {
            loadInitialContent(startURL)
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
        applyDarkReaderStyle()
    }

    func setAdBlockerEnabled(_ enabled: Bool, reloadAfterChange: Bool = true) {
        isAdBlockerEnabled = enabled
        BrowserContentBlocker.setEnabled(enabled, on: webView.configuration.userContentController) { [weak self] _ in
            guard reloadAfterChange else { return }
            Task { @MainActor in
                self?.webView.reload()
            }
        }
    }

    private func applyDarkReaderStyle() {
        let script: String

        if isDarkReaderEnabled {
            script = """
            (() => {
              const existing = document.getElementById('zenfire-dark-reader');
              if (existing) { existing.remove(); }
              const style = document.createElement('style');
              style.id = 'zenfire-dark-reader';
              style.textContent = `
                html, body {
                  background: #0b0d12 !important;
                  color: #dfe6f3 !important;
                }
                html {
                  filter: invert(0.88) hue-rotate(180deg) brightness(0.86) contrast(0.92) !important;
                }
                img, picture, video, canvas, svg, iframe, [style*="background-image"] {
                  filter: invert(1) hue-rotate(180deg) brightness(1.08) contrast(1.08) !important;
                }
                input, textarea, select, button {
                  color-scheme: dark !important;
                }
              `;
              document.head.appendChild(style);
            })();
            """
        } else {
            script = """
            (() => {
              const existing = document.getElementById('zenfire-dark-reader');
              if (existing) { existing.remove(); }
              document.documentElement.style.filter = '';
            })();
            """
        }

        webView.evaluateJavaScript(script)
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

    private static let containedCompatibilityDomains: Set<String> = [
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

    private static let containedCompatibilityPathHints = [
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

    private static let containedShellHosts: Set<String> = [
        "browser.local",
        "duckduckgo.com",
        "lite.duckduckgo.com",
        "html.duckduckgo.com",
        "www.duckduckgo.com"
    ]

    private static func websiteRequest(for url: URL) -> URLRequest {
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

    private static func normalizedHost(for url: URL?) -> String {
        url?.host?.lowercased().replacingOccurrences(of: #"^www\."#, with: "", options: .regularExpression) ?? ""
    }

    private static func domain(_ host: String, matches domains: Set<String>) -> Bool {
        domains.contains(host) || domains.contains(where: { host.hasSuffix("." + $0) })
    }

    private static func isContainedCompatibilityURL(_ url: URL) -> Bool {
        let host = normalizedHost(for: url)
        let path = url.path.lowercased()
        return domain(host, matches: containedCompatibilityDomains) ||
            containedCompatibilityPathHints.contains { hint in
                path == hint || path.hasPrefix(hint + "/") || path.contains(hint + "/")
            }
    }

    private static func redirectedDestinationURL(from url: URL) -> URL? {
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

    private static func promotedContainedURL(from navigationAction: WKNavigationAction) -> URL? {
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
          <link rel="preconnect" href="https://lite.duckduckgo.com">
          <link rel="dns-prefetch" href="//lite.duckduckgo.com">
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
            let audioContext = undefined;

            function destination(raw) {
              const value = raw.trim();
              if (!value) return initialURL;
              if (/^(https?|file):\\/\\//i.test(value)) return value;
              if (/^(localhost|127\\.0\\.0\\.1)(:|\\/|$)/i.test(value)) return "http://" + value;
              if (value.includes(".") || value.includes(":")) return "https://" + value;
              return "https://lite.duckduckgo.com/lite/?q=" + encodeURIComponent(value);
            }

            function hostFor(url) {
              try {
                return new URL(url).hostname.replace(/^www\\./, "").toLowerCase();
              } catch (_) {
                return "";
              }
            }

            function shouldOpenDirect(url) {
              try {
                const parsed = new URL(url);
                const host = parsed.hostname.replace(/^www\\./, "").toLowerCase();
                const path = parsed.pathname.toLowerCase();
                return directDomains.some(domain => host === domain || host.endsWith("." + domain)) ||
                  directPathHints.some(hint => path === hint || path.startsWith(hint + "/") || path.includes(hint + "/"));
              } catch (_) {
                const host = hostFor(url);
                return directDomains.some(domain => host === domain || host.endsWith("." + domain));
              }
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

              if (shouldOpenDirect(url)) {
                showStatus("Opening full site for media and compatibility");
                window.location.assign(url);
                return;
              }

              clearTimeout(frameStatusTimer);
              frame.dataset.target = url;
              frame.src = url;
              frameStatusTimer = setTimeout(() => {
                if (frame.dataset.target === url) {
                  showStatus("Still loading. Open Page is fastest for protected sites");
                }
              }, 2200);

              if (push) {
                stack = stack.slice(0, index + 1);
                stack.push(url);
                index = stack.length - 1;
              }

              updateButtons();
              showStatus("Loading inside contained browser");
            }

            form.addEventListener("submit", event => {
              event.preventDefault();
              openInner(input.value);
            });

            document.querySelectorAll("[data-url]").forEach(button => {
              button.addEventListener("click", () => {
                openInner(button.dataset.url);
              });
            });

            backButton.addEventListener("click", () => {
              if (index <= 0) return;
              index -= 1;
              input.value = stack[index];
              frame.src = stack[index];
              updateButtons();
            });

            forwardButton.addEventListener("click", () => {
              if (index >= stack.length - 1) return;
              index += 1;
              input.value = stack[index];
              frame.src = stack[index];
              updateButtons();
            });

            reloadButton.addEventListener("click", () => {
              if (!input.value) return;
              frame.src = input.value;
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

            openInner(initialURL);
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

        webView.addGestureRecognizer(twoFingerPan)
        webView.addGestureRecognizer(threeFingerPan)
    }

    @objc private func handleTwoFingerPan(_ recognizer: UIPanGestureRecognizer) {
        guard recognizer.state == .ended else { return }
        let translation = recognizer.translation(in: webView)
        guard abs(translation.x) > 72, abs(translation.x) > abs(translation.y) else { return }
        onTwoFingerSwipe?(translation.x)
    }

    @objc private func handleThreeFingerPan(_ recognizer: UIPanGestureRecognizer) {
        guard recognizer.state == .ended else { return }
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
            self.applyDarkReaderStyle()
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
        true
    }
}
