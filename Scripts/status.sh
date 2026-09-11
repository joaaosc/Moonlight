#!/bin/bash
# Compares the app installed in /Applications with the current checkout.
#
# The installed copy is the only one Launch Services keeps registered, so every
# Spotlight, App Intents or widget check runs against it — not against whatever
# was just compiled. Nothing in the system reports that gap, so it is reported
# here: the build number is the commit count, which makes the two directly
# comparable without adding anything to the bundle.
#
# Exit status is 0 when the installed copy matches HEAD and 1 when it does not,
# so this can gate a runtime validation instead of being read by eye.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
INSTALLED="/Applications/Moonlight.app"
PLIST="$INSTALLED/Contents/Info.plist"

HEAD_BUILD="$(git -C "$ROOT" rev-list --count HEAD)"
HEAD_SHA="$(git -C "$ROOT" rev-parse --short HEAD)"

if [ ! -d "$INSTALLED" ]; then
    echo "Not installed: $INSTALLED is missing."
    echo "Checkout: build $HEAD_BUILD ($HEAD_SHA)"
    echo
    echo "Install it with: bash Scripts/dev-install.sh"
    exit 1
fi

INSTALLED_BUILD="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$PLIST")"
INSTALLED_VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$PLIST")"

echo "Installed: $INSTALLED_VERSION ($INSTALLED_BUILD), $(stat -f '%Sm' "$INSTALLED")"
echo "Checkout:  build $HEAD_BUILD ($HEAD_SHA)"

# The build number only tracks commits, so it cannot see an uncommitted edit.
# The bundle being older than the newest source can, and it covers both cases:
# a source touched after the install is a source the installed copy lacks,
# committed or not.
NEWER_SOURCES="$(find "$ROOT/App" "$ROOT/Packages" "$ROOT/Config" "$ROOT/project.yml" \
    -newer "$INSTALLED/Contents/MacOS/Moonlight" \
    -type f \
    ! -name '.DS_Store' \
    ! -name 'Version.generated.xcconfig' \
    2>/dev/null | head -5)"

echo
echo "Registered copies:"
"/System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister" -dump 2>/dev/null \
    | sed -n 's/^[[:space:]]*path:[[:space:]]*\(.*Moonlight\.app\) (0x[0-9a-f]*)$/\1/p' \
    | sort -u \
    | sed 's/^/  /'

echo
if [ "$INSTALLED_BUILD" != "$HEAD_BUILD" ]; then
    BEHIND=$((HEAD_BUILD - INSTALLED_BUILD))
    echo "Stale: the installed copy is $BEHIND commit(s) behind HEAD."
    echo "Refresh it with: bash Scripts/dev-install.sh"
    exit 1
fi

if [ -n "$NEWER_SOURCES" ]; then
    echo "Stale: sources changed after the install, so they are not in the bundle:"
    echo "$NEWER_SOURCES" | sed 's|^'"$ROOT"'/|  |'
    echo "Refresh it with: bash Scripts/dev-install.sh"
    exit 1
fi

echo "Current: the installed copy carries what is on disk."
