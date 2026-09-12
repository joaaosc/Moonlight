#!/bin/bash
# Builds a signed, notarizable Moonlight release.
#
# The script never notarizes on its own: notarization uploads the app to Apple
# and needs credentials that belong to the developer, so it is the last step and
# it is explicit. Run it from the repository root.
set -euo pipefail

SCHEME="Moonlight"
PROJECT="MoonlightTools.xcodeproj"
# A ".noindex" suffix keeps Spotlight and Launch Services out of the build
# directory: an app bundle sitting there would otherwise be registered and show
# up next to the installed copy.
BUILD_DIR="${BUILD_DIR:-build.noindex/release}"
ARCHIVE="$BUILD_DIR/Moonlight.xcarchive"
EXPORT_DIR="$BUILD_DIR/export"
TEAM_ID="${TEAM_ID:-33FPG9442W}"

echo "==> Writing the build number"
# Derived, not committed: the release stamps whatever the commit count says at
# this moment. Raising a build number is no longer an edit to a tracked file.
bash "$(dirname "$0")/version.sh"

echo "==> Regenerating the project from project.yml"
xcodegen generate --quiet
# Target identifiers are derived from the project, so regenerating can move
# them. A test plan left pointing at an old identifier runs no tests and still
# reports success, so the two are re-synced here rather than by hand.
"$(dirname "$0")/sync-test-plans.sh"

echo "==> Archiving $SCHEME (Release)"
rm -rf "$ARCHIVE" "$EXPORT_DIR"
xcodebuild -project "$PROJECT" \
    -scheme "$SCHEME" \
    -configuration Release \
    -destination 'generic/platform=macOS' \
    -archivePath "$ARCHIVE" \
    -derivedDataPath build.noindex/DerivedData \
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

# The archive leaves a third bundle behind, under the intermediates. Found
# rather than spelled out: the workspace build location decides where the
# intermediates go and it overrides -derivedDataPath.
ARCHIVE_INTERMEDIATES="$(find "$BUILD_DIR" build.noindex -maxdepth 4 -type d -name ArchiveIntermediates 2>/dev/null | head -1)"
[ -n "$ARCHIVE_INTERMEDIATES" ] && rm -rf "$ARCHIVE_INTERMEDIATES"

# Two bundles with the same identifier confuse Launch Services and Spotlight,
# which is what makes several "Moonlight" entries appear in search. Run this
# after the intermediates are gone, so their registrations are dropped in the
# same pass as the archive's and the export's.
echo "==> Unregistering build copies so they do not shadow the installed app"
bash "$(dirname "$0")/clean-app-registrations.sh" >/dev/null 2>&1 || true

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
