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
        webView.scrollView.alwaysBounceVertical = true
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
        private var initialContentOffsetY: CGFloat = 0
        private var pullTranslationOriginY: CGFloat = 0

        private let directionDominance: CGFloat = 0.55
        private let activationDistance: CGFloat = 4
        private let topActivationSlop: CGFloat = 10
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
                isEligible = parent.isPullDownNavigationEnabled
                isTrackingPull = false
                lastPullDistance = 0
                lastHorizontalPosition = normalizedHorizontalPosition(of: recognizer, in: scrollView)
                initialContentOffsetY = scrollView.contentOffset.y
                pullTranslationOriginY = 0

            case .changed:
                guard isEligible, parent.isPullDownNavigationEnabled else { return }
                let translation = recognizer.translation(in: scrollView.window ?? scrollView)

                if isTrackingPull == false {
                    let topBoundary = -scrollView.adjustedContentInset.top
                    let beganAtTop = initialContentOffsetY <= topBoundary + topActivationSlop
                    let velocity = recognizer.velocity(in: scrollView.window ?? scrollView)

                    guard scrollView.contentOffset.y <= topBoundary + topActivationSlop,
                          velocity.y > 0,
                          velocity.y >= abs(velocity.x) * directionDominance else { return }

                    if beganAtTop {
                        guard translation.y >= activationDistance,
                              translation.y >= abs(translation.x) * directionDominance else { return }
                        pullTranslationOriginY = 0
                    } else {
                        pullTranslationOriginY = translation.y
                    }
                    isTrackingPull = true
                }

                let distance = min(
                    maximumPullDistance,
                    max(0, translation.y - pullTranslationOriginY)
                )
                let horizontalPosition = normalizedHorizontalPosition(of: recognizer, in: scrollView)
                guard abs(distance - lastPullDistance) >= 0.5
                        || abs(horizontalPosition - lastHorizontalPosition) >= 0.002 else { return }

                lastPullDistance = distance
                lastHorizontalPosition = horizontalPosition
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
            initialContentOffsetY = 0
            pullTranslationOriginY = 0

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
