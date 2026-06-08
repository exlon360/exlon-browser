import Combine
import Foundation
import UIKit
import WebKit

enum BrowserDefaults {
    static let homeURL = URL(string: "https://duckduckgo.com/")!
}

@MainActor
final class BrowserTab: NSObject, Identifiable, ObservableObject {
    let id = UUID()
    let isPrivate: Bool
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
    var onTwoFingerSwipe: (@MainActor () -> Void)?
    var onThreeFingerSwipe: (@MainActor (CGFloat) -> Void)?
    var onFilePickerRequested: (@MainActor (Bool, @escaping ([URL]?) -> Void) -> Void)?

    private var observations: [NSKeyValueObservation] = []
    private var activeDownloads: [ObjectIdentifier: BrowserDownloadItem] = [:]

    init(
        startURL: URL = BrowserDefaults.homeURL,
        isPrivate: Bool = false,
        isDarkReaderEnabled: Bool = false,
        isAdBlockerEnabled: Bool = false
    ) {
        self.isPrivate = isPrivate
        self.isDarkReaderEnabled = isDarkReaderEnabled
        self.isAdBlockerEnabled = isAdBlockerEnabled
        self.title = isPrivate ? "Private Start" : "Start"
        self.url = startURL
        self.addressText = startURL.absoluteString

        let configuration = WKWebViewConfiguration()
        configuration.userContentController = WKUserContentController()
        configuration.allowsInlineMediaPlayback = true
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        configuration.websiteDataStore = isPrivate ? .nonPersistent() : .default()
        configuration.applicationNameForUserAgent = "ZenFireBrowser/1.0"

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
                    self?.load(startURL)
                }
            }
        } else {
            load(startURL)
        }
    }

    static var homeURL: URL {
        BrowserDefaults.homeURL
    }

    func load(_ url: URL) {
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

    private func bindWebViewState() {
        observations = [
            webView.observe(\.title, options: [.initial, .new]) { [weak self] webView, _ in
                Task { @MainActor in
                    let fallback = self?.isPrivate == true ? "Private Tab" : "New Tab"
                    let title = webView.title?.trimmingCharacters(in: .whitespacesAndNewlines)
                    self?.title = title?.isEmpty == false ? title ?? fallback : fallback
                }
            },
            webView.observe(\.url, options: [.initial, .new]) { [weak self] webView, _ in
                Task { @MainActor in
                    self?.url = webView.url
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
        let movedEnough = max(abs(translation.x), abs(translation.y)) > 72
        guard movedEnough else { return }
        onTwoFingerSwipe?()
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
