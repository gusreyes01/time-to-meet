#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

OUT="${1:-Resources/AppIcon.icns}"
ICONSET="$(mktemp -d)/AppIcon.iconset"
mkdir -p "$ICONSET"

SRC="$ICONSET/_source.png"
cp Resources/AppIcon-source.png "$SRC"

for pair in 16:icon_16x16.png 32:icon_16x16@2x.png 32:icon_32x32.png 64:icon_32x32@2x.png \
            128:icon_128x128.png 256:icon_128x128@2x.png 256:icon_256x256.png \
            512:icon_256x256@2x.png 512:icon_512x512.png 1024:icon_512x512@2x.png; do
    sz="${pair%%:*}"
    name="${pair##*:}"
    sips -z "$sz" "$sz" "$SRC" --out "$ICONSET/$name" >/dev/null
done
rm "$SRC"

mkdir -p "$(dirname "$OUT")"
iconutil -c icns "$ICONSET" -o "$OUT"
rm -rf "$ICONSET"
echo "Wrote $OUT"
