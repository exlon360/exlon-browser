# Glide

Glide is a SwiftUI iOS browser prototype with a dark, Arc/Zen-inspired interface and a Firefox-inspired privacy posture.

## What is included

- Side tabs by default, with placement switching for left, right, top, bottom, and floating chrome.
- Glide app icon and home-screen display name.
- PIN unlock at launch, with optional Face ID/Touch ID unlock for the same secure vault.
- Glide browser state, history, restored tabs, theme data, local AI settings, VPN profile metadata, downloads metadata, and settings are saved through a PIN-derived AES-256-GCM vault using PBKDF2-HMAC-SHA256.
- First-launch tutorial with a smooth Welcome to Glide flow and quick customization for tab visibility plus glass/liquid chrome.
- Blank transparent start page for new tabs so the app wallpaper/background is the first thing you see; search still opens through the floating address bar and DuckDuckGo by default.
- Search/address entry that navigates to URLs or searches DuckDuckGo.
- Floating search results with quick search actions and local history matches while typing.
- Optional always-on search bar for people who want the address field pinned above the page, with a drag-to-move mode and saved custom position.
- New tab actions can open the floating search immediately, with a setting to turn that auto-open behavior off and the create-tab button placed before the tab list.
- Protected Private Mode from the three-dot menu prompts for the Glide PIN on entry, exits without a second PIN prompt, keeps private tabs alive only inside Private Mode, hides normal tabs/Essentials/history/download controls, keeps the private tab button available, and blacks out private tab titles.
- Tab Finder sheet for searching, selecting, and closing normal, private, and contained tabs from one place.
- Contained Tabs open full screen and run a custom browser-in-browser website inside a nested `WKWebView`, with an inner address bar, quick sites, back/forward/reload controls, an embedded website viewport, direct compatibility mode for heavy/media sites, audio unlock, an open-page fallback for sites that refuse embedding, audio/video playback, and isolated non-persistent web storage.
- More polished glass-style tab chrome with a settings toggle and adjustable transparency up to 100%.
- Tab bar transparency and background controls are available directly from the tab bar, and side/top/bottom chrome overlays the page so transparency shows the page or wallpaper beneath it.
- User-selected image backgrounds with Files and Photos import, enable, remove, plus stronger bottom chrome contrast over bright/noisy wallpapers.
- Saved themes for colors, wallpaper, and tab transparency, with `.glidetheme` export to Files and import back into Glide.
- Essentials: long-press a normal tab to add it to a saved launcher strip/section.
- When enabled, new tabs focus the floating address field and select its current text.
- Search engine chooser with DuckDuckGo, Google, Bing, Brave, Startpage, Kagi, and a custom `{query}` template.
- Add-ons Library access for Firefox Add-ons and Brave's Chrome Web Store extension catalog. iOS WebKit can browse these libraries, but desktop Firefox/Brave extensions cannot be installed into a third-party `WKWebView`.
- Faster warm page loads through a shared WebKit process pool, responsive URL requests, and a larger memory-only URL cache.
- Normal and private tabs use non-persistent `WKWebsiteDataStore` instances so WebKit does not keep an app-controlled persistent disk cache.
- Private tabs do not write browsing history or show local history suggestions in private search.
- Normal tabs are restored after relaunch; private tabs are not persisted.
- History panel for normal browsing, plus a clear-history action.
- Downloads panel backed by WebKit downloads and a manual "Download Current Tab" action; downloaded file bytes are encrypted at rest in Glide's vault storage, with preview/share only after an export warning creates a temporary decrypted copy.
- Local crash log detection for dirty foreground exits, with a crash logs menu that appears after unlock when a crash-like relaunch is detected.
- Web page file-upload fields open a native file picker for sending local files.
- Native WebKit content-rule ad/tracker blocking is enabled by default with 200-plus blocker domains, aggressive ad URL-pattern rules, cosmetic hiding, and anti-adblock nag cleanup.
- Gesture controls: two-finger swipe left hides the tab bar, two-finger swipe right reveals it, and three-finger horizontal swipes go back or forward.
- Collapsible side tabs without a visible side hider handle.
- Custom VPN profile setup using iOS Personal VPN APIs for a user-supplied country/server.
- Left-side page controls with AI shortcuts for ChatGPT, Gemini, Claude, Grok, an importable local AI endpoint, plus a configurable three-dot menu; moving a toolbar action into the menu hides it from the main chrome bar.
- Advanced config editor with JSON code plus Save, Apply, and Discard actions for fast preference editing.
- Custom chrome icons using SF Symbol names or user-imported image files.
- Back navigation is gesture-first; the visible chrome keeps forward, reload/stop, close tab, new tab, and new private tab controls.
- Dark mode enforced in SwiftUI and `Info.plist`.

## Notes

iOS apps cannot ship the desktop Firefox/Gecko engine through ordinary Swift app code. This project uses Apple's `WKWebView`, which is the browser view available to iOS apps, and wraps it in a Firefox/Zen/Arc-style experience.

Apple does not expose a way for third-party browsers to AES-encrypt WebKit's internal cache files directly. Glide handles that by running tabs on non-persistent WebKit storage, disabling shared disk URL caching, clearing old app/WebKit cache locations on launch/unlock, and encrypting Glide's own persisted browser data and downloaded file blobs with the PIN-derived vault key.

The custom VPN screen is native, not a website shortcut. A working tunnel still requires a real VPN server and the Personal VPN entitlement when the IPA is signed.

Open `ZenFireBrowser.xcodeproj` in Xcode on macOS, set your development team, and run the `ZenFireBrowser` scheme on an iPhone or iPad simulator.

## Separate Nebula Rooms App

`NebulaRooms.xcodeproj` is a separate SwiftUI iOS messaging app prototype. It uses username/password accounts only, accepts account and room passwords from 1 to 100 characters, lets users create or join password-protected rooms, send messages, delete messages for themselves, remove their own messages for everyone, and create unlimited custom color themes. The default visual style is a black and purple Nebula Rooms theme with generated app icon and backdrop assets.

Open `NebulaRooms.xcodeproj` in Xcode on macOS, set your development team, and run the `NebulaRooms` scheme on an iPhone or iPad simulator.

Build an unsigned IPA with the `Build Nebula Rooms IPA` workflow. For release assets, push a `nebula-v*` tag, such as:

```bash
git tag nebula-v0.1.0
git push origin nebula-v0.1.0
```

## GitHub Automations

The repo includes GitHub Actions workflows under `.github/workflows`:

- `ios-ci.yml` builds the shared `ZenFireBrowser` Xcode scheme on a macOS runner for pushes, pull requests, and manual dispatches.
- `glide-emu-ios-ci.yml` builds the separate `GlideEmu` Xcode scheme on a macOS runner for pushes, pull requests, and manual dispatches.
- `build-ipa.yml` creates an unsigned `ZenFireBrowser-unsigned.ipa` artifact from a manual workflow run or a `v*` tag, and publishes the IPA to GitHub Releases for tag builds.
- `build-glide-emu-ipa.yml` creates a separate unsigned `GlideEmu-unsigned.ipa` artifact from a manual workflow run or an `emu-v*` tag.
- `build-nebula-rooms-ipa.yml` creates a separate unsigned `NebulaRooms-unsigned.ipa` artifact from a manual workflow run or a `nebula-v*` tag.
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

## Separate Glide Emu App

`GlideEmu.xcodeproj` is a separate SwiftUI iOS app from the Glide browser. It registers `.dmg`, `.apk`, `.exe`, and `.deb` document imports, copies selected packages into app storage, keeps a local package library, and opens a local-engine touch session for the selected package type.

The `.exe` path now has a real local DOSBox-style runtime: imported DOS-compatible EXE files are packed on-device into a `.jsdos` bundle, mounted without installing, and launched in a full-screen WebKit emulator surface with touch and audio. The js-dos v7 runtime assets are bundled with the app. Modern Windows PE apps, APKs, DEBs, and DMGs still need their own emulator cores; iOS cannot execute those package formats natively.

Build it from GitHub Actions with the `Build Glide Emu IPA` workflow. For release assets, push an `emu-v*` tag, such as:

```bash
git tag emu-v0.1.0
git push origin emu-v0.1.0
```

Each non-DOS package type requires a bundled local emulator engine inside the IPA for real execution. iOS does not natively execute imported macOS, Android, Windows, or Linux package files by itself.
