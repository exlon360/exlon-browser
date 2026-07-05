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
REYNARD_ASSET_CATALOG="${REYNARD_ASSET_CATALOG:-../reynard-browser/browser/Reynard/Resources/Assets.xcassets}"
SKIN_REYNARD_ASSETS="${SKIN_REYNARD_ASSETS:-1}"
PYTHON_BIN="${PYTHON_BIN:-python3}"
TROLLSTORE_SIGN="${TROLLSTORE_SIGN:-0}"
STRIP_SIGNATURES="${STRIP_SIGNATURES:-1}"
LDID_BIN="${LDID_BIN:-ldid}"

WORK_DIR="${BUILD_ROOT}/work"
PAYLOAD_DIR="${WORK_DIR}/Payload"
OUTPUT_IPA="${BUILD_ROOT}/${IPA_NAME}"
SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"

ensure_python_with_pillow() {
  if "${PYTHON_BIN}" - <<'PY' >/dev/null 2>&1
from PIL import Image
PY
  then
    return
  fi

  local bundled_python="/Users/orion/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/bin/python3"
  if [[ -x "${bundled_python}" ]]; then
    PYTHON_BIN="${bundled_python}"
  fi
}

python_has_pillow() {
  "${PYTHON_BIN}" - <<'PY' >/dev/null 2>&1
from PIL import Image
PY
}

skin_app_assets() {
  local app_path="$1"

  if [[ ! -f "${GLIDE_ICON_SOURCE}" ]]; then
    return
  fi

  ensure_python_with_pillow
  if ! python_has_pillow; then
    echo "Pillow is unavailable; keeping the source app icon." >&2
    return
  fi

  "${PYTHON_BIN}" "${SCRIPT_DIR}/render_glide_gecko_icon.py" \
    --source "${GLIDE_ICON_SOURCE}" \
    --output-dir "${app_path}" \
    --preview "${BUILD_ROOT}/Glide-Gecko-AppIcon-1024.png"

  if [[ "${SKIN_REYNARD_ASSETS}" != "1" || ! -d "${REYNARD_ASSET_CATALOG}" ]]; then
    plutil -remove CFBundleIcons.CFBundlePrimaryIcon.CFBundleIconName "${app_path}/Info.plist" 2>/dev/null || true
    plutil -remove "CFBundleIcons~ipad.CFBundlePrimaryIcon.CFBundleIconName" "${app_path}/Info.plist" 2>/dev/null || true
    return
  fi

  local developer_dir="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
  local actool="${developer_dir}/usr/bin/actool"
  if [[ ! -x "${actool}" ]]; then
    actool="$(xcrun --find actool 2>/dev/null || true)"
  fi
  if [[ -z "${actool}" || ! -x "${actool}" ]]; then
    echo "actool is unavailable; applying loose Glide app icons only." >&2
    return
  fi

  local asset_work="${BUILD_ROOT}/glide-assets"
  local compiled_assets="${asset_work}/compiled"
  local partial_plist="${asset_work}/partial-info.plist"
  rm -rf "${asset_work}"
  mkdir -p "${asset_work}" "${compiled_assets}"
  cp -R "${REYNARD_ASSET_CATALOG}" "${asset_work}/Assets.xcassets"

  "${PYTHON_BIN}" "${SCRIPT_DIR}/render_glide_gecko_icon.py" \
    --source "${GLIDE_ICON_SOURCE}" \
    --output-dir "${asset_work}/loose-icons" \
    --preview "${asset_work}/Assets.xcassets/AppIcon.appiconset/icon.png"
  cp "${asset_work}/Assets.xcassets/AppIcon.appiconset/icon.png" "${asset_work}/Assets.xcassets/AppIcon.appiconset/icon-dark.png"
  cp "${asset_work}/Assets.xcassets/AppIcon.appiconset/icon.png" "${asset_work}/Assets.xcassets/AppIcon.appiconset/icon-tint.png"

  "${actool}" \
    --compile "${compiled_assets}" \
    --platform iphoneos \
    --minimum-deployment-target 13.0 \
    --app-icon AppIcon \
    --accent-color AccentColor \
    --output-partial-info-plist "${partial_plist}" \
    --output-format human-readable-text \
    "${asset_work}/Assets.xcassets" >/dev/null

  cp "${compiled_assets}/Assets.car" "${app_path}/Assets.car"
  cp "${compiled_assets}/AppIcon60x60@2x.png" "${app_path}/AppIcon60x60@2x.png"
  cp "${compiled_assets}/AppIcon76x76@2x~ipad.png" "${app_path}/AppIcon76x76@2x~ipad.png"

  plutil -replace CFBundleIcons -xml "$(plutil -extract CFBundleIcons xml1 -o - "${partial_plist}")" "${app_path}/Info.plist"
  plutil -replace "CFBundleIcons~ipad" -xml "$(plutil -extract "CFBundleIcons~ipad" xml1 -o - "${partial_plist}")" "${app_path}/Info.plist"
}

save_entitlements() {
  local binary="$1"
  local output="$2"

  if [[ -f "${binary}" ]] && command -v "${LDID_BIN}" >/dev/null 2>&1; then
    "${LDID_BIN}" -e "${binary}" > "${output}" 2>/dev/null || true
    if ! grep -q "<plist" "${output}" 2>/dev/null; then
      rm -f "${output}"
    fi
  fi
}

sign_macho() {
  local binary="$1"
  local entitlements="${2:-}"

  if [[ -n "${entitlements}" && -f "${entitlements}" ]]; then
    "${LDID_BIN}" -S"${entitlements}" "${binary}"
  else
    "${LDID_BIN}" -S "${binary}"
  fi
}

sign_trollstore_payload() {
  local app_path="$1"

  if ! command -v "${LDID_BIN}" >/dev/null 2>&1; then
    echo "TROLLSTORE_SIGN=1 requires ldid." >&2
    exit 1
  fi

  local app_executable
  app_executable="$(plutil -extract CFBundleExecutable raw "${app_path}/Info.plist")"
  local app_binary="${app_path}/${app_executable}"
  local app_entitlements="${WORK_DIR}/app.entitlements.plist"
  local helper_binary="${app_path}/PlugIns/Reynard Helper.appex/Reynard Helper"
  local helper_entitlements="${WORK_DIR}/helper.entitlements.plist"
  local openin_binary="${app_path}/PlugIns/OpenIn.appex/OpenIn"
  local openin_entitlements="${WORK_DIR}/openin.entitlements.plist"
  local ptrace_binary="${app_path}/ptrace_jit"
  local ptrace_entitlements="${WORK_DIR}/ptrace.entitlements.plist"

  save_entitlements "${app_binary}" "${app_entitlements}"
  save_entitlements "${helper_binary}" "${helper_entitlements}"
  save_entitlements "${openin_binary}" "${openin_entitlements}"
  save_entitlements "${ptrace_binary}" "${ptrace_entitlements}"

  find "${app_path}" -type d -name "_CodeSignature" -prune -exec rm -rf {} +
  find "${app_path}" -name "embedded.mobileprovision" -delete

  while IFS= read -r file; do
    if file "${file}" | grep -q "Mach-O"; then
      sign_macho "${file}"
    fi
  done < <(find "${app_path}" -type f)

  sign_macho "${app_binary}" "${app_entitlements}"
  [[ -f "${helper_binary}" ]] && sign_macho "${helper_binary}" "${helper_entitlements}"
  [[ -f "${openin_binary}" ]] && sign_macho "${openin_binary}" "${openin_entitlements}"
  [[ -f "${ptrace_binary}" ]] && sign_macho "${ptrace_binary}" "${ptrace_entitlements}"
}

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

skin_app_assets "${APP_PATH}"

if [[ "${TROLLSTORE_SIGN}" == "1" ]]; then
  sign_trollstore_payload "${APP_PATH}"
elif [[ "${STRIP_SIGNATURES}" == "1" ]]; then
  # This output is intentionally unsigned so a sideloading tool can apply the
  # user's own identity and extension-safe signing choices.
  find "${APP_PATH}" -type d -name "_CodeSignature" -prune -exec rm -rf {} +
  find "${APP_PATH}" -name "embedded.mobileprovision" -delete
fi

(
  cd "${WORK_DIR}"
  /usr/bin/zip -qry "../${IPA_NAME}" "Payload"
)

echo "${OUTPUT_IPA}"
