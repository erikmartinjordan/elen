#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")/.."

# Firma con Developer ID, endurece el runtime y crea el .dmg
IDENTITY="${IDENTITY:-Developer ID Application: Erik Martín Jordán (FL97XCW5XD)}"

echo "Compilando…"
swift build -c release

APP="elen.app"
rm -rf "$APP" dist build_dmg
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/elen "$APP/Contents/MacOS/elen"
cp Info.plist "$APP/Contents/Info.plist"
cp AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

echo "Firmando (Developer ID, hardened runtime)…"
codesign --force --options runtime --timestamp \
  --entitlements elen.entitlements \
  --sign "$IDENTITY" "$APP"
codesign --verify --strict --verbose=2 "$APP"

echo "Creando el DMG…"
mkdir -p build_dmg dist
cp -R "$APP" build_dmg/
ln -s /Applications build_dmg/Applications
hdiutil create -volname "elen" -srcfolder build_dmg -ov -format UDZO dist/elen.dmg
codesign --force --timestamp --sign "$IDENTITY" dist/elen.dmg

echo ""
echo "Hecho: $(pwd)/dist/elen.dmg"
