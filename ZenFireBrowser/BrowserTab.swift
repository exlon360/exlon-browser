import Combine
import AVFoundation
import Foundation
import UIKit
import WebKit

enum BrowserDefaults {
    static let homeURL = URL(string: "https://glide.local/start")!
    static let containedBrowserStartURL = URL(string: "https://duckduckgo.com/")!
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

    init(
        startURL: URL = BrowserDefaults.homeURL,
        isPrivate: Bool = false,
        usesPersistentStorage: Bool = true,
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
        configuration.userContentController = WKUserContentController()
        configuration.allowsInlineMediaPlayback = true
        configuration.allowsAirPlayForMediaPlayback = true
        configuration.allowsPictureInPictureMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = true
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        configuration.websiteDataStore = (isPrivate || usesPersistentStorage == false) ? .nonPersistent() : .default()

        self.webView = WKWebView(frame: .zero, configuration: configuration)
        super.init()

        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.allowsBackForwardNavigationGestures = true
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

        webView.load(URLRequest(url: url))
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

    private static func containedBrowserHTML(defaultURLString: String) -> String {
        """
        <!doctype html>
        <html lang="en">
        <head>
          <meta charset="utf-8">
          <meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
          <title>Contained Web Browser</title>
          <style>
            :root {
              color-scheme: dark;
              font-family: -apple-system, BlinkMacSystemFont, "SF Pro Display", "Segoe UI", sans-serif;
              background: #07090d;
              color: #f4f7fb;
            }
            * { box-sizing: border-box; }
            body {
              margin: 0;
              min-height: 100vh;
              display: grid;
              place-items: center;
              padding: 22px;
              background:
                radial-gradient(circle at 78% 18%, rgba(169, 180, 200, 0.18), transparent 32%),
                linear-gradient(135deg, #07090d 0%, #101826 48%, #07090d 100%);
            }
            main {
              width: min(760px, 100%);
              border: 1px solid rgba(169, 180, 200, 0.34);
              border-radius: 8px;
              padding: 18px;
              background: rgba(16, 18, 24, 0.78);
              box-shadow: 0 28px 80px rgba(0, 0, 0, 0.48);
              backdrop-filter: blur(20px);
            }
            .mark {
              width: 42px;
              height: 42px;
              border-radius: 8px;
              display: grid;
              place-items: center;
              margin-bottom: 14px;
              font-size: 22px;
              font-weight: 900;
              color: #07090d;
              background: linear-gradient(135deg, #f4f7fb, #9fb7ff);
            }
            h1 {
              margin: 0 0 7px;
              font-size: clamp(28px, 7vw, 52px);
              line-height: 0.95;
              letter-spacing: 0;
            }
            p {
              margin: 0 0 18px;
              color: #a9b4c8;
              font-size: 15px;
              line-height: 1.45;
            }
            form {
              display: flex;
              gap: 8px;
              padding: 7px;
              border: 1px solid rgba(169, 180, 200, 0.32);
              border-radius: 8px;
              background: rgba(32, 36, 45, 0.86);
            }
            input {
              min-width: 0;
              flex: 1;
              height: 42px;
              border: 0;
              outline: 0;
              color: #f4f7fb;
              background: transparent;
              font-size: 16px;
            }
            button {
              border: 0;
              border-radius: 8px;
              min-height: 42px;
              padding: 0 14px;
              font-weight: 800;
              color: #07090d;
              background: #d6e2ff;
            }
            .chips {
              display: flex;
              flex-wrap: wrap;
              gap: 8px;
              margin-top: 12px;
            }
            .chips button {
              color: #f4f7fb;
              background: rgba(32, 36, 45, 0.9);
              border: 1px solid rgba(169, 180, 200, 0.22);
            }
          </style>
        </head>
        <body>
          <main>
            <div class="mark">B</div>
            <h1>Web Browser</h1>
            <p>This is a browser website running inside the contained tab. Enter a site or search, then it opens as top-level navigation so audio, video, logins, and sites that block iframes can still work through WebKit.</p>
            <form id="browserForm">
              <input id="address" value="\(defaultURLString)" autocomplete="url" autocapitalize="none" spellcheck="false" aria-label="Website or search">
              <button type="submit">Open</button>
            </form>
            <div class="chips">
              <button type="button" data-url="https://youtube.com/">YouTube</button>
              <button type="button" data-url="https://open.spotify.com/">Spotify</button>
              <button type="button" data-url="https://wikipedia.org/">Wikipedia</button>
              <button type="button" data-url="https://duckduckgo.com/">Search</button>
            </div>
          </main>
          <script>
            const input = document.getElementById("address");
            const form = document.getElementById("browserForm");

            function destination(raw) {
              const value = raw.trim();
              if (!value) return "\(defaultURLString)";
              if (/^(https?|file):\\/\\//i.test(value)) return value;
              if (/^(localhost|127\\.0\\.0\\.1)(:|\\/|$)/i.test(value)) return "http://" + value;
              if (value.includes(".") || value.includes(":")) return "https://" + value;
              return "https://duckduckgo.com/?q=" + encodeURIComponent(value);
            }

            form.addEventListener("submit", event => {
              event.preventDefault();
              window.location.assign(destination(input.value));
            });

            document.querySelectorAll("[data-url]").forEach(button => {
              button.addEventListener("click", () => {
                input.value = button.dataset.url;
                window.location.assign(button.dataset.url);
              });
            });

            input.focus();
            input.select();
          </script>
        </body>
        </html>
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

    static func isStartPageURL(_ url: URL?) -> Bool {
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

    nonisolated private static func downloadDestination(for suggestedFilename: String) throws -> URL {
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
        if navigationAction.shouldPerformDownload {
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
            let item = BrowserDownloadItem(
                filename: destination.lastPathComponent,
                sourceURLString: response.url?.absoluteString ?? "",
                localPath: destination.path,
                state: .inProgress
            )

            Task { @MainActor [weak self] in
                self?.registerDownload(item, for: identifier)
            }
            completionHandler(destination)
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
