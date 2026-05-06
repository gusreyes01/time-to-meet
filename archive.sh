#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

TEAM_ID="${TEAM_ID:-T85644NQ7L}"
ARCHIVE_PATH="build/TimeToMeet.xcarchive"
EXPORT_PATH="build/TimeToMeet-export"

echo "→ Generating AppIcon.icns"
chmod +x tools/make_icns.sh
tools/make_icns.sh Resources/AppIcon.icns >/dev/null

echo "→ Regenerating Xcode project from project.yml"
xcodegen generate >/dev/null

echo "→ Archiving (Release, team $TEAM_ID)"
rm -rf "$ARCHIVE_PATH"
xcodebuild -project TimeToMeet.xcodeproj \
    -scheme TimeToMeet \
    -configuration Release \
    -destination 'platform=macOS' \
    -archivePath "$ARCHIVE_PATH" \
    DEVELOPMENT_TEAM="$TEAM_ID" \
    -allowProvisioningUpdates \
    archive >/dev/null

echo "→ Exporting for App Store Connect"
rm -rf "$EXPORT_PATH"
xcodebuild -exportArchive \
    -archivePath "$ARCHIVE_PATH" \
    -exportPath "$EXPORT_PATH" \
    -exportOptionsPlist ExportOptions.plist \
    -allowProvisioningUpdates >/dev/null

PKG="$EXPORT_PATH/Time to Meet.pkg"
if [ ! -f "$PKG" ]; then
    echo "Export did not produce the expected .pkg" >&2
    ls -la "$EXPORT_PATH" >&2
    exit 1
fi

echo
echo "✓ Built and signed: $PKG"
echo
echo "Validate: xcrun altool --validate-app -f \"$PKG\" -t macos --apiKey <KEY_ID> --apiIssuer <ISSUER_ID>"
echo "Upload:   xcrun altool --upload-app   -f \"$PKG\" -t macos --apiKey <KEY_ID> --apiIssuer <ISSUER_ID>"
echo "Or drag the .pkg into Transporter.app and click Deliver."
