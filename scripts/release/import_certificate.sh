#!/bin/zsh
set -euo pipefail

: "${APPLE_DEVELOPER_ID_APPLICATION_P12_BASE64:?Missing APPLE_DEVELOPER_ID_APPLICATION_P12_BASE64}"
: "${APPLE_DEVELOPER_ID_APPLICATION_P12_PASSWORD:?Missing APPLE_DEVELOPER_ID_APPLICATION_P12_PASSWORD}"
: "${KEYCHAIN_PASSWORD:?Missing KEYCHAIN_PASSWORD}"

KEYCHAIN_PATH="${RUNNER_TEMP:-/tmp}/carpdm-build.keychain-db"
CERT_PATH="${RUNNER_TEMP:-/tmp}/developer-id-application.p12"

trap 'rm -f "$CERT_PATH"' EXIT

echo "$APPLE_DEVELOPER_ID_APPLICATION_P12_BASE64" | base64 --decode > "$CERT_PATH"

security create-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN_PATH"
security set-keychain-settings -lut 21600 "$KEYCHAIN_PATH"
security unlock-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN_PATH"
security list-keychains -d user -s "$KEYCHAIN_PATH"
security import "$CERT_PATH" -k "$KEYCHAIN_PATH" -P "$APPLE_DEVELOPER_ID_APPLICATION_P12_PASSWORD" -T /usr/bin/codesign -T /usr/bin/security -T /usr/bin/productbuild
security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "$KEYCHAIN_PASSWORD" "$KEYCHAIN_PATH"

echo "KEYCHAIN_PATH=$KEYCHAIN_PATH" >> "$GITHUB_ENV"
