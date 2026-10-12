#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")/.."

# Notariza y grapa el DMG. Pasa las credenciales de notarytool:
#   scripts/notarize.sh --keychain-profile "AC_PASSWORD"
#   scripts/notarize.sh --apple-id "tu@id" --team-id "FL97XCW5XD" --password "xxxx-xxxx-xxxx-xxxx"
#   scripts/notarize.sh --key "AuthKey_XXX.p8" --key-id "XXX" --issuer "xxxx"

DMG="dist/elen.dmg"
[ -f "$DMG" ] || { echo "Falta $DMG (ejecuta scripts/package.sh)"; exit 1; }

echo "Enviando a notarizar…"
xcrun notarytool submit "$DMG" "$@" --wait

echo "Grapando el ticket…"
xcrun stapler staple "$DMG"
xcrun stapler validate "$DMG"

echo "Comprobando Gatekeeper…"
spctl -a -t open --context context:primary-signature -v "$DMG"
echo "Notarización OK."
