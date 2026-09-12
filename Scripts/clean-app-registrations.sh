#!/bin/bash
# Removes every Launch Services registration for Moonlight except the one
# pointing at the installed copy.
#
# Two things fill the database during development. Xcode registers each build
# product it writes, so a build directory, an archive, a test runner and a
# backup in the Trash each become an entry, and several bundles carrying the
# same identifier make Spotlight show one result per copy. Reading a bundle
# also registers it, which is what the launcher catalogue does, so a test run
# over throwaway fixtures leaves a record for each one.
#
# Deleting the bundle does not remove its record: the registration outlives the
# file, which is why a path that no longer exists still has to be unregistered
# by hand. Launch Services publishes no unregister call, so this drives the
# tool the system ships. Run it after building, testing or installing.
#
# Scope is deliberate: only bundles whose path names this project. Records
# belonging to other apps are not this script's business, even when they are
# stale.
set -euo pipefail

LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister"
KEEP="/Applications/Moonlight.app"

# `sed -E` because BSD sed does not accept `\?` in a basic expression, and the
# alternation between `.app` and `.appex` needs one.
registered_bundles() {
    "$LSREGISTER" -dump 2>/dev/null \
        | sed -nE 's/^[[:space:]]*path:[[:space:]]+(.*\.(app|appex)) \(0x[0-9a-f]+\)$/\1/p' \
        | sort -u
}

removed=0
while IFS= read -r bundle; do
    [ -n "$bundle" ] || continue
    # The installed copy, and the extensions inside it, are what the system
    # should resolve the app to.
    case "$bundle" in "$KEEP"|"$KEEP"/*) continue ;; esac
    # Anything else this project put there: a build product, an archive, a test
    # runner, a backup, or a launcher-test fixture.
    case "$bundle" in *[Mm]oonlight*) ;; *) continue ;; esac

    if [ -e "$bundle" ]; then reason="duplicate"; else reason="missing"; fi
    echo "unregistering ($reason) $bundle"
    "$LSREGISTER" -u "$bundle" 2>/dev/null || true
    removed=$((removed + 1))
done <<< "$(registered_bundles)"

echo "Unregistered $removed bundle(s)."
echo "Registered Moonlight bundles now:"
registered_bundles | grep -i moonlight || echo "  (none)"
