#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

CONFIG="${CONFIG:-release}"
APP_NAME="Time to Meet"
APP_DIR="build/${APP_NAME}.app"

echo "→ Building Swift package ($CONFIG)"
swift build -c "$CONFIG"

BIN_PATH=".build/$CONFIG/TimeToMeet"
if [ ! -f "$BIN_PATH" ]; then
    echo "Build output missing at $BIN_PATH" >&2
    exit 1
fi

echo "→ Generating app icon"
chmod +x tools/make_icns.sh
tools/make_icns.sh build/AppIcon.icns >/dev/null

echo "→ Stopping any running instance (graceful)"
osascript -e 'tell application "Time to Meet" to quit' 2>/dev/null || true
# Give cfprefsd time to flush UserDefaults to disk before any further work
for _ in 1 2 3 4 5 6 7 8 9 10; do
    pgrep -x TimeToMeet >/dev/null || break
    sleep 0.2
done
pkill -x TimeToMeet 2>/dev/null || true

echo "→ Assembling .app bundle"
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"
cp "$BIN_PATH" "$APP_DIR/Contents/MacOS/TimeToMeet"
cp Resources/Info.plist "$APP_DIR/Contents/Info.plist"
cp build/AppIcon.icns "$APP_DIR/Contents/Resources/AppIcon.icns"

echo "→ Ad-hoc signing"
codesign --force --deep --sign - "$APP_DIR" >/dev/null

echo
echo "✓ Built $APP_DIR"
echo
echo "Run it:    open \"$APP_DIR\""
echo "Install:   cp -R \"$APP_DIR\" /Applications/"
