#!/bin/bash
set -euo pipefail

REPO="VishaalVenkatesan/hum"
URL="https://github.com/$REPO/releases/latest/download/Hum.zip"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

if [[ "$(uname -m)" != "arm64" ]]; then
  echo "Hum requires a Mac with Apple Silicon." >&2
  exit 1
fi

if [[ "$(sw_vers -productVersion | cut -d. -f1)" -lt 14 ]]; then
  echo "Hum requires macOS 14 Sonoma or later." >&2
  exit 1
fi

echo "Downloading Hum..."
curl -fsSL "$URL" -o "$TMP/Hum.zip"
ditto -x -k "$TMP/Hum.zip" "$TMP"

pkill -x Hum 2>/dev/null || true
while pgrep -x Hum >/dev/null; do sleep 0.2; done
rm -rf /Applications/Hum.app
mv "$TMP/Hum.app" /Applications/
xattr -dr com.apple.quarantine /Applications/Hum.app 2>/dev/null || true

open /Applications/Hum.app
echo "Hum is installed in /Applications and running in your menu bar."
