#!/bin/zsh
set -euo pipefail

ROOT_DIR="${ROOT_DIR:-$PWD}"
SCHEME="${SCHEME:-CarpdmTerminal}"
PROJECT_PATH="${PROJECT_PATH:-$ROOT_DIR/CarpdmTerminal.xcodeproj}"
ARCHIVE_PATH="${ARCHIVE_PATH:-$ROOT_DIR/build/CarpdmTerminal.xcarchive}"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-$ROOT_DIR/build/DerivedData}"

: "${APPLE_TEAM_ID:?Missing APPLE_TEAM_ID}"

mkdir -p "$ROOT_DIR/build"

xcodegen generate --spec "$ROOT_DIR/project.yml"

xcodebuild \
  -project "$PROJECT_PATH" \
  -scheme "$SCHEME" \
  -configuration Release \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  -archivePath "$ARCHIVE_PATH" \
  DEVELOPMENT_TEAM="$APPLE_TEAM_ID" \
  CODE_SIGN_STYLE=Manual \
  CODE_SIGN_IDENTITY="Developer ID Application" \
  archive

APP_PATH="$ARCHIVE_PATH/Products/Applications/CarpdmTerminal.app"
ZIP_PATH="$ROOT_DIR/dist/CarpdmTerminal.zip"

mkdir -p "$ROOT_DIR/dist"
/usr/bin/ditto -c -k --keepParent "$APP_PATH" "$ZIP_PATH"

echo "APP_PATH=$APP_PATH" >> "$GITHUB_ENV"
echo "ZIP_PATH=$ZIP_PATH" >> "$GITHUB_ENV"
echo "DERIVED_DATA_PATH=$DERIVED_DATA_PATH" >> "$GITHUB_ENV"

