#!/usr/bin/env bash
# Run unit tests on an iOS simulator in CI, ensuring a runtime + device exist.
# Newly-selected Xcodes on GitHub runners sometimes ship without an iOS
# simulator runtime, so we download one and create a device if necessary.
set -euo pipefail

PROJECT="${PROJECT:-HermesNative.xcodeproj}"
SCHEME="${SCHEME:-HermesNative}"

echo "::group::Ensure iOS simulator runtime"
xcodebuild -downloadPlatform iOS -quiet || echo "downloadPlatform iOS skipped/failed (may already exist)"
echo "::endgroup::"

pick_udid() {
  xcrun simctl list devices available -j | python3 -c '
import json, sys
d = json.load(sys.stdin)["devices"]
ids = [x["udid"] for v in d.values() for x in v if "iPhone" in x["name"]]
print(ids[0] if ids else "")'
}

UDID="$(pick_udid)"

if [ -z "$UDID" ]; then
  echo "No iPhone simulator available; creating one."
  RT="$(xcrun simctl list runtimes -j | python3 -c '
import json, sys
r = [x["identifier"] for x in json.load(sys.stdin)["runtimes"] if x.get("isAvailable") and "iOS" in x["identifier"]]
print(r[-1] if r else "")')"
  DT="$(xcrun simctl list devicetypes -j | python3 -c '
import json, sys
d = [x["identifier"] for x in json.load(sys.stdin)["devicetypes"] if "iPhone" in x["name"]]
print(d[-1] if d else "")')"
  if [ -z "$RT" ] || [ -z "$DT" ]; then
    echo "error: no iOS runtime ($RT) or iPhone device type ($DT) available" >&2
    exit 1
  fi
  UDID="$(xcrun simctl create ci-iphone "$DT" "$RT")"
fi

echo "Testing on simulator $UDID"
xcodebuild test \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -destination "id=$UDID" \
  CODE_SIGNING_ALLOWED=NO
