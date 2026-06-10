from pathlib import Path
import json
import re
import sys
import xml.etree.ElementTree as ET


ROOT = Path(__file__).resolve().parents[1]


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


def require_file(path: str) -> None:
    if not (ROOT / path).is_file():
        raise SystemExit(f"Missing required file: {path}")


def require_contains(path: str, needle: str, message: str) -> None:
    if needle not in read(path):
        raise SystemExit(message)


def require_absent(path: str, needle: str, message: str) -> None:
    if needle in read(path):
        raise SystemExit(message)


def require_minimum_blocked_domains(minimum: int) -> None:
    source = read("ZenFireBrowser/BrowserContentBlocker.swift")
    marker = "private static let blockedDomains = ["
    start = source.find(marker)
    if start == -1:
        raise SystemExit("The ad blocker must keep a native blockedDomains list.")

    end = source.find("]\n", start)
    if end == -1:
        raise SystemExit("The blockedDomains list could not be parsed.")

    domains = set(re.findall(r'"([A-Za-z0-9.-]+)"', source[start:end]))
    if len(domains) < minimum:
        raise SystemExit(f"The ad blocker must include at least {minimum} ad/tracker domains; found {len(domains)}.")


def parse_xml(path: str) -> None:
    try:
        ET.parse(ROOT / path)
    except ET.ParseError as error:
        raise SystemExit(f"Invalid XML in {path}: {error}") from error


def parse_json(path: str) -> None:
    try:
        json.loads(read(path))
    except json.JSONDecodeError as error:
        raise SystemExit(f"Invalid JSON in {path}: {error}") from error


def require_app_icon_files() -> None:
    icon_dir = ROOT / "ZenFireBrowser/Assets.xcassets/AppIcon.appiconset"
    contents = json.loads((icon_dir / "Contents.json").read_text(encoding="utf-8"))
    filenames = [
        image["filename"]
        for image in contents.get("images", [])
        if "filename" in image
    ]
    if len(filenames) < 18:
        raise SystemExit(f"The app icon set must include the full iPhone/iPad icon set; found {len(filenames)} entries.")

    for filename in filenames:
        if not (icon_dir / filename).is_file():
            raise SystemExit(f"Missing app icon image: {filename}")


def main() -> int:
    required_files = [
        ".github/workflows/ios-ci.yml",
        ".github/workflows/build-ipa.yml",
        ".github/workflows/build-signed-ipa.yml",
        ".github/workflows/repository-checks.yml",
        "README.md",
        "scripts/build_unsigned_ipa.sh",
        "scripts/build_signed_ipa.sh",
        "ZenFireBrowser.xcodeproj/project.pbxproj",
        "ZenFireBrowser.xcodeproj/xcshareddata/xcschemes/ZenFireBrowser.xcscheme",
        "ZenFireBrowser/Assets.xcassets/Contents.json",
        "ZenFireBrowser/Assets.xcassets/AppIcon.appiconset/Contents.json",
        "ZenFireBrowser/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png",
        "ZenFireBrowser/AppCrashReporter.swift",
        "ZenFireBrowser/BrowserContentBlocker.swift",
        "ZenFireBrowser/BrowserModels.swift",
        "ZenFireBrowser/BrowserTab.swift",
        "ZenFireBrowser/BrowserTheme.swift",
        "ZenFireBrowser/BrowserViewModel.swift",
        "ZenFireBrowser/BrowserWebView.swift",
        "ZenFireBrowser/ContentView.swift",
        "ZenFireBrowser/CustomVPNController.swift",
        "ZenFireBrowser/Info.plist",
        "ZenFireBrowser/SecureBrowserVault.swift",
        "ZenFireBrowser/ZenFireBrowserApp.swift",
    ]

    for path in required_files:
        require_file(path)

    parse_xml("ZenFireBrowser/Info.plist")
    parse_xml("ZenFireBrowser.xcodeproj/xcshareddata/xcschemes/ZenFireBrowser.xcscheme")
    parse_json("ZenFireBrowser/Assets.xcassets/Contents.json")
    parse_json("ZenFireBrowser/Assets.xcassets/AppIcon.appiconset/Contents.json")
    require_app_icon_files()

    require_contains(
        "ZenFireBrowser/Info.plist",
        "<key>CFBundleDisplayName</key>\n\t<string>Glide</string>",
        "The installed app display name must be Glide.",
    )
    require_contains(
        "ZenFireBrowser/Info.plist",
        "<key>CFBundleName</key>\n\t<string>Glide</string>",
        "The bundle name must be Glide.",
    )
    require_contains(
        "ZenFireBrowser.xcodeproj/project.pbxproj",
        "ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;",
        "The Xcode target must use the Glide app icon asset catalog.",
    )
    require_contains(
        "ZenFireBrowser.xcodeproj/project.pbxproj",
        "Assets.xcassets in Resources",
        "The asset catalog must be included in the target resources.",
    )
    require_contains(
        "ZenFireBrowser/ContentView.swift",
        'Text("Glide")',
        "The in-app brand must be Glide.",
    )

    require_contains(
        "ZenFireBrowser/BrowserTab.swift",
        ".nonPersistent()",
        "Private browsing must use a non-persistent WKWebsiteDataStore.",
    )
    require_contains(
        "ZenFireBrowser/BrowserContentBlocker.swift",
        "WKContentRuleListStore",
        "The ad blocker must use native WebKit content rules.",
    )
    require_minimum_blocked_domains(100)
    require_contains(
        "ZenFireBrowser/BrowserViewModel.swift",
        "vault.load(Bool.self, forKey: Self.StorageKey.adBlockerEnabled, default: true)",
        "The ad blocker must be enabled by default for fresh installs.",
    )
    require_contains(
        "ZenFireBrowser/ContentView.swift",
        "BrowserTabFinderView",
        "The browser must expose an all-tabs tab finder screen.",
    )
    require_contains(
        "ZenFireBrowser/ContentView.swift",
        "BrowserPageControls",
        "AI and more actions must live in the left-side page control cluster.",
    )
    require_contains(
        "ZenFireBrowser/ContentView.swift",
        "MoreTabButton",
        "The page controls must include a three-dot more menu.",
    )
    require_contains(
        "ZenFireBrowser/ContentView.swift",
        "pageControlsLeadingPadding",
        "Left-side page controls must avoid the default side tab rail.",
    )
    require_contains(
        "ZenFireBrowser/ContentView.swift",
        'Section("Three-Dot Menu")',
        "Settings must expose three-dot menu customization.",
    )
    require_contains(
        "ZenFireBrowser/BrowserViewModel.swift",
        "moreMenuActionIDs",
        "Three-dot menu customization must persist in the encrypted browser model.",
    )
    require_contains(
        "ZenFireBrowser/BrowserViewModel.swift",
        "BrowserToolbarAction",
        "Toolbar actions must be modeled for bar/menu customization.",
    )
    require_contains(
        "ZenFireBrowser/ContentView.swift",
        "model.isInMoreMenu(.history) == false",
        "Moving History to the three-dot menu must hide it from the main bar.",
    )
    require_contains(
        "ZenFireBrowser/BrowserViewModel.swift",
        "isTabFinderPresented",
        "The browser model must present the tab finder.",
    )
    require_contains(
        "ZenFireBrowser/BrowserViewModel.swift",
        "selectFromFinder",
        "The tab finder must select normal and contained tabs.",
    )
    require_contains(
        "ZenFireBrowser/AppCrashReporter.swift",
        "Previous session ended unexpectedly",
        "The app must detect and log crash-like dirty foreground exits.",
    )
    require_contains(
        "ZenFireBrowser/SecureBrowserVault.swift",
        "isCrashLogsPresented",
        "The security model must present crash logs after unlock.",
    )
    require_contains(
        "ZenFireBrowser/ContentView.swift",
        "CrashLogsView",
        "The app must include a crash logs menu.",
    )
    require_contains(
        "ZenFireBrowser/ContentView.swift",
        "presentCrashLogsIfNeeded",
        "Crash logs must be offered automatically after an unread crash-like relaunch.",
    )
    require_contains(
        "ZenFireBrowser/BrowserViewModel.swift",
        "downloadSelectedTab",
        "Downloads must include a manual current-tab download action.",
    )
    require_contains(
        "ZenFireBrowser/BrowserViewModel.swift",
        "URLSession.shared.download",
        "Manual downloads must use native URLSession downloading.",
    )
    require_contains(
        "ZenFireBrowser/SecureBrowserVault.swift",
        "encryptData",
        "Downloaded file bytes must be encryptable through the AES-256 vault.",
    )
    require_contains(
        "ZenFireBrowser/SecureBrowserVault.swift",
        "decryptData",
        "Downloaded file bytes must be decryptable only after unlock.",
    )
    require_contains(
        "ZenFireBrowser/BrowserModels.swift",
        "encryptedLocalPath",
        "Downloads must track their encrypted blob path instead of relying on plaintext files.",
    )
    require_contains(
        "ZenFireBrowser/BrowserViewModel.swift",
        "GlideEncryptedDownloads",
        "Encrypted downloads must be stored outside the plaintext Documents/Downloads folder.",
    )
    require_contains(
        "ZenFireBrowser/BrowserViewModel.swift",
        "prepareDownloadForExport",
        "Downloads must decrypt only through an explicit export preparation path.",
    )
    require_contains(
        "ZenFireBrowser/BrowserTab.swift",
        "temporaryDownloadDestination",
        "WebKit downloads must land in a temporary staging path before encryption.",
    )
    require_contains(
        "ZenFireBrowser/ContentView.swift",
        "Export decrypted file?",
        "Exporting a downloaded file must show a privacy warning first.",
    )
    require_absent(
        "ZenFireBrowser/ContentView.swift",
        "ShareLink(item: item.localURL)",
        "Downloads must not share the stored file URL directly.",
    )
    require_contains(
        "ZenFireBrowser/ContentView.swift",
        "QLPreviewController",
        "Downloaded files must support in-app preview.",
    )
    require_contains(
        "ZenFireBrowser/Info.plist",
        "UIFileSharingEnabled",
        "Downloaded files must be visible through iOS file sharing.",
    )
    require_contains(
        "ZenFireBrowser/Info.plist",
        "LSSupportsOpeningDocumentsInPlace",
        "Downloaded files must support opening in place from Files.",
    )
    require_contains(
        "ZenFireBrowser/ContentView.swift",
        "BrowserLockView",
        "The browser must show a PIN/Face ID lock screen before the browser UI.",
    )
    require_contains(
        "ZenFireBrowser/ContentView.swift",
        "BrowserUnlockedRoot(vault: vault)",
        "The browser model and theme must be created only after the secure vault unlocks.",
    )
    require_contains(
        "ZenFireBrowser/ContentView.swift",
        "security.lock()",
        "Settings must allow locking Glide without quitting the app.",
    )
    require_contains(
        "ZenFireBrowser/Info.plist",
        "NSFaceIDUsageDescription",
        "Face ID unlock must include an iOS usage description.",
    )
    require_contains(
        "ZenFireBrowser/SecureBrowserVault.swift",
        "PBKDF2-HMAC-SHA256",
        "The vault envelope must record PBKDF2-HMAC-SHA256 as the PIN KDF.",
    )
    require_contains(
        "ZenFireBrowser/SecureBrowserVault.swift",
        "CCKeyDerivationPBKDF",
        "The vault must derive its AES key from the PIN with PBKDF2.",
    )
    require_contains(
        "ZenFireBrowser/SecureBrowserVault.swift",
        "kCCPRFHmacAlgSHA256",
        "PBKDF2 must use HMAC-SHA256.",
    )
    require_contains(
        "ZenFireBrowser/SecureBrowserVault.swift",
        "AES.GCM.seal",
        "The vault must encrypt saved browser state with AES-256-GCM.",
    )
    require_contains(
        "ZenFireBrowser/SecureBrowserVault.swift",
        "biometryCurrentSet",
        "Face ID/Touch ID unlock must bind the stored key to the current biometric enrollment.",
    )
    require_contains(
        "ZenFireBrowser/SecureBrowserVault.swift",
        "URLCache(memoryCapacity: 8 * 1024 * 1024, diskCapacity: 0",
        "Shared URL loading must disable unencrypted disk cache.",
    )
    require_contains(
        "ZenFireBrowser/SecureBrowserVault.swift",
        "removeUnencryptedCacheFiles",
        "Launch privacy prep must clear unencrypted app cache files.",
    )
    require_contains(
        "ZenFireBrowser/BrowserTheme.swift",
        "init(vault: SecureBrowserVault)",
        "Theme preferences must load through the encrypted vault.",
    )
    require_contains(
        "ZenFireBrowser/BrowserViewModel.swift",
        "init(vault: SecureBrowserVault)",
        "Browser state must load through the encrypted vault.",
    )
    require_contains(
        "ZenFireBrowser/BrowserViewModel.swift",
        "setAdBlockerEnabled(true)",
        "Reset to default must turn the ad blocker back on.",
    )
    require_contains(
        "ZenFireBrowser/BrowserViewModel.swift",
        "topSearchBarEnabled",
        "The top search bar preference must persist in the encrypted browser model.",
    )
    require_contains(
        "ZenFireBrowser/BrowserViewModel.swift",
        "BrowserTopSearchBarPlacement",
        "The pinned search bar must have movable placement options.",
    )
    require_contains(
        "ZenFireBrowser/ContentView.swift",
        "Picker(\"Search bar position\"",
        "Settings must expose the pinned search bar placement picker.",
    )
    require_contains(
        "ZenFireBrowser/ContentView.swift",
        "BrowserTopSearchBar",
        "The browser shell must render the optional top search bar.",
    )
    require_contains(
        "ZenFireBrowser/BrowserViewModel.swift",
        "BrowserAddOnLibrary",
        "Firefox and Brave add-on libraries must be modeled.",
    )
    require_contains(
        "ZenFireBrowser/BrowserViewModel.swift",
        "addons.mozilla.org/firefox",
        "The add-ons library must include Firefox Add-ons access.",
    )
    require_contains(
        "ZenFireBrowser/BrowserViewModel.swift",
        "chromewebstore.google.com/category/extensions",
        "The add-ons library must include Brave/Chrome Web Store access.",
    )
    require_contains(
        "ZenFireBrowser/ContentView.swift",
        "AddOnsLibraryView",
        "The app must expose an add-ons library screen.",
    )
    require_contains(
        "ZenFireBrowser/ContentView.swift",
        "AdvancedConfigView",
        "Settings must expose the advanced config editor.",
    )
    require_contains(
        "ZenFireBrowser/ContentView.swift",
        "Button(\"Apply\")",
        "The advanced config editor must include an Apply action.",
    )
    require_contains(
        "ZenFireBrowser/ContentView.swift",
        "Button(\"Discard\")",
        "The advanced config editor must include a Discard action.",
    )
    require_contains(
        "ZenFireBrowser/ContentView.swift",
        "Button(\"Save\")",
        "The advanced config editor must include a Save action.",
    )
    require_contains(
        "ZenFireBrowser/BrowserViewModel.swift",
        "BrowserCustomIconSlot",
        "Custom browser icon slots must be modeled.",
    )
    require_contains(
        "ZenFireBrowser/ContentView.swift",
        "CustomIconsView",
        "Settings must expose custom icon controls.",
    )
    require_contains(
        "ZenFireBrowser/ContentView.swift",
        "BrowserIcon",
        "The chrome must render configurable custom icons.",
    )
    require_contains(
        "ZenFireBrowser/BrowserTheme.swift",
        "glidetheme",
        "Themes must export with a Glide theme file extension.",
    )
    require_contains(
        "ZenFireBrowser/BrowserTheme.swift",
        "exportThemeFile",
        "Saved themes must be exportable to Files.",
    )
    require_contains(
        "ZenFireBrowser/BrowserTheme.swift",
        "importTheme",
        "Theme files must be importable back into Glide.",
    )
    require_contains(
        "ZenFireBrowser/ContentView.swift",
        "ThemeFileExportController",
        "The settings UI must present a native Files export picker for themes.",
    )
    require_contains(
        "ZenFireBrowser/ContentView.swift",
        "Import from Files",
        "The settings UI must import theme files from Files.",
    )
    require_contains(
        "ZenFireBrowser/ContentView.swift",
        "FirstRunTutorialView",
        "Fresh installs must show a first-run tutorial.",
    )
    require_contains(
        "ZenFireBrowser/BrowserViewModel.swift",
        "containedTabs",
        "Contained tabs must have separate browser state.",
    )
    require_contains(
        "ZenFireBrowser/ContentView.swift",
        "ContainedBrowserOverlay",
        "Contained tabs must render a nested browser overlay.",
    )
    require_contains(
        "ZenFireBrowser/ContentView.swift",
        ".ignoresSafeArea()",
        "Contained tabs must be able to present full screen.",
    )
    require_contains(
        "ZenFireBrowser/BrowserTab.swift",
        "Contained Web Browser",
        "Contained tabs must load a custom browser-in-browser website.",
    )
    require_contains(
        "ZenFireBrowser/BrowserTab.swift",
        "<iframe",
        "The contained browser website must include an embedded website viewport.",
    )
    require_contains(
        "ZenFireBrowser/BrowserTab.swift",
        "Open Page",
        "The contained browser must include a fallback for sites that refuse embedding.",
    )
    require_contains(
        "ZenFireBrowser/BrowserViewModel.swift",
        "usesPersistentStorage: false",
        "Contained tabs must use isolated non-persistent web storage.",
    )
    require_contains(
        "ZenFireBrowser/BrowserViewModel.swift",
        "BrowserDefaults.containedBrowserStartURL",
        "Contained tabs must open the browser-in-browser start page by default.",
    )
    require_contains(
        "ZenFireBrowser/BrowserTab.swift",
        "containedBrowserHTML",
        "Contained tabs must provide a local browser-in-browser website.",
    )
    require_contains(
        "ZenFireBrowser/BrowserTab.swift",
        "https://browser.local/contained-browser",
        "The contained browser start page must use a neutral browser URL, not Glide branding.",
    )
    require_absent(
        "ZenFireBrowser/BrowserTab.swift",
        "Glide Contained Browser",
        "The contained browser webpage must not be Glide-branded.",
    )
    require_absent(
        "ZenFireBrowser/BrowserTab.swift",
        "browser inside Glide",
        "The contained browser webpage must describe itself as a browser website, not as Glide.",
    )
    require_contains(
        "ZenFireBrowser/BrowserTab.swift",
        "window.location.assign(destination(input.value))",
        "The contained browser website must open entered websites as top-level navigation.",
    )
    require_contains(
        "ZenFireBrowser/BrowserTab.swift",
        "mediaTypesRequiringUserActionForPlayback = []",
        "WebKit tabs must allow website audio and video playback.",
    )
    require_contains(
        "ZenFireBrowser/BrowserTab.swift",
        "allowsAirPlayForMediaPlayback = true",
        "WebKit tabs must allow audio routing/AirPlay playback.",
    )
    require_contains(
        "ZenFireBrowser/BrowserTab.swift",
        "createWebViewWith",
        "WebKit tabs must handle popup and target=_blank navigation.",
    )
    require_contains(
        "ZenFireBrowser/BrowserTab.swift",
        "requestMediaCapturePermissionFor",
        "WebKit tabs must support website camera/microphone permission prompts.",
    )
    require_contains(
        "ZenFireBrowser/Info.plist",
        "NSAllowsArbitraryLoads",
        "The browser must allow broad website loading in WKWebView.",
    )
    require_contains(
        "ZenFireBrowser/Info.plist",
        "NSAllowsLocalNetworking",
        "The browser must allow local-network websites.",
    )
    require_contains(
        "ZenFireBrowser/Info.plist",
        "UIBackgroundModes",
        "The app must declare audio background mode for website audio.",
    )
    require_contains(
        "ZenFireBrowser/Info.plist",
        "NSMicrophoneUsageDescription",
        "The app must include microphone permission text for websites.",
    )
    require_contains(
        "ZenFireBrowser/ContentView.swift",
        "ZStack(alignment: edge == .left ? .leading : .trailing)",
        "Side tab chrome must overlay the web content so transparency is visible.",
    )
    require_contains(
        "ZenFireBrowser/ContentView.swift",
        "ZStack(alignment: .top)",
        "Top chrome must overlay the web content so transparency is visible.",
    )
    require_contains(
        "ZenFireBrowser/ContentView.swift",
        "ZStack(alignment: .bottom)",
        "Bottom chrome must overlay the web content so transparency is visible.",
    )
    require_contains(
        "ZenFireBrowser/BrowserTheme.swift",
        "tabBarTransparency = 0.82",
        "Default tab bar transparency must be clear enough to read as transparent.",
    )
    require_contains(
        "ZenFireBrowser/BrowserTheme.swift",
        "Data(contentsOf: url)",
        "Wallpaper import must read image data reliably from file-provider URLs.",
    )
    require_contains(
        "ZenFireBrowser/BrowserWebView.swift",
        "isOpaque = false",
        "The web view must allow wallpaper/transparent backgrounds around web content.",
    )
    require_absent(
        "ZenFireBrowser/ContentView.swift",
        "SideTabHandle",
        "The visible side-tab hider handle must stay hidden.",
    )
    require_contains(
        "ZenFireBrowser/BrowserViewModel.swift",
        "hasCompletedTutorial",
        "The first-run tutorial must persist its completed state.",
    )
    require_absent(
        "ZenFireBrowser/ContentView.swift",
        'ChromeButton(symbol: "chevron.left", label: "Back")',
        "Visible chrome back buttons must stay hidden; use gestures for back navigation.",
    )
    require_contains(
        "ZenFireBrowser/BrowserTab.swift",
        "runOpenPanelWith",
        "Web page file uploads must use a native file picker bridge.",
    )
    require_contains(
        "ZenFireBrowser/BrowserViewModel.swift",
        "floatingSearchText",
        "Floating search results must be driven by typed search text.",
    )
    require_contains(
        "ZenFireBrowser/ContentView.swift",
        "openNewTabAndSearch",
        "New tab controls must open the floating search bar.",
    )
    require_contains(
        "ZenFireBrowser/BrowserTheme.swift",
        "tabBarTransparency",
        "The tab bar must expose adjustable transparency.",
    )
    require_contains(
        "ZenFireBrowser/BrowserTheme.swift",
        "setUserBackground",
        "The browser theme must support user-selected backgrounds.",
    )
    require_contains(
        "ZenFireBrowser/ContentView.swift",
        "Choose from Files",
        "Settings must expose a file-based user background picker.",
    )
    require_contains(
        "ZenFireBrowser/ContentView.swift",
        "PhotosPicker",
        "Settings must expose a Photos-based user background picker.",
    )
    require_contains(
        "ZenFireBrowser/BrowserTheme.swift",
        "SavedBrowserTheme",
        "The browser must support saved themes.",
    )
    require_contains(
        "ZenFireBrowser/ContentView.swift",
        "Saved Themes",
        "Settings must expose saved theme controls.",
    )
    require_contains(
        "ZenFireBrowser/ContentView.swift",
        "Add to Essentials",
        "Long-press tab menus must expose Add to Essentials.",
    )
    require_contains(
        "ZenFireBrowser/BrowserViewModel.swift",
        "handleTwoFingerSwipe(deltaX",
        "Two-finger gestures must use direction instead of blind toggling.",
    )
    require_contains(
        "ZenFireBrowser/BrowserTab.swift",
        "Start Page",
        "New tabs must use a local blank start page instead of a fixed DuckDuckGo page.",
    )
    require_absent(
        "ZenFireBrowser/BrowserTab.swift",
        "<h1>Glide</h1>",
        "The blank start page must not render Glide branding over the wallpaper.",
    )
    require_contains(
        "ZenFireBrowser/ContentView.swift",
        "max(theme.tabBarOpacity, 0.68)",
        "Floating/bottom chrome must keep a strong opacity floor over custom backgrounds.",
    )
    require_contains(
        "ZenFireBrowser/ContentView.swift",
        "chromeForegroundColor",
        "Chrome controls must use a high-contrast foreground over custom backgrounds.",
    )
    require_contains(
        "ZenFireBrowser/ContentView.swift",
        "TabBarStyleControl",
        "The tab bar must expose local transparency/background controls.",
    )
    require_contains(
        "ZenFireBrowser/ContentView.swift",
        "selectAll",
        "The floating address field must auto-select text for new tab entry.",
    )
    require_contains(
        "ZenFireBrowser/BrowserViewModel.swift",
        "shouldSelectFloatingSearchText",
        "The browser model must track floating search text selection requests.",
    )
    require_contains(
        "ZenFireBrowser/CustomVPNController.swift",
        "NEVPNManager",
        "The custom VPN profile must use native iOS VPN APIs.",
    )
    require_contains(
        "ZenFireBrowser/ZenFireBrowserApp.swift",
        ".preferredColorScheme(.dark)",
        "The SwiftUI app entry point must enforce dark mode.",
    )
    require_contains(
        "ZenFireBrowser/Info.plist",
        "UIUserInterfaceStyle",
        "Info.plist must enforce dark interface style.",
    )
    require_contains(
        ".github/workflows/ios-ci.yml",
        "xcodebuild",
        "The iOS CI workflow must run xcodebuild.",
    )
    require_contains(
        ".github/workflows/build-ipa.yml",
        "ZenFireBrowser-unsigned.ipa",
        "The IPA workflow must upload a ZenFireBrowser IPA artifact.",
    )
    require_contains(
        ".github/workflows/build-ipa.yml",
        "softprops/action-gh-release",
        "The IPA workflow must publish tag builds to GitHub Releases.",
    )
    require_contains(
        ".github/workflows/build-signed-ipa.yml",
        "ZenFireBrowser-signed-ipa",
        "The signed IPA workflow must upload a signed IPA artifact.",
    )
    require_contains(
        "scripts/build_unsigned_ipa.sh",
        "CODE_SIGNING_ALLOWED=NO",
        "The unsigned IPA script must disable code signing.",
    )
    require_contains(
        "scripts/build_signed_ipa.sh",
        "security import",
        "The signed IPA script must import the signing certificate.",
    )

    swift_files = list((ROOT / "ZenFireBrowser").glob("*.swift"))
    for path in swift_files:
        source = path.read_text(encoding="utf-8")
        rel = path.relative_to(ROOT).as_posix()
        if "#Preview" in source:
            raise SystemExit(f"{rel} uses #Preview; use PreviewProvider for broader Xcode compatibility.")
        if "guard let selectedTabID else" in source:
            raise SystemExit(f"{rel} uses newer optional binding shorthand.")
        if "host(percentEncoded:" in source:
            raise SystemExit(f"{rel} uses newer URL host API; use .host for this target.")

    print("project validation ok")
    return 0


if __name__ == "__main__":
    sys.exit(main())
