#!/bin/bash
# Writes the build number that nobody commits.
#
# The number is derived, never stored: locally from the commit count, and in
# Xcode Cloud from the build number Apple assigns. Both are monotonic and
# neither produces a diff, which is the whole point — a build number in the
# repository turns every build into a commit and every branch into a conflict.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUTPUT="$ROOT/Config/Version.generated.xcconfig"

if [ -n "${CI_BUILD_NUMBER:-}" ]; then
    # Xcode Cloud owns the number. Its clone is shallow, so the commit count
    # would be wrong here even if we wanted it.
    BUILD_NUMBER="$CI_BUILD_NUMBER"
    SOURCE="Xcode Cloud"
else
    BUILD_NUMBER="$(git -C "$ROOT" rev-list --count HEAD)"
    SOURCE="commit count"
fi

cat > "$OUTPUT" <<CFG
// Written by Scripts/version.sh. Not tracked by Git; do not edit.
// Source: $SOURCE
CURRENT_PROJECT_VERSION = $BUILD_NUMBER
CFG

echo "Build number $BUILD_NUMBER ($SOURCE) -> ${OUTPUT#"$ROOT/"}"
