# PowerShortcuts

PowerShortcuts is a SwiftUI iOS app that exposes Shortcuts actions through App Intents. It gives Shortcuts a safe, PowerShell-style command surface for app-approved Files locations.

## What it can do

- List files in the app Documents folder or a folder the user grants through the Files picker.
- Copy, move, import, export, read, write, and delete files inside approved roots.
- Run a command action with familiar aliases such as `ls`, `cp`, `mv`, `rm`, `Get-ChildItem`, `Copy-Item`, `Move-Item`, `Remove-Item`, `Get-Content`, `Set-Content`, and `Start-Process`.
- Open apps that publish URL schemes, such as `shortcuts://`, or open web URLs.

## iOS limits

iOS does not allow an App Store-style app to run desktop PowerShell, browse the whole device filesystem, delete apps, or launch arbitrary apps by bundle identifier. PowerShortcuts uses the supported route: user-granted Files access, app sandbox storage, and URL schemes.

Deletion is guarded: root paths, parent traversal, and wildcards are blocked, and folder deletion must be explicitly enabled.

## GitHub Actions

PowerShortcuts has two workflows:

- `PowerShortcuts iOS CI` builds the app for the iOS simulator on pushes, pull requests, and manual runs.
- `Build PowerShortcuts IPA` builds and uploads `PowerShortcuts-unsigned.ipa` on matching app changes, manual runs, and release tags.

To publish an unsigned IPA to a GitHub Release:

```bash
git tag power-shortcuts-v0.1.0
git push origin power-shortcuts-v0.1.0
```
