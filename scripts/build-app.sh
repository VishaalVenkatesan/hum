#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/build/Hum.app"

cd "$ROOT"
swift build -c release --arch arm64

BIN="$(swift build -c release --arch arm64 --show-bin-path)/Hum"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/Hum"
cp "$ROOT/Resources/Info.plist" "$APP/Contents/Info.plist"

codesign --force --deep --sign - "$APP"

echo "Built $APP"

if [[ "${1:-}" == "--zip" ]]; then
  rm -f "$ROOT/build/Hum.zip"
  ditto -c -k --keepParent "$APP" "$ROOT/build/Hum.zip"
  echo "Packaged $ROOT/build/Hum.zip"
fi

if [[ "${1:-}" == "--install" ]]; then
  pkill -x Hum || true
  rm -rf /Applications/Hum.app
  cp -R "$APP" /Applications/
  open /Applications/Hum.app
  echo "Installed to /Applications/Hum.app"
fi
