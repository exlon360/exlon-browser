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
        "connect.facebook.net",
        "facebook.net",
        "ads.facebook.com",
        "an.facebook.com",
        "graph.facebook.com",
        "ads.instagram.com",
        "analytics.pinterest.com",
        "ct.pinterest.com",
        "ads.pinterest.com",
        "sc-static.net",
        "tr.snapchat.com",
        "analytics.snapchat.com",
        "ads.snapchat.com",
        "ads-api.twitter.com",
        "ads.tiktok.com",
        "analytics-sg.tiktok.com",
        "ads.youtube.com",
        "imasdk.googleapis.com",
        "pubads.g.doubleclick.net",
        "securepubads.g.doubleclick.net",
        "tpc.googlesyndication.com",
        "ad.doubleclick.net",
        "static.doubleclick.net",
        "partner.googleadservices.com",
        "www.googleadservices.com",
        "adservice.google.ca",
        "adservice.google.co.uk",
        "adservice.google.com.au",
        "adsensecustomsearchads.com",
        "adtrafficquality.google",
        "googletagservices.com",
        "fundingchoicesmessages.google.com",
        "googleoptimize.com",
        "stats.g.doubleclick.net",
        "2mdn.net",
        "adclick.g.doubleclick.net",
        "admob.com",
        "app-measurement.com",
        "firebase-settings.crashlytics.com",
        "firebaseinstallations.googleapis.com",
        "marketingplatform.google.com",
        "ads.pubmatic.com",
        "hbopenbid.pubmatic.com",
        "image2.pubmatic.com",
        "ow.pubmatic.com",
        "eus.rubiconproject.com",
        "fastlane.rubiconproject.com",
        "pixel.rubiconproject.com",
        "prebid-server.rubiconproject.com",
        "prebid.media.net",
        "prebid.adnxs.com",
        "ib.adnxs.com",
        "secure.adnxs.com",
        "acdn.adnxs.com",
        "prebid.a-mo.net",
        "ads.stickyadstv.com",
        "sync-tm.everesttech.net",
        "cm.g.doubleclick.net",
        "match.adsrvr.org",
        "insight.adsrvr.org",
        "js.adsrvr.org",
        "pix.adsafeprotected.com",
        "pixel.adsafeprotected.com",
        "static.adsafeprotected.com",
        "pixel.quantserve.com",
        "secure.quantserve.com",
        "rules.quantcount.com",
        "sb.scorecardresearch.com",
        "b.scorecardresearch.com",
        "udm.scorecardresearch.com",
        "cdn.taboola.com",
        "trc.taboola.com",
        "vidstat.taboola.com",
        "amplify.outbrain.com",
        "widgets.outbrain.com",
        "log.outbrain.com",
        "odb.outbrain.com",
        "paid.outbrain.com",
        "traffic.outbrain.com",
        "images.outbrainimg.com",
        "ads.revcontent.com",
        "trends.revcontent.com",
        "cdn.revcontent.com",
        "servicer.mgid.com",
        "jsc.mgid.com",
        "api.mgid.com",
        "widgets.mgid.com",
        "ads.mgid.com",
        "cdn.carbonads.com",
        "srv.carbonads.net",
        "adserver.barrapunto.com",
        "srv.buysellads.com",
        "stats.wp.com",
        "pixel.wp.com",
        "mc.yandex.ru",
        "an.yandex.ru",
        "ads.yandex.ru",
        "yandexadexchange.net",
        "adfox.ru",
        "adsbetnet.com",
        "ad-delivery.net",
        "adkernel.com",
        "adkernel.net",
        "admantx.com",
        "admedo.com",
        "adnuntius.com",
        "adotmob.com",
        "adpone.com",
        "adriver.ru",
        "adswizz.com",
        "adtago.s3.amazonaws.com",
        "adtelligent.com",
        "adverline.com",
        "adversal.com",
        "advertserve.com",
        "advinci.co",
        "adxpansion.com",
        "adxpose.com",
        "adxxx.com",
        "affiliatly.com",
        "bannerflow.com",
        "bannernow.com",
        "bannersnack.com",
        "bidtheatre.com",
        "brand-display.com",
        "brandmetrics.com",
        "cdn.adligature.com",
        "cdn.krxd.net",
        "chango.com",
        "clickagy.com",
        "clickdimensions.com",
        "clicktale.net",
        "contentsquare.net",
        "crwdcntrl.net",
        "cxense.com",
        "dable.io",
        "deployads.com",
        "districtm.ca",
        "durationmedia.net",
        "ezoic.net",
        "ezojs.com",
        "goadservices.com",
        "gumgum.com",
        "h-bid.com",
        "headbidder.net",
        "id5-sync.com",
        "lijit.com",
        "liveintent.com",
        "loopme.me",
        "monetizemore.com",
        "nativeads.com",
        "nativo.com",
        "nextmillmedia.com",
        "omnitagjs.com",
        "onaudience.com",
        "onesignal.com",
        "optad360.io",
        "orbsrv.com",
        "playwire.com",
        "primis.tech",
        "proper.io",
        "revjet.com",
        "sekindo.com",
        "shareaholic.com",
        "smaato.net",
        "sni-dat.com",
        "streamrail.com",
        "taboola-syndication.com",
        "trafficjunky.net",
        "unrulymedia.com",
        "viralize.tv",
        "w55c.net",
        "webads.eu",
        "yldbt.com",
        "zergnet.com"
    ]

    private static let cosmeticSelectors = [
        "[class*=' ad-']",
        "[class*=' Ad-']",
        "[class*=' ad_']",
        "[class^='ad-']",
        "[class^='ads-']",
        "[class$='-ad']",
        "[class$='_ad']",
        "[class*=' ads-']",
        "[class*=' ads_']",
        "[class*='adslot']",
        "[class*='ad-slot']",
        "[class*='ad_unit']",
        "[class*='ad-unit']",
        "[class*='adcontainer']",
        "[class*='ad-container']",
        "[class*='ad_wrapper']",
        "[class*='ad-wrapper']",
        "[class*='adbanner']",
        "[class*='ad-banner']",
        "[class*='adbox']",
        "[class*='ad-box']",
        "[class*='ad-placement']",
        "[class*='adlabel']",
        "[class*='ad-label']",
        "[class*='adnotice']",
        "[class*='advert']",
        "[class*='commercial']",
        "[class*='sponsor']",
        "[class*='promoted']",
        "[class*='promotion']",
        "[class*='native-ad']",
        "[class*='banner-ad']",
        "[class*='dfp']",
        "[class*='gpt-ad']",
        "[class*='google-ad']",
        "[class*='googleAd']",
        "[class*='taboola']",
        "[class*='outbrain']",
        "[class*='revcontent']",
        "[class*='mgid']",
        "[class*='affiliate']",
        "[class*='paid-content']",
        "[class*='paidContent']",
        "[class*='partner-content']",
        "[class*='recommended-widget']",
        "[class*='recommendation-widget']",
        "[class*='adblock']",
        "[class*='ad-block']",
        "[class*='adb-']",
        "[class*='anti-ad']",
        "[class*='antiad']",
        "[class*='fc-ab-root']",
        "[class*='fc-dialog']",
        "[class*='fc-consent']",
        "[id*=' ad-']",
        "[id*=' ad_']",
        "[id^='ad-']",
        "[id^='ads-']",
        "[id*='adslot']",
        "[id*='ad-slot']",
        "[id*='ad_unit']",
        "[id*='ad-unit']",
        "[id*='adcontainer']",
        "[id*='ad-container']",
        "[id*='ad_wrapper']",
        "[id*='ad-wrapper']",
        "[id*='adbanner']",
        "[id*='ad-banner']",
        "[id*='advert']",
        "[id*='sponsor']",
        "[id*='promoted']",
        "[id*='promotion']",
        "[id*='dfp']",
        "[id*='gpt-ad']",
        "[id*='google-ad']",
        "[id*='taboola']",
        "[id*='outbrain']",
        "[id*='revcontent']",
        "[id*='mgid']",
        "[id*='affiliate']",
        "[id*='paid-content']",
        "[id*='adblock']",
        "[id*='ad-block']",
        "[id*='anti-ad']",
        "[id*='antiad']",
        "[aria-label*='advertisement']",
        "[aria-label*='Advertisement']",
        "[data-ad]",
        "[data-ads]",
        "[data-ad-client]",
        "[data-ad-slot]",
        "[data-ad-unit]",
        "[data-ad-unit-id]",
        "[data-adzone]",
        "[data-ad-zone]",
        "[data-adname]",
        "[data-ad-name]",
        "[data-adtype]",
        "[data-ad-type]",
        "[data-google-query-id]",
        "[data-freestar-ad]",
        "[data-mrf-recirculation]",
        "[data-native-ad]",
        "[data-outbrain]",
        "[data-taboola]",
        "amp-ad",
        "amp-embed[type='taboola']",
        "amp-embed[type='outbrain']",
        "amp-sticky-ad",
        "amp-fx-flying-carpet",
        "iframe[src*='ads']",
        "iframe[src*='doubleclick']",
        "iframe[src*='googlesyndication']",
        "iframe[src*='googleadservices']",
        "iframe[src*='adnxs']",
        "iframe[src*='taboola']",
        "iframe[src*='outbrain']",
        "iframe[src*='mgid']",
        "iframe[id*='ad']",
        "ins.adsbygoogle",
        "div[id^='google_ads']",
        "div[id^='div-gpt-ad']",
        "div[id*='google_ads_iframe']",
        "div[class*='OUTBRAIN']",
        "div[id*='taboola']",
        "div[class*='taboola']"
    ].joined(separator: ", ")

    private static let blockedURLPatterns = [
        ".*(/|%2F)(ad|ads|adv|advert|advertise|advertising|adserver|adservice|admanager|adunit|adslot|adzone|banner|banners|sponsor|sponsored|promoted|promotion|prebid|bidder|bid-request|bid_request|header-bid|headerbid|gampad|pagead|pubads|securepubads|vast|vpaid|ima|ima3|outstream|interstitial|popunder|popup|native-ad|native_ad|affiliate)(/|\\.|-|_|\\?|=|&|%2F).*",
        ".*[?&](ad|ads|adid|ad_id|adunit|ad_unit|adslot|ad_slot|adzone|ad_zone|adserver|ad_server|adtype|ad_type|adsize|ad_size|adpos|ad_pos|iu|sz|cust_params|correlator|output)=.*",
        ".*(doubleclick|googlesyndication|googleadservices|google-analytics|googletagmanager|googletagservices|adnxs|adsrvr|rubicon|pubmatic|openx|criteo|taboola|outbrain|revcontent|mgid|prebid|amazon-adsystem|facebook\\.com/tr|bat\\.bing|clarity\\.ms).*"
    ]

    private static let targetedBlockedURLPatterns = [
        "^https?://([^/]+\\.)?facebook\\.com/tr.*",
        "^https?://([^/]+\\.)?youtube\\.com/(pagead|api/stats/ads).*",
        "^https?://([^/]+\\.)?googlevideo\\.com/videoplayback.*[?&]oad=.*",
        "^https?://www\\.googletagmanager\\.com/gtag/js.*",
        "^https?://analytics\\.google\\.com/g/collect.*",
        "^https?://stats\\.g\\.doubleclick\\.net/.*",
        "^https?://bat\\.bing\\.com/.*",
        "^https?://([^/]+\\.)?clarity\\.ms/.*"
    ]

    private static let broadBlockedResourceTypes = [
        "image",
        "style-sheet",
        "script",
        "font",
        "svg-document"
    ]

    private static let targetedBlockedResourceTypes = [
        "image",
        "style-sheet",
        "script",
        "font",
        "media",
        "svg-document",
        "raw"
    ]

    private static let compatibilityDomains = [
        "browser.local",
        "duckduckgo.com",
        "lite.duckduckgo.com",
        "html.duckduckgo.com",
        "youtube.com",
        "youtu.be",
        "googlevideo.com",
        "ytimg.com",
        "spotify.com",
        "music.apple.com",
        "soundcloud.com",
        "bandcamp.com",
        "netflix.com",
        "hulu.com",
        "disneyplus.com",
        "primevideo.com",
        "max.com",
        "hbomax.com",
        "peacocktv.com",
        "paramountplus.com",
        "tv.apple.com",
        "appletv.apple.com",
        "crunchyroll.com",
        "twitch.tv",
        "kick.com",
        "rumble.com",
        "vimeo.com",
        "dailymotion.com",
        "tiktok.com",
        "x.com",
        "twitter.com",
        "instagram.com",
        "facebook.com",
        "reddit.com",
        "gmail.com",
        "accounts.google.com",
        "google.com",
        "github.com",
        "gitlab.com",
        "stackoverflow.com",
        "stackexchange.com",
        "notion.so",
        "figma.com",
        "discord.com",
        "chatgpt.com",
        "claude.ai",
        "gemini.google.com",
        "grok.com",
        "perplexity.ai",
        "login.microsoftonline.com",
        "appleid.apple.com",
        "amazon.com",
        "ebay.com",
        "walmart.com",
        "target.com",
        "bestbuy.com",
        "linkedin.com",
        "pinterest.com",
        "medium.com",
        "nytimes.com",
        "cnn.com",
        "bbc.com",
        "microsoft.com",
        "office.com",
        "live.com",
        "icloud.com",
        "dropbox.com"
    ]

    private static let compatibilityRuleDomains = compatibilityDomains.map { "*\($0)" }

    private static let antiAdBlockScript = """
    (() => {
      if (window.__glideAggressiveAdBlockerInstalled) { return; }
      window.__glideAggressiveAdBlockerInstalled = true;

      const compatibilityHosts = \(Self.javascriptArrayLiteral(from: compatibilityDomains));
      const currentHost = location.hostname.replace(/^www\\./, "").toLowerCase();
      if (compatibilityHosts.some((domain) => currentHost === domain || currentHost.endsWith("." + domain))) {
        return;
      }

      const textPattern = /(ad\\s*block|adblock|ad-block|disable\\s+(your\\s+)?ad|turn\\s+off\\s+(your\\s+)?ad|whitelist\\s+(us|this)|allow\\s+ads|support\\s+us\\s+by\\s+allowing\\s+ads|we\\s+noticed\\s+.*ad|detected\\s+.*ad|disable\\s+.*blocker|blocker\\s+detected)/i;
      const selectorList = \(Self.javascriptArrayLiteral(from: cosmeticSelectors.components(separatedBy: ", ")));
      const extraSelectors = [
        "[class*='modal'][class*='ad']",
        "[class*='overlay'][class*='ad']",
        "[class*='paywall'][class*='ad']",
        "[role='dialog'][class*='ad']",
        "[role='dialog'][id*='ad']",
        "[class*='fc-ab-root']",
        "[class*='fc-dialog']",
        "[id*='adblock']",
        "[class*='adblock']",
        "[id*='ad-block']",
        "[class*='ad-block']",
        "[id*='antiad']",
        "[class*='antiad']",
        "[id*='anti-ad']",
        "[class*='anti-ad']"
      ];

      const style = document.createElement("style");
      style.id = "glide-aggressive-ad-blocker";
      style.textContent = `${selectorList.concat(extraSelectors).join(", ")} {
        display: none !important;
        visibility: hidden !important;
        opacity: 0 !important;
        pointer-events: none !important;
      }`;

      const appendStyle = () => {
        if (!document.getElementById(style.id)) {
          (document.documentElement || document.head || document.body)?.appendChild(style);
        }
      };

      const makeDetectorStub = () => ({
        onDetected() { return this; },
        onNotDetected(callback) { try { callback && callback(); } catch (_) {} return this; },
        on() { return this; },
        check() { return false; },
        clearEvent() { return this; },
        emitEvent() { return this; },
        setOption() { return this; }
      });

      try {
        const detector = makeDetectorStub();
        ["blockAdBlock", "BlockAdBlock", "fuckAdBlock", "FuckAdBlock"].forEach((name) => {
          Object.defineProperty(window, name, {
            configurable: true,
            get() { return detector; },
            set() {}
          });
        });
        window.canRunAds = true;
        window.isAdBlockActive = false;
        window.adBlockDetected = false;
      } catch (_) {}

      try {
        const nativeAlert = window.alert.bind(window);
        window.alert = (message) => {
          if (textPattern.test(String(message || ""))) { return; }
          nativeAlert(message);
        };
      } catch (_) {}

      const isVisible = (element) => {
        const rect = element.getBoundingClientRect?.();
        return !rect || rect.width > 0 || rect.height > 0;
      };

      const isNagContainer = (element) => {
        if (!element || element === document.documentElement || element === document.body) { return false; }
        const text = (element.innerText || element.textContent || "").slice(0, 1200);
        if (!textPattern.test(text)) { return false; }
        const style = window.getComputedStyle(element);
        const classAndId = `${element.id || ""} ${element.className || ""}`.toLowerCase();
        const rect = element.getBoundingClientRect?.();
        const coversPage = rect && rect.width > window.innerWidth * 0.35 && rect.height > window.innerHeight * 0.18;
        return isVisible(element) && (
          style.position === "fixed" ||
          style.position === "sticky" ||
          Number(style.zIndex || 0) >= 50 ||
          element.getAttribute("role") === "dialog" ||
          classAndId.includes("modal") ||
          classAndId.includes("overlay") ||
          classAndId.includes("popup") ||
          classAndId.includes("adblock") ||
          classAndId.includes("anti-ad") ||
          coversPage
        );
      };

      const removeElement = (element) => {
        if (!element || element === document.documentElement || element === document.body) { return; }
        element.remove();
        return true;
      };

      const unlockPage = () => {
        try {
          [document.documentElement, document.body].forEach((element) => {
            if (!element) { return; }
            element.style.overflow = "auto";
            element.style.pointerEvents = "auto";
          });
        } catch (_) {}
      };

      const clean = () => {
        appendStyle();
        let removedNag = false;

        try {
          extraSelectors.forEach((selector) => {
            try {
              document.querySelectorAll(selector).forEach((element) => {
                if (isNagContainer(element) && removeElement(element)) {
                  removedNag = true;
                }
              });
            } catch (_) {}
          });
        } catch (_) {}

        try {
          document.querySelectorAll("[role='dialog'], [aria-modal='true'], .modal, .overlay, .popup, [class*='adblock'], [id*='adblock'], [class*='anti-ad'], [id*='anti-ad']").forEach((element) => {
            if (isNagContainer(element) && removeElement(element)) {
              removedNag = true;
            }
          });
        } catch (_) {}

        if (removedNag) {
          unlockPage();
        }
      };

      let cleanTimer = undefined;
      const scheduleClean = () => {
        clearTimeout(cleanTimer);
        cleanTimer = setTimeout(clean, 120);
      };

      clean();
      window.addEventListener("DOMContentLoaded", scheduleClean, { once: false });
      window.addEventListener("load", scheduleClean, { once: false });
      setInterval(scheduleClean, 3000);

      try {
        new MutationObserver(scheduleClean).observe(document.documentElement, {
          childList: true,
          subtree: true,
          attributes: true,
          attributeFilter: ["class", "id", "style", "aria-modal", "role"]
        });
      } catch (_) {}
    })();
    """

    private static var rules: String {
        let domainPattern = blockedDomains
            .map { NSRegularExpression.escapedPattern(for: $0) }
            .joined(separator: "|")

        var nativeRules: [[String: Any]] = [
            [
                "trigger": [
                    "url-filter": ".*(\(domainPattern)).*",
                    "resource-type": targetedBlockedResourceTypes,
                    "load-type": ["third-party"],
                    "unless-domain": compatibilityRuleDomains
                ],
                "action": [
                    "type": "block"
                ]
            ],
            [
                "trigger": [
                    "url-filter": ".*",
                    "unless-domain": compatibilityRuleDomains
                ],
                "action": [
                    "type": "css-display-none",
                    "selector": cosmeticSelectors
                ]
            ]
        ]

        nativeRules.append(contentsOf: targetedBlockedURLPatterns.map { pattern in
            [
                "trigger": [
                    "url-filter": pattern,
                    "resource-type": targetedBlockedResourceTypes,
                    "unless-domain": compatibilityRuleDomains
                ],
                "action": [
                    "type": "block"
                ]
            ]
        })

        nativeRules.append(contentsOf: blockedURLPatterns.map { pattern in
            [
                "trigger": [
                    "url-filter": pattern,
                    "resource-type": broadBlockedResourceTypes,
                    "load-type": ["third-party"],
                    "unless-domain": compatibilityRuleDomains
                ],
                "action": [
                    "type": "block"
                ]
            ]
        })

        guard let data = try? JSONSerialization.data(withJSONObject: nativeRules, options: []),
              let encodedRules = String(data: data, encoding: .utf8) else {
            return "[]"
        }

        return encodedRules
    }

    static func setEnabled(
        _ enabled: Bool,
        on userContentController: WKUserContentController,
        additionalUserScripts: [WKUserScript] = [],
        completion: ((Error?) -> Void)? = nil
    ) {
        userContentController.removeAllContentRuleLists()
        userContentController.removeAllUserScripts()
        for script in additionalUserScripts {
            userContentController.addUserScript(script)
        }

        guard enabled else {
            completion?(nil)
            return
        }

        let blockerScript = WKUserScript(
            source: antiAdBlockScript,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: false
        )

        WKContentRuleListStore.default().compileContentRuleList(
            forIdentifier: identifier,
            encodedContentRuleList: rules
        ) { ruleList, error in
            DispatchQueue.main.async {
                if let ruleList = ruleList {
                    userContentController.add(ruleList)
                    userContentController.addUserScript(blockerScript)
                }
                completion?(error)
            }
        }
    }

    private static func javascriptArrayLiteral(from values: [String]) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: values, options: []),
              let encoded = String(data: data, encoding: .utf8) else {
            return "[]"
        }
        return encoded
    }
}
