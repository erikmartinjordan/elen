#!/bin/sh
# Importa el certificado Developer ID en un llavero temporal para firmar en CI.
# Uso: import-certs-ci.sh <ruta-base64-p12> <password>
set -eu

P12_B64="${1:?Uso: import-certs-ci.sh <ruta-base64-p12> <password>}"
PASSWORD="${2:?Uso: import-certs-ci.sh <ruta-base64-p12> <password>}"

TMP_P12="$(mktemp "${TMPDIR:-/tmp}/elen-cert.XXXXXX.p12")"
base64 --decode --output "$TMP_P12" < "$P12_B64"

KEYCHAIN="elenCI.keychain"
KEYCHAIN_PASSWORD="elen-ci-$(uuidgen)"

security create-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN"
security default-keychain -s "$KEYCHAIN"
security unlock-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN"
security set-keychain-settings -lut 600 "$KEYCHAIN"

security import "$TMP_P12" -k "$KEYCHAIN" -P "$PASSWORD" -T /usr/bin/codesign -f pkcs12

security set-key-partition-list \
  -S apple-tool:,apple:,codesign: \
  -s \
  -k "$KEYCHAIN_PASSWORD" \
  "$KEYCHAIN" >/dev/null

rm -f "$TMP_P12"

echo "Certificado importado."
echo "KEYCHAIN=$KEYCHAIN"
