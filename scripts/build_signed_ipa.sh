#!/usr/bin/env bash
set -euo pipefail

PROJECT="ZenFireBrowser.xcodeproj"
SCHEME="ZenFireBrowser"
CONFIGURATION="Release"
BUILD_ROOT="build/signed-ipa"
ARCHIVE_PATH="${BUILD_ROOT}/ZenFireBrowser.xcarchive"
EXPORT_PATH="${BUILD_ROOT}/export"
EXPORT_OPTIONS_PATH="${BUILD_ROOT}/ExportOptions.plist"
KEYCHAIN_PATH="${RUNNER_TEMP:-/tmp}/zenfirebrowser-signing.keychain-db"
KEYCHAIN_PASSWORD="${KEYCHAIN_PASSWORD:-$(uuidgen)}"
PROFILE_PATH="${RUNNER_TEMP:-/tmp}/ZenFireBrowser.mobileprovision"
CERTIFICATE_PATH="${RUNNER_TEMP:-/tmp}/ZenFireBrowser.p12"

: "${APPLE_TEAM_ID:?APPLE_TEAM_ID is required}"
: "${IOS_CERTIFICATE_BASE64:?IOS_CERTIFICATE_BASE64 is required}"
: "${IOS_CERTIFICATE_PASSWORD:?IOS_CERTIFICATE_PASSWORD is required}"
: "${IOS_PROVISIONING_PROFILE_BASE64:?IOS_PROVISIONING_PROFILE_BASE64 is required}"

BUNDLE_IDENTIFIER="${BUNDLE_IDENTIFIER:-com.exlon.ZenFireBrowser}"
EXPORT_METHOD="${EXPORT_METHOD:-development}"

rm -rf "${BUILD_ROOT}"
mkdir -p "${BUILD_ROOT}" "${EXPORT_PATH}"

python3 - <<PY
import base64
import os
from pathlib import Path

Path("${CERTIFICATE_PATH}").write_bytes(base64.b64decode(os.environ["IOS_CERTIFICATE_BASE64"]))
Path("${PROFILE_PATH}").write_bytes(base64.b64decode(os.environ["IOS_PROVISIONING_PROFILE_BASE64"]))
PY

security create-keychain -p "${KEYCHAIN_PASSWORD}" "${KEYCHAIN_PATH}"
security set-keychain-settings -lut 21600 "${KEYCHAIN_PATH}"
security unlock-keychain -p "${KEYCHAIN_PASSWORD}" "${KEYCHAIN_PATH}"
security import "${CERTIFICATE_PATH}" -P "${IOS_CERTIFICATE_PASSWORD}" -A -t cert -f pkcs12 -k "${KEYCHAIN_PATH}"
security list-keychains -d user -s "${KEYCHAIN_PATH}" login.keychain-db
security set-key-partition-list -S apple-tool:,apple: -s -k "${KEYCHAIN_PASSWORD}" "${KEYCHAIN_PATH}"

mkdir -p "${HOME}/Library/MobileDevice/Provisioning Profiles"
PROFILE_PLIST="${BUILD_ROOT}/profile.plist"
security cms -D -i "${PROFILE_PATH}" > "${PROFILE_PLIST}"
PROFILE_UUID=$(/usr/libexec/PlistBuddy -c "Print UUID" "${PROFILE_PLIST}")
PROFILE_NAME=$(/usr/libexec/PlistBuddy -c "Print Name" "${PROFILE_PLIST}")
cp "${PROFILE_PATH}" "${HOME}/Library/MobileDevice/Provisioning Profiles/${PROFILE_UUID}.mobileprovision"

cat > "${EXPORT_OPTIONS_PATH}" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>method</key>
  <string>${EXPORT_METHOD}</string>
  <key>signingStyle</key>
  <string>manual</string>
  <key>teamID</key>
  <string>${APPLE_TEAM_ID}</string>
  <key>provisioningProfiles</key>
  <dict>
    <key>${BUNDLE_IDENTIFIER}</key>
    <string>${PROFILE_NAME}</string>
  </dict>
  <key>compileBitcode</key>
  <false/>
  <key>stripSwiftSymbols</key>
  <true/>
</dict>
</plist>
EOF

xcodebuild \
  -project "${PROJECT}" \
  -scheme "${SCHEME}" \
  -configuration "${CONFIGURATION}" \
  -sdk iphoneos \
  -archivePath "${ARCHIVE_PATH}" \
  DEVELOPMENT_TEAM="${APPLE_TEAM_ID}" \
  PRODUCT_BUNDLE_IDENTIFIER="${BUNDLE_IDENTIFIER}" \
  CODE_SIGN_STYLE=Manual \
  PROVISIONING_PROFILE_SPECIFIER="${PROFILE_NAME}" \
  archive

xcodebuild \
  -exportArchive \
  -archivePath "${ARCHIVE_PATH}" \
  -exportPath "${EXPORT_PATH}" \
  -exportOptionsPlist "${EXPORT_OPTIONS_PATH}"

IPA_PATH="$(find "${EXPORT_PATH}" -maxdepth 1 -name "*.ipa" -print -quit)"
if [[ -z "${IPA_PATH}" ]]; then
  echo "Signed IPA was not created in ${EXPORT_PATH}" >&2
  exit 1
fi

echo "${IPA_PATH}"
