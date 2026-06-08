# ZenFireBrowser

ZenFireBrowser is a SwiftUI iOS browser prototype with a dark, Arc/Zen-inspired interface and a Firefox-inspired privacy posture.

## What is included

- Side tabs by default, with placement switching for left, right, top, bottom, and floating chrome.
- Search/address entry that navigates to URLs or searches DuckDuckGo.
- Search engine chooser with DuckDuckGo, Google, Bing, Brave, Startpage, Kagi, and a custom `{query}` template.
- Normal and private tabs. Private tabs use a non-persistent `WKWebsiteDataStore`.
- Normal tabs are restored after relaunch; private tabs are not persisted.
- History panel for normal browsing, plus a clear-history action.
- Collapsible side tabs with a small edge handle.
- Top-right AI shortcuts for ChatGPT, Gemini, Claude, Grok, and an importable local AI endpoint.
- Back, forward, reload/stop, close tab, new tab, and new private tab controls.
- Dark mode enforced in SwiftUI and `Info.plist`.

## Notes

iOS apps cannot ship the desktop Firefox/Gecko engine through ordinary Swift app code. This project uses Apple's `WKWebView`, which is the browser view available to iOS apps, and wraps it in a Firefox/Zen/Arc-style experience.

Open `ZenFireBrowser.xcodeproj` in Xcode on macOS, set your development team, and run the `ZenFireBrowser` scheme on an iPhone or iPad simulator.

## GitHub Automations

The repo includes GitHub Actions workflows under `.github/workflows`:

- `ios-ci.yml` builds the shared `ZenFireBrowser` Xcode scheme on a macOS runner for pushes, pull requests, and manual dispatches.
- `build-ipa.yml` creates an unsigned `ZenFireBrowser-unsigned.ipa` artifact from a manual workflow run or a `v*` tag, and publishes the IPA to GitHub Releases for tag builds.
- `build-signed-ipa.yml` creates a signed IPA when Apple signing secrets are configured.
- `repository-checks.yml` validates the plist, shared scheme XML, required project files, private browsing storage, and dark mode enforcement.

Run the same repository-level checks locally with:

```bash
python scripts/validate_project.py
```

## IPA Builds

Run the `Build IPA` GitHub Action manually to produce `ZenFireBrowser-unsigned.ipa` as a workflow artifact.

Unsigned IPAs are not installable on a real iPhone by themselves, but they are the right artifact to import into sideload signing tools such as KSign.

### KSign Sideload Flow

1. Push this repo to GitHub.
2. Push a release tag, such as `v0.1.0`.
3. Open GitHub Releases.
4. Download `ZenFireBrowser-unsigned.ipa` from the release assets.
5. Move that IPA to your iPhone.
6. Open KSign, import the IPA, sign it with your certificate/profile inside KSign, then install it.

KSign cannot compile the Swift project. It only signs/sideloads the IPA after GitHub Actions or Xcode has built it.

For GitHub-signed builds, add these repository secrets:

- `APPLE_TEAM_ID`
- `IOS_CERTIFICATE_BASE64`
- `IOS_CERTIFICATE_PASSWORD`
- `IOS_PROVISIONING_PROFILE_BASE64`

Create the base64 values on macOS with:

```bash
base64 -i Certificates.p12 | pbcopy
base64 -i ZenFireBrowser.mobileprovision | pbcopy
```

Then run the `Build Signed IPA` workflow manually.
