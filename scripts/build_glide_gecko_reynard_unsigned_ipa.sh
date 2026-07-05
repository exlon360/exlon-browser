#!/usr/bin/env bash
set -euo pipefail

REYNARD_VERSION="${REYNARD_VERSION:-0.6.0}"
REYNARD_RELEASE_URL="${REYNARD_RELEASE_URL:-https://github.com/minh-ton/reynard-browser/releases/download/${REYNARD_VERSION}/Reynard.ipa}"
REYNARD_SHA256="${REYNARD_SHA256:-d3b84c86f8b7e72270be0e079fe14e4b481ef8590695c0791a347d69f5b12a35}"

BUILD_ROOT="${BUILD_ROOT:-build/glide-gecko-reynard-unsigned-ipa}"
DOWNLOAD_DIR="${DOWNLOAD_DIR:-build/gecko-downloads}"
SOURCE_IPA="${SOURCE_IPA:-${DOWNLOAD_DIR}/Reynard-${REYNARD_VERSION}.ipa}"
IPA_NAME="${IPA_NAME:-Glide-Gecko-Reynard-unsigned.ipa}"
DISPLAY_NAME="${DISPLAY_NAME:-Glide Gecko}"
BUNDLE_IDENTIFIER="${BUNDLE_IDENTIFIER:-com.exlon.ZenFireBrowser.gecko}"
REBRAND_BUNDLE_IDS="${REBRAND_BUNDLE_IDS:-0}"
GLIDE_ICON_SOURCE="${GLIDE_ICON_SOURCE:-ZenFireBrowser/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png}"
PYTHON_BIN="${PYTHON_BIN:-python3}"

WORK_DIR="${BUILD_ROOT}/work"
PAYLOAD_DIR="${WORK_DIR}/Payload"
OUTPUT_IPA="${BUILD_ROOT}/${IPA_NAME}"

mkdir -p "${DOWNLOAD_DIR}" "${BUILD_ROOT}"

if [[ ! -f "${SOURCE_IPA}" ]]; then
  echo "Downloading Reynard Gecko ${REYNARD_VERSION}..."
  curl -L --fail "${REYNARD_RELEASE_URL}" -o "${SOURCE_IPA}"
fi

actual_sha="$(shasum -a 256 "${SOURCE_IPA}" | awk '{print $1}')"
if [[ "${actual_sha}" != "${REYNARD_SHA256}" ]]; then
  echo "Reynard IPA checksum mismatch." >&2
  echo "Expected: ${REYNARD_SHA256}" >&2
  echo "Actual:   ${actual_sha}" >&2
  exit 1
fi

rm -rf "${WORK_DIR}" "${OUTPUT_IPA}"
mkdir -p "${WORK_DIR}"
unzip -q "${SOURCE_IPA}" -d "${WORK_DIR}"

APP_PATH="$(find "${PAYLOAD_DIR}" -maxdepth 1 -type d -name "*.app" -print -quit)"
if [[ -z "${APP_PATH}" || ! -d "${APP_PATH}" ]]; then
  echo "Expected app bundle was not found in Reynard IPA." >&2
  exit 1
fi

plutil -replace CFBundleDisplayName -string "${DISPLAY_NAME}" "${APP_PATH}/Info.plist"
plutil -replace CFBundleName -string "${DISPLAY_NAME}" "${APP_PATH}/Info.plist"

if [[ "${REBRAND_BUNDLE_IDS}" == "1" ]]; then
  plutil -replace CFBundleIdentifier -string "${BUNDLE_IDENTIFIER}" "${APP_PATH}/Info.plist"
fi

if [[ -d "${APP_PATH}/PlugIns/Reynard Helper.appex" ]]; then
  plutil -replace CFBundleDisplayName -string "${DISPLAY_NAME} Helper" "${APP_PATH}/PlugIns/Reynard Helper.appex/Info.plist"
  plutil -replace CFBundleName -string "${DISPLAY_NAME} Helper" "${APP_PATH}/PlugIns/Reynard Helper.appex/Info.plist"
  if [[ "${REBRAND_BUNDLE_IDS}" == "1" ]]; then
    plutil -replace CFBundleIdentifier -string "${BUNDLE_IDENTIFIER}.Helper" "${APP_PATH}/PlugIns/Reynard Helper.appex/Info.plist"
  fi
fi

if [[ -d "${APP_PATH}/PlugIns/OpenIn.appex" ]]; then
  plutil -replace CFBundleDisplayName -string "Open in ${DISPLAY_NAME}" "${APP_PATH}/PlugIns/OpenIn.appex/Info.plist"
  plutil -replace CFBundleName -string "Open in ${DISPLAY_NAME}" "${APP_PATH}/PlugIns/OpenIn.appex/Info.plist"
  if [[ "${REBRAND_BUNDLE_IDS}" == "1" ]]; then
    plutil -replace CFBundleIdentifier -string "${BUNDLE_IDENTIFIER}.OpenIn" "${APP_PATH}/PlugIns/OpenIn.appex/Info.plist"
  fi
fi

if [[ -f "${GLIDE_ICON_SOURCE}" ]]; then
  if ! "${PYTHON_BIN}" - <<'PY' >/dev/null 2>&1
from PIL import Image
PY
  then
    bundled_python="/Users/orion/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/bin/python3"
    if [[ -x "${bundled_python}" ]]; then
      PYTHON_BIN="${bundled_python}"
    fi
  fi

  if "${PYTHON_BIN}" - <<'PY' >/dev/null 2>&1
from PIL import Image
PY
  then
    "${PYTHON_BIN}" "$(dirname "$0")/render_glide_gecko_icon.py" \
      --source "${GLIDE_ICON_SOURCE}" \
      --output-dir "${APP_PATH}" \
      --preview "${BUILD_ROOT}/Glide-Gecko-AppIcon-1024.png"
    plutil -remove CFBundleIcons.CFBundlePrimaryIcon.CFBundleIconName "${APP_PATH}/Info.plist" 2>/dev/null || true
    plutil -remove "CFBundleIcons~ipad.CFBundlePrimaryIcon.CFBundleIconName" "${APP_PATH}/Info.plist" 2>/dev/null || true
  else
    echo "Pillow is unavailable; keeping the source app icon." >&2
  fi
fi

# This output is intentionally unsigned so a sideloading tool can apply the
# user's own identity and extension-safe signing choices.
find "${APP_PATH}" -type d -name "_CodeSignature" -prune -exec rm -rf {} +
find "${APP_PATH}" -name "embedded.mobileprovision" -delete

(
  cd "${WORK_DIR}"
  /usr/bin/zip -qry "../${IPA_NAME}" "Payload"
)

echo "${OUTPUT_IPA}"
