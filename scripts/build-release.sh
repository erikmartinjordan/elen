#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")/.."

# Compila, firma con Developer ID (hardened runtime), crea y firma el DMG.
# La identidad se toma de IDENTITY o del primer "Developer ID Application" del llavero.
IDENTITY="${IDENTITY:-$(security find-identity -v -p codesigning | grep 'Developer ID Application' | head -1 | sed 's/.*"\(.*\)"/\1/')}"
if [ -z "$IDENTITY" ]; then
  echo "No se encontró una identidad Developer ID Application." >&2
  exit 1
fi
echo "Identidad: $IDENTITY"

swift build -c release

APP="elen.app"
rm -rf "$APP" dist build_dmg
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/elen "$APP/Contents/MacOS/elen"
cp Info.plist "$APP/Contents/Info.plist"
cp AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

codesign --force --options runtime --timestamp \
  --entitlements elen.entitlements \
  --sign "$IDENTITY" "$APP"
codesign --verify --strict --verbose=2 "$APP"

mkdir -p build_dmg dist
cp -R "$APP" build_dmg/
ln -s /Applications build_dmg/Applications
hdiutil create -volname "elen" -srcfolder build_dmg -ov -format UDZO dist/elen.dmg
codesign --force --timestamp --sign "$IDENTITY" dist/elen.dmg

echo "DMG: $(pwd)/dist/elen.dmg"
