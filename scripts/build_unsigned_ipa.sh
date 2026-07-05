#!/usr/bin/env bash
set -euo pipefail

PROJECT="ZenFireBrowser.xcodeproj"
SCHEME="ZenFireBrowser"
CONFIGURATION="Release"
BUILD_ROOT="${BUILD_ROOT:-build/unsigned-ipa}"
BUNDLE_IDENTIFIER="${BUNDLE_IDENTIFIER:-com.exlon.ZenFireBrowser}"
IPA_NAME="${IPA_NAME:-ZenFireBrowser-unsigned.ipa}"
OTHER_SWIFT_FLAGS="${OTHER_SWIFT_FLAGS:-}"
APP_PATH="${BUILD_ROOT}/Build/Products/${CONFIGURATION}-iphoneos/ZenFireBrowser.app"
PAYLOAD_DIR="${BUILD_ROOT}/Payload"
IPA_PATH="${BUILD_ROOT}/${IPA_NAME}"
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"

rm -rf "${BUILD_ROOT}"
mkdir -p "${BUILD_ROOT}"

BUILD_LOG="${BUILD_ROOT}/xcodebuild.log"
extra_build_settings=(
  "PRODUCT_BUNDLE_IDENTIFIER=${BUNDLE_IDENTIFIER}"
  "CODE_SIGNING_REQUIRED=NO"
)
if [[ -n "${OTHER_SWIFT_FLAGS}" ]]; then
  extra_build_settings+=("OTHER_SWIFT_FLAGS=${OTHER_SWIFT_FLAGS}")
fi

set +e
xcodebuild \
  -project "${PROJECT}" \
  -scheme "${SCHEME}" \
  -configuration "${CONFIGURATION}" \
  -sdk iphoneos \
  -derivedDataPath "${BUILD_ROOT}/DerivedData" \
  SYMROOT="${BUILD_ROOT}/Build/Products" \
  CODE_SIGNING_ALLOWED=NO \
  "${extra_build_settings[@]}" \
  build 2>&1 | tee "${BUILD_LOG}"
build_status=${PIPESTATUS[0]}
set -e

if [[ ${build_status} -ne 0 ]]; then
  echo "xcodebuild failed with status ${build_status}. Error summary:" >&2
  grep -E "error:|fatal error:|warning:.*failed|BUILD FAILED|\\([0-9]+ failures?\\)" "${BUILD_LOG}" | tail -n 120 >&2 || true
  exit "${build_status}"
fi

if [[ ! -d "${APP_PATH}" ]]; then
  APP_PATH="$(find "${BUILD_ROOT}/Build/Products" -type d -name "ZenFireBrowser.app" -print -quit)"
fi

if [[ -z "${APP_PATH}" || ! -d "${APP_PATH}" ]]; then
  echo "Expected app bundle was not created." >&2
  find "${BUILD_ROOT}/Build/Products" -maxdepth 3 -type d -name "*.app" -print >&2 || true
  exit 1
fi

mkdir -p "${PAYLOAD_DIR}"
cp -R "${APP_PATH}" "${PAYLOAD_DIR}/"

(
  cd "${BUILD_ROOT}"
  /usr/bin/zip -qry "${IPA_NAME}" "Payload"
)

echo "${IPA_PATH}"
