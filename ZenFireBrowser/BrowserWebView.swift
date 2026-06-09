import SwiftUI
import WebKit

struct BrowserWebView: UIViewRepresentable {
    @ObservedObject var tab: BrowserTab

    func makeUIView(context: Context) -> WKWebView {
        tab.webView.isOpaque = false
        tab.webView.backgroundColor = .clear
        tab.webView.scrollView.backgroundColor = .clear
        tab.webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
    }
}
