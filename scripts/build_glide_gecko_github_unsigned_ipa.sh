#!/usr/bin/env bash
set -euo pipefail

if [[ -z "${GECKO_ENGINE_ROOT:-}" || ! -d "${GECKO_ENGINE_ROOT}" ]]; then
  cat >&2 <<'EOF'
GECKO_ENGINE_ROOT must point to a real iOS Gecko/BrowserEngineKit engine bundle before
building the GitHub Gecko sideload IPA.

This script intentionally refuses to package a fake Gecko build over WKWebView.
Expected next inputs:
  - Gecko engine binaries built for iOS
  - BrowserEngineKit networking/rendering/web-content extension targets
  - matching browser-engine entitlements/provisioning profile
EOF
  exit 2
fi

export BUILD_ROOT="${BUILD_ROOT:-build/glide-gecko-github-unsigned-ipa}"
export BUNDLE_IDENTIFIER="${BUNDLE_IDENTIFIER:-com.exlon.ZenFireBrowser.gecko}"
export IPA_NAME="${IPA_NAME:-Glide-Gecko-GitHub-unsigned.ipa}"
if [[ -z "${OTHER_SWIFT_FLAGS:-}" ]]; then
  export OTHER_SWIFT_FLAGS='$(inherited) -D GLIDE_GECKO_EDITION'
fi

bash "$(dirname "$0")/build_unsigned_ipa.sh"
