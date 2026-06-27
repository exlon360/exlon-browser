#!/usr/bin/env bash
set -euo pipefail

PROJECT="ZenFireBrowser.xcodeproj"
SCHEME="ZenFireBrowser"
CONFIGURATION="Release"
BUILD_ROOT="build/unsigned-ipa"
APP_PATH="${BUILD_ROOT}/Build/Products/${CONFIGURATION}-iphoneos/ZenFireBrowser.app"
PAYLOAD_DIR="${BUILD_ROOT}/Payload"
IPA_PATH="${BUILD_ROOT}/ZenFireBrowser-unsigned.ipa"

rm -rf "${BUILD_ROOT}"
mkdir -p "${BUILD_ROOT}"

BUILD_LOG="${BUILD_ROOT}/xcodebuild.log"
set +e
xcodebuild \
  -project "${PROJECT}" \
  -scheme "${SCHEME}" \
  -configuration "${CONFIGURATION}" \
  -sdk iphoneos \
  -derivedDataPath "${BUILD_ROOT}/DerivedData" \
  SYMROOT="${BUILD_ROOT}/Build/Products" \
  CODE_SIGNING_ALLOWED=NO \
  build 2>&1 | tee "${BUILD_LOG}"
build_status=${PIPESTATUS[0]}
set -e

if [[ ${build_status} -ne 0 ]]; then
  echo "xcodebuild failed with status ${build_status}. Error summary:" >&2
  grep -E "error:|fatal error:|warning:.*failed|BUILD FAILED|\\([0-9]+ failures?\\)" "${BUILD_LOG}" | tail -n 120 >&2 || true
  exit "${build_status}"
fi

if [[ ! -d "${APP_PATH}" ]]; then
  echo "Expected app bundle was not created: ${APP_PATH}" >&2
  exit 1
fi

mkdir -p "${PAYLOAD_DIR}"
cp -R "${APP_PATH}" "${PAYLOAD_DIR}/"

(
  cd "${BUILD_ROOT}"
  /usr/bin/zip -qry "ZenFireBrowser-unsigned.ipa" "Payload"
)

echo "${IPA_PATH}"
