#!/usr/bin/env bash
# Package a built .app from an .xcarchive into an UNSIGNED .ipa.
# AltStore re-signs on device with the user's free Apple ID, so we ship unsigned.
set -euo pipefail

ARCHIVE="${1:-build/HermesNative.xcarchive}"
OUT="${2:-build/HermesNative.ipa}"

APP_DIR="$ARCHIVE/Products/Applications"
APP="$(/usr/bin/find "$APP_DIR" -maxdepth 1 -name '*.app' -print -quit)"
if [[ -z "${APP:-}" || ! -d "$APP" ]]; then
  echo "error: no .app found under $APP_DIR" >&2
  exit 1
fi

WORK="$(dirname "$OUT")"
mkdir -p "$WORK"
rm -rf "$WORK/Payload" "$OUT"
mkdir -p "$WORK/Payload"
cp -R "$APP" "$WORK/Payload/"

# Strip any signature so the artifact is unambiguously unsigned.
rm -rf "$WORK/Payload/"*.app/_CodeSignature 2>/dev/null || true

( cd "$WORK" && /usr/bin/zip -qry "$(basename "$OUT")" Payload )
rm -rf "$WORK/Payload"

echo "wrote $OUT ($(du -h "$OUT" | cut -f1))"
