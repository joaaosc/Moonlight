#!/bin/bash
# Installs Moonlight into /Applications, the canonical location.
#
# Copying replaces whatever is already installed, so the script asks first and
# does nothing without an explicit answer. Data lives in the App Group container
# and is untouched by an install.
set -euo pipefail

APP="${1:-build.noindex/release/export/Moonlight.app}"
DESTINATION="/Applications/Moonlight.app"

if [ ! -d "$APP" ]; then
    echo "No app bundle at $APP. Build one with Scripts/release.sh first." >&2
    exit 1
fi

echo "Installing:"
echo "  from $APP"
echo "  to   $DESTINATION"
if [ -d "$DESTINATION" ]; then
    echo "  (replaces the version already installed)"
fi
read -r -p "Continue? [y/N] " answer
case "$answer" in
    y | Y) ;;
    *) echo "Nothing was installed."; exit 0 ;;
esac

# Quit the running copy so the replaced bundle is not in use.
osascript -e 'tell application "Moonlight" to quit' 2>/dev/null || true

rm -rf "$DESTINATION"
cp -R "$APP" "$DESTINATION"

echo "==> Verifying the installed bundle"
codesign --verify --strict "$DESTINATION"

# Registering makes the App Intents and widgets visible without a logout.
/System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister \
    -f "$DESTINATION"

echo "Installed. Open it from /Applications when you want to run it."
