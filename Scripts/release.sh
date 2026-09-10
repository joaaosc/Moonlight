#!/bin/bash
# Builds a signed, notarizable Moonlight release.
#
# The script never notarizes on its own: notarization uploads the app to Apple
# and needs credentials that belong to the developer, so it is the last step and
# it is explicit. Run it from the repository root.
set -euo pipefail

SCHEME="Moonlight"
PROJECT="Moonlight.xcodeproj"
BUILD_DIR="${BUILD_DIR:-build/release}"
ARCHIVE="$BUILD_DIR/Moonlight.xcarchive"
EXPORT_DIR="$BUILD_DIR/export"
TEAM_ID="${TEAM_ID:-33FPG9442W}"

echo "==> Regenerating the project from project.yml"
xcodegen generate --quiet

echo "==> Archiving $SCHEME (Release)"
rm -rf "$ARCHIVE" "$EXPORT_DIR"
xcodebuild -project "$PROJECT" \
    -scheme "$SCHEME" \
    -configuration Release \
    -destination 'generic/platform=macOS' \
    -archivePath "$ARCHIVE" \
    archive

echo "==> Exporting with Developer ID"
cat > "$BUILD_DIR/ExportOptions.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>method</key>
	<string>developer-id</string>
	<key>teamID</key>
	<string>$TEAM_ID</string>
	<key>signingStyle</key>
	<string>automatic</string>
</dict>
</plist>
PLIST

xcodebuild -exportArchive \
    -archivePath "$ARCHIVE" \
    -exportOptionsPlist "$BUILD_DIR/ExportOptions.plist" \
    -exportPath "$EXPORT_DIR"

APP="$EXPORT_DIR/Moonlight.app"

echo "==> Verifying the signature"
# --strict without --deep: the modern check, which also validates the nested
# extensions the way the system does at launch.
codesign --verify --strict --verbose=2 "$APP"
codesign --display --entitlements - --xml "$APP" | plutil -convert xml1 -o - -

echo "==> Assessing with Gatekeeper (fails until the app is notarized)"
spctl --assess --type execute --verbose=4 "$APP" || \
    echo "    Not accepted yet: notarize and staple before distributing."

cat <<'NEXT'

Next steps, which touch Apple's servers and need your credentials:

  xcrun notarytool submit --keychain-profile "<profile>" --wait \
      <zip or dmg containing Moonlight.app>
  xcrun stapler staple build/release/export/Moonlight.app

Store the credentials once with:

  xcrun notarytool store-credentials "<profile>" \
      --apple-id "<apple id>" --team-id 33FPG9442W

NEXT
