# ZenFireBrowser

ZenFireBrowser is a SwiftUI iOS browser prototype with a dark, Arc/Zen-inspired interface and a Firefox-inspired privacy posture.

## What is included

- Side tabs by default, with placement switching for left, right, top, bottom, and floating chrome.
- Search/address entry that navigates to URLs or searches DuckDuckGo.
- Normal and private tabs. Private tabs use a non-persistent `WKWebsiteDataStore`.
- Back, forward, reload/stop, close tab, new tab, and new private tab controls.
- Dark mode enforced in SwiftUI and `Info.plist`.

## Notes

iOS apps cannot ship the desktop Firefox/Gecko engine through ordinary Swift app code. This project uses Apple's `WKWebView`, which is the browser view available to iOS apps, and wraps it in a Firefox/Zen/Arc-style experience.

Open `ZenFireBrowser.xcodeproj` in Xcode on macOS, set your development team, and run the `ZenFireBrowser` scheme on an iPhone or iPad simulator.

## GitHub Automations

The repo includes GitHub Actions workflows under `.github/workflows`:

- `ios-ci.yml` builds the shared `ZenFireBrowser` Xcode scheme on a macOS runner for pushes, pull requests, and manual dispatches.
- `build-ipa.yml` creates an unsigned `ZenFireBrowser-unsigned.ipa` artifact from a manual workflow run or a `v*` tag.
- `repository-checks.yml` validates the plist, shared scheme XML, required project files, private browsing storage, and dark mode enforcement.

Run the same repository-level checks locally with:

```bash
python scripts/validate_project.py
```

## IPA Builds

Run the `Build IPA` GitHub Action manually to produce `ZenFireBrowser-unsigned.ipa` as a workflow artifact.

Unsigned IPAs are not installable on a real iPhone. For a device-installable IPA, add Apple Developer signing credentials and replace the unsigned packaging step with an `xcodebuild archive` plus `xcodebuild -exportArchive` flow.
