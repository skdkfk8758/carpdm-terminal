#!/bin/zsh
set -euo pipefail

ROOT_DIR="${ROOT_DIR:-$PWD}"
APP_PATH="${APP_PATH:-$ROOT_DIR/build/CarpdmTerminal.xcarchive/Products/Applications/CarpdmTerminal.app}"
DMG_PATH="${DMG_PATH:-$ROOT_DIR/dist/CarpdmTerminal.dmg}"
STAGING_DIR="${STAGING_DIR:-$ROOT_DIR/build/dmg}"

rm -rf "$STAGING_DIR"
mkdir -p "$STAGING_DIR"
cp -R "$APP_PATH" "$STAGING_DIR/CarpdmTerminal.app"
ln -s /Applications "$STAGING_DIR/Applications"

hdiutil create \
  -volname "CarpdmTerminal" \
  -srcfolder "$STAGING_DIR" \
  -ov \
  -format UDZO \
  "$DMG_PATH"

echo "DMG_PATH=$DMG_PATH" >> "$GITHUB_ENV"

