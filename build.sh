#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")"

echo "Compilando elen…"
swift build -c release

APP="elen.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/elen "$APP/Contents/MacOS/elen"
cp Info.plist "$APP/Contents/Info.plist"
cp AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

codesign --force --sign - "$APP" >/dev/null 2>&1 || true

echo ""
echo "Listo: $(pwd)/$APP"
echo "Para abrirla:  open \"$(pwd)/$APP\""
