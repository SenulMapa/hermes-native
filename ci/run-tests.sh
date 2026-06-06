#!/usr/bin/env bash
# Run unit tests on an iOS simulator in CI.
# Newly-selected Xcodes on GitHub runners can ship without an iOS simulator
# runtime, so we download one first, then pick a destination from xcodebuild's
# OWN list (-showdestinations) — the authoritative source, so the id always
# matches what xcodebuild will accept.
set -euo pipefail

PROJECT="${PROJECT:-HermesNative.xcodeproj}"
SCHEME="${SCHEME:-HermesNative}"

echo "::group::Ensure iOS simulator runtime"
xcodebuild -downloadPlatform iOS -quiet || echo "downloadPlatform iOS skipped/failed (may already exist)"
echo "::endgroup::"

echo "::group::Available destinations"
DESTS="$(xcodebuild -project "$PROJECT" -scheme "$SCHEME" -showdestinations 2>/dev/null || true)"
echo "$DESTS"
echo "::endgroup::"

pick_id() { # $1 = grep pattern for the device name
  echo "$DESTS" \
    | grep "platform:iOS Simulator" \
    | grep -v "placeholder" \
    | grep -E "$1" \
    | head -1 \
    | sed -E 's/.*[^A-Za-z]id:([0-9A-Fa-f-]+).*/\1/'
}

DEST_ID="$(pick_id 'name:iPhone')"
[ -z "$DEST_ID" ] && DEST_ID="$(pick_id 'name:')"   # fall back to any iOS sim

if [ -z "$DEST_ID" ]; then
  echo "error: no iOS Simulator destination available" >&2
  exit 1
fi

echo "::group::HermesAPI package tests (host)"
swift test --package-path Packages/HermesAPI
echo "::endgroup::"

echo "Testing app on iOS Simulator id=$DEST_ID"
xcodebuild test \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -destination "id=$DEST_ID" \
  CODE_SIGNING_ALLOWED=NO
