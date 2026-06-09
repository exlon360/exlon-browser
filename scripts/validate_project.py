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
        "ZenFireBrowser/BrowserContentBlocker.swift",
        "ZenFireBrowser/BrowserModels.swift",
        "ZenFireBrowser/BrowserTab.swift",
        "ZenFireBrowser/BrowserTheme.swift",
        "ZenFireBrowser/BrowserViewModel.swift",
        "ZenFireBrowser/BrowserWebView.swift",
        "ZenFireBrowser/ContentView.swift",
        "ZenFireBrowser/CustomVPNController.swift",
        "ZenFireBrowser/Info.plist",
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
        "defaults.object(forKey: Self.StorageKey.adBlockerEnabled) as? Bool ?? true",
        "The ad blocker must be enabled by default for fresh installs.",
    )
    require_contains(
        "ZenFireBrowser/BrowserViewModel.swift",
        "setAdBlockerEnabled(true)",
        "Reset to default must turn the ad blocker back on.",
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
        "Choose background",
        "Settings must expose a user background picker.",
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
