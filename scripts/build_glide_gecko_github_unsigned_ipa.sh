#!/usr/bin/env bash
set -euo pipefail

if [[ -z "${GECKO_ENGINE_ROOT:-}" || ! -d "${GECKO_ENGINE_ROOT}" ]]; then
  echo "GECKO_ENGINE_ROOT is not set; packaging the verified Reynard Gecko release instead." >&2
  exec bash "$(dirname "$0")/build_glide_gecko_reynard_unsigned_ipa.sh"
fi

export BUILD_ROOT="${BUILD_ROOT:-build/glide-gecko-github-unsigned-ipa}"
export BUNDLE_IDENTIFIER="${BUNDLE_IDENTIFIER:-com.exlon.ZenFireBrowser.gecko}"
export IPA_NAME="${IPA_NAME:-Glide-Gecko-GitHub-unsigned.ipa}"
if [[ -z "${OTHER_SWIFT_FLAGS:-}" ]]; then
  export OTHER_SWIFT_FLAGS='$(inherited) -D GLIDE_GECKO_EDITION'
fi

bash "$(dirname "$0")/build_unsigned_ipa.sh"
