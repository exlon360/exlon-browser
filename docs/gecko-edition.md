# Glide Gecko Edition

Glide has two intended iOS lanes:

- **App Store / WKWebView:** the default `ZenFireBrowser` build. This is the safe App Store lane and uses Apple's `WKWebView`.
- **GitHub / Gecko sideload:** the cool build lane. This must use a real Gecko engine through Apple's `BrowserEngineKit` path before it is released.

The GitHub Gecko lane is intentionally guarded. `scripts/build_glide_gecko_github_unsigned_ipa.sh` exits unless `GECKO_ENGINE_ROOT` points to a real iOS Gecko engine bundle. This prevents shipping a fake Gecko build that is actually WKWebView underneath.

## Required Gecko Inputs

Before the Gecko IPA can be released, the repo needs:

- iOS Gecko engine binaries built for device architectures.
- BrowserEngineKit networking, rendering, and web-content extension targets.
- Browser-engine entitlements and a matching provisioning profile.
- Integration between `BrowserTab` navigation state and the Gecko engine view/process lifecycle.
- WebExtension background/service-worker support wired to the Gecko extension runtime.

## Current State

The WKWebView lane builds and runs today. It already includes first-pass Firefox WebExtension content-script import for `.xpi` and `.zip` packages.

The Gecko lane now has build metadata and a guarded GitHub sideload script, but it is not releasable until the real Gecko engine bundle and BrowserEngineKit extension targets are added.
