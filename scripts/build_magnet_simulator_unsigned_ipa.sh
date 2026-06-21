#!/usr/bin/env bash
set -euo pipefail

PROJECT="MagnetSimulator.xcodeproj"
SCHEME="MagnetSimulator"
CONFIGURATION="Release"
BUILD_ROOT="build/magnet-simulator-unsigned-ipa"
APP_PATH="${BUILD_ROOT}/Build/Products/${CONFIGURATION}-iphoneos/MagnetSimulator.app"
PAYLOAD_DIR="${BUILD_ROOT}/Payload"
IPA_PATH="${BUILD_ROOT}/MagnetSimulator-unsigned.ipa"

rm -rf "${BUILD_ROOT}"
mkdir -p "${BUILD_ROOT}"

xcodebuild \
  -project "${PROJECT}" \
  -scheme "${SCHEME}" \
  -configuration "${CONFIGURATION}" \
  -sdk iphoneos \
  -derivedDataPath "${BUILD_ROOT}/DerivedData" \
  SYMROOT="${BUILD_ROOT}/Build/Products" \
  CODE_SIGNING_ALLOWED=NO \
  build

if [[ ! -d "${APP_PATH}" ]]; then
  echo "Expected app bundle was not created: ${APP_PATH}" >&2
  exit 1
fi

mkdir -p "${PAYLOAD_DIR}"
cp -R "${APP_PATH}" "${PAYLOAD_DIR}/"

(
  cd "${BUILD_ROOT}"
  /usr/bin/zip -qry "MagnetSimulator-unsigned.ipa" "Payload"
)

echo "${IPA_PATH}"
