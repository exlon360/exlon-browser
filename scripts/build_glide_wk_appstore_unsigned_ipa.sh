#!/usr/bin/env bash
set -euo pipefail

export BUILD_ROOT="${BUILD_ROOT:-build/glide-wk-appstore-unsigned-ipa}"
export BUNDLE_IDENTIFIER="${BUNDLE_IDENTIFIER:-com.exlon.ZenFireBrowser}"
export IPA_NAME="${IPA_NAME:-Glide-WKWebView-AppStore-unsigned.ipa}"

bash "$(dirname "$0")/build_unsigned_ipa.sh"
