import Combine
import Foundation
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

    var onNavigationFinished: (@MainActor (BrowserTab) -> Void)?

    private var observations: [NSKeyValueObservation] = []

    init(startURL: URL = BrowserDefaults.homeURL, isPrivate: Bool = false, isDarkReaderEnabled: Bool = false) {
        self.isPrivate = isPrivate
        self.isDarkReaderEnabled = isDarkReaderEnabled
        self.title = isPrivate ? "Private Start" : "Start"
        self.url = startURL
        self.addressText = startURL.absoluteString

        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        configuration.websiteDataStore = isPrivate ? .nonPersistent() : .default()
        configuration.applicationNameForUserAgent = "ZenFireBrowser/1.0"

        self.webView = WKWebView(frame: .zero, configuration: configuration)
        super.init()

        webView.navigationDelegate = self
        webView.allowsBackForwardNavigationGestures = true
        webView.scrollView.keyboardDismissMode = .interactive
        bindWebViewState()
        load(startURL)
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

    private static func destinationURL(
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
}

extension BrowserTab: WKNavigationDelegate {
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
