#!/usr/bin/env bash
set -euo pipefail

PROJECT="ZenFireBrowser.xcodeproj"
SCHEME="ZenFireBrowser"
CONFIGURATION="Release"
BUILD_ROOT="build/mac-dmg"
PRODUCTS_DIR="${BUILD_ROOT}/Build/Products"
APP_NAME="Glide"
SOURCE_APP_PATH="${PRODUCTS_DIR}/${CONFIGURATION}-maccatalyst/ZenFireBrowser.app"
DMG_STAGING="${BUILD_ROOT}/dmg-staging"
DMG_PATH="${BUILD_ROOT}/${APP_NAME}-macOS.dmg"
BUILD_LOG="${BUILD_ROOT}/xcodebuild.log"

rm -rf "${BUILD_ROOT}"
mkdir -p "${BUILD_ROOT}"

set +e
xcodebuild \
  -project "${PROJECT}" \
  -scheme "${SCHEME}" \
  -configuration "${CONFIGURATION}" \
  -sdk macosx \
  -destination "generic/platform=macOS,variant=Mac Catalyst" \
  -derivedDataPath "${BUILD_ROOT}/DerivedData" \
  SYMROOT="${PRODUCTS_DIR}" \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  build 2>&1 | tee "${BUILD_LOG}"
build_status=${PIPESTATUS[0]}
set -e

if [[ ${build_status} -ne 0 ]]; then
  echo "xcodebuild failed with status ${build_status}. Error summary:" >&2
  grep -E "error:|fatal error:|warning:.*failed|BUILD FAILED|\\([0-9]+ failures?\\)" "${BUILD_LOG}" | tail -n 160 >&2 || true
  exit "${build_status}"
fi

if [[ ! -d "${SOURCE_APP_PATH}" ]]; then
  SOURCE_APP_PATH="$(find "${PRODUCTS_DIR}" -type d -name "ZenFireBrowser.app" | head -n 1)"
fi

if [[ -z "${SOURCE_APP_PATH}" || ! -d "${SOURCE_APP_PATH}" ]]; then
  echo "Expected Mac Catalyst app bundle was not created." >&2
  find "${PRODUCTS_DIR}" -maxdepth 3 -type d -name "*.app" -print >&2 || true
  exit 1
fi

mkdir -p "${DMG_STAGING}"
ditto "${SOURCE_APP_PATH}" "${DMG_STAGING}/${APP_NAME}.app"
ln -s /Applications "${DMG_STAGING}/Applications"

BINARY_PATH="${DMG_STAGING}/${APP_NAME}.app/Contents/MacOS/ZenFireBrowser"
if [[ ! -f "${BINARY_PATH}" ]]; then
  echo "Expected executable was not found: ${BINARY_PATH}" >&2
  exit 1
fi

file "${BINARY_PATH}" | tee "${BUILD_ROOT}/mach-o.txt"
if ! file "${BINARY_PATH}" | grep -q "Mach-O"; then
  echo "The built executable is not a Mach-O binary." >&2
  exit 1
fi

hdiutil create \
  -volname "${APP_NAME}" \
  -srcfolder "${DMG_STAGING}" \
  -ov \
  -format UDZO \
  "${DMG_PATH}"

echo "${DMG_PATH}"
