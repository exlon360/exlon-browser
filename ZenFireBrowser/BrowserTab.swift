import Combine
import Foundation
import WebKit

enum BrowserDefaults {
    static let homeURL = URL(string: "https://www.mozilla.org/firefox/new/")!
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

    private var observations: [NSKeyValueObservation] = []

    init(startURL: URL = BrowserDefaults.homeURL, isPrivate: Bool = false) {
        self.isPrivate = isPrivate
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

    func submitAddress() {
        let destination = Self.destinationURL(from: addressText)
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

    private static func destinationURL(from rawValue: String) -> URL {
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

        let encodedQuery = trimmed.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? trimmed
        return URL(string: "https://duckduckgo.com/?q=\(encodedQuery)")!
    }
}

extension BrowserTab: WKNavigationDelegate {
    nonisolated func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        Task { @MainActor [weak self] in
            self?.isLoading = false
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
