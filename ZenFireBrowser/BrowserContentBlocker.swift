import Foundation
import WebKit

enum BrowserContentBlocker {
    private static let identifier = "ZenFireBrowser.AdBlocker"

    private static let rules = """
    [
      {
        "trigger": {
          "url-filter": ".*(doubleclick\\\\.net|googlesyndication\\\\.com|googleadservices\\\\.com|adservice\\\\.google\\\\.|googletagmanager\\\\.com|google-analytics\\\\.com|analytics\\\\.google\\\\.com|adnxs\\\\.com|adsystem\\\\.com|taboola\\\\.com|outbrain\\\\.com|scorecardresearch\\\\.com|quantserve\\\\.com|facebook\\\\.com/tr|connect\\\\.facebook\\\\.net/signals).*"
        },
        "action": {
          "type": "block"
        }
      },
      {
        "trigger": {
          "url-filter": ".*"
        },
        "action": {
          "type": "css-display-none",
          "selector": "[class*=' ad-'], [class^='ad-'], [id*=' ad-'], [id^='ad-'], [class*='advert'], [id*='advert'], iframe[src*='ads'], iframe[id*='ad']"
        }
      }
    ]
    """

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
