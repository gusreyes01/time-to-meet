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
ICONSET="build/AppIcon.iconset"
rm -rf "$ICONSET"
mkdir -p "$ICONSET"
SRC="$ICONSET/_source.png"
swift tools/make_icon.swift "$SRC" >/dev/null

gen() { sips -z "$2" "$2" "$SRC" --out "$ICONSET/$1" >/dev/null; }
gen icon_16x16.png       16
gen icon_16x16@2x.png    32
gen icon_32x32.png       32
gen icon_32x32@2x.png    64
gen icon_128x128.png     128
gen icon_128x128@2x.png  256
gen icon_256x256.png     256
gen icon_256x256@2x.png  512
gen icon_512x512.png     512
gen icon_512x512@2x.png  1024
rm "$SRC"

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
iconutil -c icns "$ICONSET" -o "$APP_DIR/Contents/Resources/AppIcon.icns"
rm -rf "$ICONSET"

echo "→ Ad-hoc signing"
codesign --force --deep --sign - "$APP_DIR" >/dev/null

echo
echo "✓ Built $APP_DIR"
echo
echo "Run it:    open \"$APP_DIR\""
echo "Install:   cp -R \"$APP_DIR\" /Applications/"
