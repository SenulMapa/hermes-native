#!/usr/bin/env bash
# Regenerate the AltStore source manifest (source.json) with a new version entry.
# Keeps existing versions so AltStore shows history; prepends the newest.
#
# Required env:
#   VERSION       e.g. 0.1.42
#   DOWNLOAD_URL  https URL of the .ipa release asset
#   IPA_PATH      local path to the .ipa (for size)
# Optional env:
#   DATE          ISO date (default: today, UTC)
#   NOTES         release notes string
#   MIN_OS        minimum iOS (default 26.0)
set -euo pipefail

: "${VERSION:?VERSION required}"
: "${DOWNLOAD_URL:?DOWNLOAD_URL required}"
: "${IPA_PATH:?IPA_PATH required}"
DATE="${DATE:-$(date -u +%F)}"
NOTES="${NOTES:-Automated build $VERSION.}"
MIN_OS="${MIN_OS:-26.0}"
SOURCE_FILE="${SOURCE_FILE:-source.json}"

SIZE="$(stat -f%z "$IPA_PATH" 2>/dev/null || stat -c%s "$IPA_PATH")"

# Build the new version object.
NEW_VERSION=$(VERSION="$VERSION" DATE="$DATE" NOTES="$NOTES" \
  DOWNLOAD_URL="$DOWNLOAD_URL" SIZE="$SIZE" MIN_OS="$MIN_OS" \
  python3 - <<'PY'
import json, os
print(json.dumps({
    "version": os.environ["VERSION"],
    "date": os.environ["DATE"],
    "localizedDescription": os.environ["NOTES"],
    "downloadURL": os.environ["DOWNLOAD_URL"],
    "size": int(os.environ["SIZE"]),
    "minOSVersion": os.environ["MIN_OS"],
}))
PY
)

# Merge into existing source.json (or scaffold a fresh one), newest first,
# de-duplicating by version.
NEW_VERSION="$NEW_VERSION" SOURCE_FILE="$SOURCE_FILE" python3 - <<'PY'
import json, os

new = json.loads(os.environ["NEW_VERSION"])
path = os.environ["SOURCE_FILE"]

try:
    with open(path) as f:
        src = json.load(f)
except (FileNotFoundError, json.JSONDecodeError):
    src = {
        "name": "Hermes Native",
        "identifier": "com.senulmapa.hermesnative.source",
        "subtitle": "Your Hermes agent, natively.",
        "apps": [{
            "name": "Hermes",
            "bundleIdentifier": "com.senulmapa.hermesnative",
            "developerName": "Senul Mapa",
            "subtitle": "Terminal-grade, mobile-shaped.",
            "localizedDescription": "Native SwiftUI client for the Hermes agent: "
                                    "streaming chat, full SSH terminal, cron, projects and more.",
            "iconURL": "https://raw.githubusercontent.com/SenulMapa/hermes-native/main/assets/icon.png",
            "tintColor": "6B66F5",
            "category": "developer",
            "screenshotURLs": [],
            "versions": [],
        }],
    }

app = src["apps"][0]
versions = [v for v in app.get("versions", []) if v.get("version") != new["version"]]
versions.insert(0, new)
app["versions"] = versions
# Mirror the newest version onto the legacy top-level fields some AltStore builds read.
app["version"] = new["version"]
app["versionDate"] = new["date"]
app["versionDescription"] = new["localizedDescription"]
app["downloadURL"] = new["downloadURL"]
app["size"] = new["size"]
app["minOSVersion"] = new["minOSVersion"]

with open(path, "w") as f:
    json.dump(src, f, indent=2)
    f.write("\n")
print(f"updated {path} -> {new['version']} ({new['size']} bytes)")
PY
