#!/usr/bin/env bash
set -euo pipefail

REYNARD_VERSION="${REYNARD_VERSION:-0.6.0}"

export REYNARD_RELEASE_URL="${REYNARD_RELEASE_URL:-https://github.com/minh-ton/reynard-browser/releases/download/${REYNARD_VERSION}/Reynard-TrollStore.tipa}"
export REYNARD_SHA256="${REYNARD_SHA256:-9666f5085f8ef25b4a4a15cb7ff4773f64de776361caca195d9b4df8a80ad207}"
export BUILD_ROOT="${BUILD_ROOT:-build/glide-gecko-reynard-trollstore-tipa}"
export DOWNLOAD_DIR="${DOWNLOAD_DIR:-build/gecko-downloads}"
export SOURCE_IPA="${SOURCE_IPA:-${DOWNLOAD_DIR}/Reynard-TrollStore-${REYNARD_VERSION}.tipa}"
export IPA_NAME="${IPA_NAME:-Glide-Gecko-Reynard-TrollStore.tipa}"
export DISPLAY_NAME="${DISPLAY_NAME:-Glide Gecko}"
export REBRAND_BUNDLE_IDS="${REBRAND_BUNDLE_IDS:-0}"
export TROLLSTORE_SIGN="${TROLLSTORE_SIGN:-1}"
export STRIP_SIGNATURES="${STRIP_SIGNATURES:-0}"

bash "$(dirname "$0")/build_glide_gecko_reynard_unsigned_ipa.sh"
