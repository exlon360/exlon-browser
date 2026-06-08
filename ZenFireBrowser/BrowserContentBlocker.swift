import Foundation
import WebKit

enum BrowserContentBlocker {
    private static let identifier = "ZenFireBrowser.AdBlocker"

    private static let blockedDomains = [
        "doubleclick.net",
        "googlesyndication.com",
        "googleadservices.com",
        "adservice.google.com",
        "pagead2.googlesyndication.com",
        "googletagmanager.com",
        "google-analytics.com",
        "analytics.google.com",
        "ssl.google-analytics.com",
        "adnxs.com",
        "adsrvr.org",
        "rubiconproject.com",
        "openx.net",
        "pubmatic.com",
        "criteo.com",
        "criteo.net",
        "taboola.com",
        "outbrain.com",
        "scorecardresearch.com",
        "quantserve.com",
        "moatads.com",
        "moat.com",
        "zedo.com",
        "yieldmo.com",
        "sharethrough.com",
        "indexww.com",
        "sovrn.com",
        "contextweb.com",
        "casalemedia.com",
        "mathtag.com",
        "media.net",
        "adform.net",
        "adroll.com",
        "adsafeprotected.com",
        "advertising.com",
        "servedby-buysellads.com",
        "buysellads.com",
        "carbonads.com",
        "revcontent.com",
        "mgid.com",
        "smartadserver.com",
        "lijit.com",
        "spotxchange.com",
        "spotx.tv",
        "freewheel.tv",
        "innovid.com",
        "bidswitch.net",
        "bidr.io",
        "yieldlab.net",
        "yieldlove.com",
        "adscale.de",
        "adition.com",
        "adzerk.net",
        "kevel.co",
        "amazon-adsystem.com",
        "aaxads.com",
        "ads.yahoo.com",
        "gemini.yahoo.com",
        "adserver.yahoo.com",
        "ads.linkedin.com",
        "analytics.linkedin.com",
        "ads-twitter.com",
        "analytics.twitter.com",
        "analytics.tiktok.com",
        "business-api.tiktok.com",
        "bat.bing.com",
        "bingads.microsoft.com",
        "clarity.ms",
        "adsymptotic.com",
        "branch.io",
        "appsflyer.com",
        "adjust.com",
        "kochava.com",
        "flurry.com",
        "mixpanel.com",
        "amplitude.com",
        "segment.io",
        "segment.com",
        "hotjar.com",
        "fullstory.com",
        "logrocket.com",
        "newrelic.com",
        "nr-data.net",
        "datadoghq-browser-agent.com",
        "optimizely.com",
        "crazyegg.com",
        "mouseflow.com",
        "inspectlet.com",
        "chartbeat.com",
        "parsely.com",
        "permutive.com",
        "bluekai.com",
        "demdex.net",
        "dpm.demdex.net",
        "everesttech.net",
        "rlcdn.com",
        "krxd.net",
        "adskeeper.co.uk",
        "adblade.com",
        "adbutler.com",
        "adcolony.com",
        "admixer.net",
        "adnami.io",
        "adpushup.com",
        "adreactor.com",
        "adskeeper.com",
        "adspirit.de",
        "adtelligent.com",
        "adtng.com",
        "adtrue.com",
        "adyoulike.com",
        "affec.tv",
        "afy11.net",
        "bebi.com",
        "beachfront.com",
        "betweendigital.com",
        "brightcom.com",
        "bttrack.com",
        "chitika.net",
        "connatix.com",
        "districtm.io",
        "emxdgt.com",
        "e-planning.net",
        "exelator.com",
        "eyeota.net",
        "flashtalking.com",
        "gumgum.com",
        "imrworldwide.com",
        "inmobi.com",
        "inner-active.mobi",
        "lkqd.net",
        "mookie1.com",
        "nexac.com",
        "onetag-sys.com",
        "openweb.com",
        "owneriq.net",
        "polarbyte.com",
        "postrelease.com",
        "prebid.org",
        "pubmine.com",
        "rhythmone.com",
        "rfihub.com",
        "semasio.net",
        "simpli.fi",
        "smartclip.net",
        "sonobi.com",
        "tapad.com",
        "tapjoy.com",
        "teads.tv",
        "technoratimedia.com",
        "the-ozone-project.com",
        "tradedoubler.com",
        "tribalfusion.com",
        "triplelift.com",
        "turn.com",
        "undertone.com",
        "vidoomy.com",
        "videologygroup.com",
        "vungle.com",
        "weborama.fr",
        "widespace.com",
        "yieldoptimizer.com",
        "zemanta.com",
        "connect.facebook.net"
    ]

    private static let cosmeticSelectors = [
        "[class*=' ad-']",
        "[class^='ad-']",
        "[class$='-ad']",
        "[class*=' ads-']",
        "[class*='advert']",
        "[class*='sponsor']",
        "[class*='promoted']",
        "[class*='native-ad']",
        "[class*='banner-ad']",
        "[id*=' ad-']",
        "[id^='ad-']",
        "[id*='advert']",
        "[id*='sponsor']",
        "[id*='promoted']",
        "iframe[src*='ads']",
        "iframe[src*='doubleclick']",
        "iframe[id*='ad']"
    ].joined(separator: ", ")

    private static var rules: String {
        let domainPattern = blockedDomains
            .map { NSRegularExpression.escapedPattern(for: $0) }
            .joined(separator: "|")

        let nativeRules: [[String: Any]] = [
            [
                "trigger": [
                    "url-filter": ".*(\(domainPattern)).*"
                ],
                "action": [
                    "type": "block"
                ]
            ],
            [
                "trigger": [
                    "url-filter": ".*"
                ],
                "action": [
                    "type": "css-display-none",
                    "selector": cosmeticSelectors
                ]
            ]
        ]

        guard let data = try? JSONSerialization.data(withJSONObject: nativeRules, options: []),
              let encodedRules = String(data: data, encoding: .utf8) else {
            return "[]"
        }

        return encodedRules
    }

    static func setEnabled(
        _ enabled: Bool,
        on userContentController: WKUserContentController,
        completion: ((Error?) -> Void)? = nil
    ) {
        userContentController.removeAllContentRuleLists()

        guard enabled else {
            completion?(nil)
            return
        }

        WKContentRuleListStore.default().compileContentRuleList(
            forIdentifier: identifier,
            encodedContentRuleList: rules
        ) { ruleList, error in
            DispatchQueue.main.async {
                if let ruleList = ruleList {
                    userContentController.add(ruleList)
                }
                completion?(error)
            }
        }
    }
}
