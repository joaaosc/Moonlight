#!/bin/bash
# Removes every registered copy of Moonlight except the installed one.
#
# Xcode registers each build product it writes, and several bundles carrying
# the same identifier make Spotlight show one entry per copy and confuse the
# shorthand it learns for the app. Run this after building or testing.
set -euo pipefail

LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister"
KEEP="/Applications/Moonlight.app"

"$LSREGISTER" -dump 2>/dev/null \
    | sed -n 's/^[[:space:]]*path:[[:space:]]*\(.*Moonlight\.app\) (0x[0-9a-f]*)$/\1/p' \
    | sort -u \
    | while read -r bundle; do
        [ "$bundle" = "$KEEP" ] && continue
        echo "unregistering $bundle"
        "$LSREGISTER" -u "$bundle" 2>/dev/null || true
    done

echo "Registered copies now:"
"$LSREGISTER" -dump 2>/dev/null \
    | sed -n 's/^[[:space:]]*path:[[:space:]]*\(.*Moonlight\.app\) (0x[0-9a-f]*)$/\1/p' \
    | sort -u
