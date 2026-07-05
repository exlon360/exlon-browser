# Glide Gecko Edition

Glide has two intended iOS lanes:

- **App Store / WKWebView:** the default `ZenFireBrowser` build. This is the safe App Store lane and uses Apple's `WKWebView`.
- **GitHub / Gecko sideload:** the cool build lane. This must use a real Gecko engine before it is released.

The GitHub Gecko lane is intentionally honest. If `GECKO_ENGINE_ROOT` points to a local iOS Gecko engine bundle, `scripts/build_glide_gecko_github_unsigned_ipa.sh` uses that lane. If it is missing, the script packages the verified Reynard Gecko release through `scripts/build_glide_gecko_reynard_unsigned_ipa.sh` instead of shipping a fake Gecko build that is actually WKWebView underneath.

## Required Gecko Inputs

Before the Gecko IPA can be released, the repo needs:

- iOS Gecko engine binaries built for device architectures.
- BrowserEngineKit networking, rendering, and web-content extension targets.
- Browser-engine entitlements and a matching provisioning profile.
- Integration between `BrowserTab` navigation state and the Gecko engine view/process lifecycle.
- WebExtension background/service-worker support wired to the Gecko extension runtime.

## Reynard Gecko Package

The fallback Gecko sideload package uses Reynard Browser `0.6.0`, an experimental Gecko-based iOS browser, and verifies the release IPA checksum before repackaging it as an unsigned `Glide Gecko` sideload artifact.

- Source: `https://github.com/minh-ton/reynard-browser/releases/tag/0.6.0`
- Expected SHA-256: `d3b84c86f8b7e72270be0e079fe14e4b481ef8590695c0791a347d69f5b12a35`
- Output: `build/glide-gecko-reynard-unsigned-ipa/Glide-Gecko-Reynard-unsigned.ipa`

For launch stability, the default package keeps Reynard's original internal app and extension bundle identifiers and only applies the Glide display name and Glide-style icon assets. The helper extension and Gecko process bootstrap are sensitive to sideload signing and extension wiring, so changing those identifiers is opt-in with `REBRAND_BUNDLE_IDS=1`.

When installing the IPA through AltStore, SideStore, or a similar sideloader, keep app extensions enabled. Reynard's Gecko process bootstrap depends on its helper extension and can crash on launch if the helper is removed during installation.

Reynard is licensed under GPLv3, with Gecko patches under MPL 2.0. Keep those license obligations in mind before publishing a modified/repackaged build.

## Current State

The WKWebView lane builds and runs today. It already includes first-pass Firefox WebExtension content-script import for `.xpi` and `.zip` packages.

The Gecko lane now produces a real Gecko sideload IPA by repackaging Reynard's verified Gecko build. Native Exlon tab/session integration still requires porting Reynard's `GeckoView` Swift module, helper extension, Gecko process bootstrap, and add-on runtime into Exlon.
