import Foundation

#if canImport(BrowserEngineKit) && os(iOS) && !targetEnvironment(macCatalyst)
import BrowserEngineKit
#endif

enum BrowserEngineEdition: String, Codable {
    case appStoreWebKit
    case githubGecko

    var title: String {
        switch self {
        case .appStoreWebKit:
            return "App Store WKWebView"
        case .githubGecko:
            return "GitHub Gecko"
        }
    }
}

enum BrowserEngineBuild {
    #if GLIDE_GECKO_EDITION
    static let edition: BrowserEngineEdition = .githubGecko
    #else
    static let edition: BrowserEngineEdition = .appStoreWebKit
    #endif

    static let geckoNetworkingBundleIdentifier = "com.exlon.ZenFireBrowser.gecko.networking"
    static let geckoRenderingBundleIdentifier = "com.exlon.ZenFireBrowser.gecko.rendering"
    static let geckoWebContentBundleIdentifier = "com.exlon.ZenFireBrowser.gecko.webcontent"

    static var isGeckoEdition: Bool {
        edition == .githubGecko
    }

    static var canUseBrowserEngineKit: Bool {
        #if canImport(BrowserEngineKit) && os(iOS) && !targetEnvironment(macCatalyst)
        if #available(iOS 17.4, *) {
            return true
        }
        #endif
        return false
    }

    static var engineSummary: String {
        switch edition {
        case .appStoreWebKit:
            return "This build uses Apple's WKWebView engine."
        case .githubGecko:
            return "This build is reserved for the Gecko sideload engine lane."
        }
    }

    static var geckoReadinessMessage: String {
        guard isGeckoEdition else {
            return "WKWebView App Store build is active."
        }

        guard canUseBrowserEngineKit else {
            return "Gecko builds require iOS BrowserEngineKit support."
        }

        return "BrowserEngineKit is available. Gecko engine extensions must be bundled before release."
    }
}
