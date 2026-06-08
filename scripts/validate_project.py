from pathlib import Path
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


def parse_xml(path: str) -> None:
    try:
        ET.parse(ROOT / path)
    except ET.ParseError as error:
        raise SystemExit(f"Invalid XML in {path}: {error}") from error


def main() -> int:
    required_files = [
        ".github/workflows/ios-ci.yml",
        ".github/workflows/build-ipa.yml",
        ".github/workflows/repository-checks.yml",
        "README.md",
        "scripts/build_unsigned_ipa.sh",
        "ZenFireBrowser.xcodeproj/project.pbxproj",
        "ZenFireBrowser.xcodeproj/xcshareddata/xcschemes/ZenFireBrowser.xcscheme",
        "ZenFireBrowser/BrowserTab.swift",
        "ZenFireBrowser/BrowserViewModel.swift",
        "ZenFireBrowser/BrowserWebView.swift",
        "ZenFireBrowser/ContentView.swift",
        "ZenFireBrowser/Info.plist",
        "ZenFireBrowser/ZenFireBrowserApp.swift",
    ]

    for path in required_files:
        require_file(path)

    parse_xml("ZenFireBrowser/Info.plist")
    parse_xml("ZenFireBrowser.xcodeproj/xcshareddata/xcschemes/ZenFireBrowser.xcscheme")

    require_contains(
        "ZenFireBrowser/BrowserTab.swift",
        ".nonPersistent()",
        "Private browsing must use a non-persistent WKWebsiteDataStore.",
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
        "scripts/build_unsigned_ipa.sh",
        "CODE_SIGNING_ALLOWED=NO",
        "The unsigned IPA script must disable code signing.",
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
