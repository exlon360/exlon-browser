import SwiftUI
import UIKit
import WebKit

struct BrowserWebView: UIViewRepresentable {
    @ObservedObject var tab: BrowserTab
    var isPullDownNavigationEnabled = false
    var onPullDownNavigationChanged: ((CGFloat, CGFloat) -> Void)?
    var onPullDownNavigationEnded: ((CGFloat, CGFloat, Bool) -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> WKWebView {
        configure(tab.webView)
        context.coordinator.install(on: tab.webView)
        return tab.webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        context.coordinator.parent = self
        configure(uiView)
        context.coordinator.install(on: uiView)
        context.coordinator.cancelPullIfDisabled()
    }

    static func dismantleUIView(_ uiView: WKWebView, coordinator: Coordinator) {
        coordinator.uninstall()
    }

    private func configure(_ webView: WKWebView) {
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        webView.scrollView.contentInset = .zero
        webView.scrollView.scrollIndicatorInsets = .zero
        if #available(iOS 11.0, *) {
            webView.scrollView.contentInsetAdjustmentBehavior = .never
        }
    }

    final class Coordinator: NSObject {
        var parent: BrowserWebView

        private weak var installedScrollView: UIScrollView?
        private var isEligible = false
        private var isTrackingPull = false
        private var lastPullDistance: CGFloat = 0
        private var lastHorizontalPosition: CGFloat = 0.5

        private let directionDominance: CGFloat = 0.78
        private let activationDistance: CGFloat = 4
        private let maximumPullDistance: CGFloat = 142

        init(parent: BrowserWebView) {
            self.parent = parent
        }

        func install(on webView: WKWebView) {
            let scrollView = webView.scrollView
            guard installedScrollView !== scrollView else { return }
            uninstall()
            scrollView.panGestureRecognizer.addTarget(self, action: #selector(handleWebpagePan(_:)))
            installedScrollView = scrollView
        }

        func uninstall() {
            finishPull(cancelled: true, notify: false)
            installedScrollView?.panGestureRecognizer.removeTarget(
                self,
                action: #selector(handleWebpagePan(_:))
            )
            installedScrollView = nil
        }

        func cancelPullIfDisabled() {
            guard parent.isPullDownNavigationEnabled == false,
                  isTrackingPull || isEligible else { return }
            finishPull(cancelled: true, notify: false)
        }

        @objc private func handleWebpagePan(_ recognizer: UIPanGestureRecognizer) {
            guard let scrollView = installedScrollView else { return }

            switch recognizer.state {
            case .began:
                let topBoundary = -scrollView.adjustedContentInset.top
                isEligible = parent.isPullDownNavigationEnabled
                    && scrollView.contentOffset.y <= topBoundary + 1.5
                isTrackingPull = false
                lastPullDistance = 0
                lastHorizontalPosition = normalizedHorizontalPosition(of: recognizer, in: scrollView)

            case .changed:
                guard isEligible else { return }
                let translation = recognizer.translation(in: scrollView.window ?? scrollView)

                if isTrackingPull == false {
                    guard translation.y >= activationDistance,
                          translation.y >= abs(translation.x) * directionDominance else { return }
                    isTrackingPull = true
                }

                let topBoundary = -scrollView.adjustedContentInset.top
                lastPullDistance = min(
                    maximumPullDistance,
                    max(0, topBoundary - scrollView.contentOffset.y)
                )
                lastHorizontalPosition = normalizedHorizontalPosition(of: recognizer, in: scrollView)
                parent.onPullDownNavigationChanged?(lastPullDistance, lastHorizontalPosition)

            case .ended:
                finishPull(cancelled: false, notify: isTrackingPull)

            case .cancelled, .failed:
                finishPull(cancelled: true, notify: isTrackingPull)

            default:
                break
            }
        }

        private func normalizedHorizontalPosition(
            of recognizer: UIPanGestureRecognizer,
            in scrollView: UIScrollView
        ) -> CGFloat {
            guard scrollView.bounds.width > 0 else { return 0.5 }
            return min(max(recognizer.location(in: scrollView).x / scrollView.bounds.width, 0), 1)
        }

        private func finishPull(cancelled: Bool, notify: Bool = true) {
            guard isTrackingPull || isEligible else { return }

            let distance = lastPullDistance
            let horizontalPosition = lastHorizontalPosition
            let wasTrackingPull = isTrackingPull

            isEligible = false
            isTrackingPull = false
            lastPullDistance = 0
            lastHorizontalPosition = 0.5

            if notify {
                parent.onPullDownNavigationEnded?(
                    distance,
                    horizontalPosition,
                    cancelled || wasTrackingPull == false
                )
            }
        }
    }
}
