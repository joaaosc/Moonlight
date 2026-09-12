#!/bin/bash
# Builds Debug and replaces the copy in /Applications.
#
# Every system surface — App Intents, widgets, the Spotlight shorthands — reads
# the bundle Launch Services has registered, and this project keeps exactly one
# registered copy, in /Applications. So a change is not observable until it is
# installed there, and Scripts/release.sh is the wrong tool for that: it
# archives Release with whole-module optimization and exports with Developer ID,
# which is minutes per iteration and exists for notarization, not for a loop.
#
# This is the loop: compile Debug, install, register, drop the stray copies.
# Signing, entitlements, sandbox and hardened runtime are the same as Release,
# so what the system sees is equivalent for validation purposes.
#
# With --skip-build it installs a product that was already compiled, which is
# what Xcode's "When build succeeds" behavior needs: the build is over by the
# time the behavior fires, and rebuilding there would repeat the work that just
# finished.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

SCHEME="Moonlight"
PROJECT="MoonlightTools.xcodeproj"
DERIVED="build.noindex/DerivedData"
CONFIGURATION="${CONFIGURATION:-Debug}"
DESTINATION="/Applications/Moonlight.app"

SKIP_BUILD=""
for argument in "$@"; do
    case "$argument" in
        --skip-build) SKIP_BUILD="yes" ;;
        *) echo "Unknown argument: $argument" >&2; exit 2 ;;
    esac
done

# Three trees can hold a product: the one xcodebuild writes here and in
# release.sh, the one Xcode writes when the build is started from its interface
# (build.noindex/Products, set as the workspace build location so no app bundle
# lands in an indexed directory), and the global DerivedData that older
# checkouts still used. Picking one by name installs the wrong bundle half the
# time, so --skip-build picks the most recently built one, which is what "the
# build that just finished" means in every case.
newest_built_app() {
    local candidates=()
    local candidate_app
    for candidate_app in \
        "$ROOT/$DERIVED/Build/Products/$CONFIGURATION/Moonlight.app" \
        "$ROOT/build.noindex/Products/$CONFIGURATION/Moonlight.app"; do
        [ -d "$candidate_app" ] && candidates+=("$candidate_app")
    done

    local global_app
    for global_app in "$HOME/Library/Developer/Xcode/DerivedData"/Moonlight*Tools-*/Build/Products/"$CONFIGURATION"/Moonlight.app; do
        [ -d "$global_app" ] && candidates+=("$global_app")
    done

    [ ${#candidates[@]} -eq 0 ] && return 1
    # Compare the executables: the bundle directory's timestamp does not move
    # when only its contents are rewritten.
    for candidate in "${candidates[@]}"; do
        printf '%s\t%s\n' "$(stat -f '%m' "$candidate/Contents/MacOS/Moonlight" 2>/dev/null || echo 0)" "$candidate"
    done | sort -rn | head -1 | cut -f2-
}

echo "==> Writing the build number"
bash Scripts/version.sh

# Regenerating unconditionally would rewrite the project file under an open
# Xcode on every run, so it happens only when project.yml is actually newer.
if [ -z "$SKIP_BUILD" ] && [ "project.yml" -nt "$PROJECT/project.pbxproj" ]; then
    echo "==> project.yml changed, regenerating the project"
    xcodegen generate --quiet
    Scripts/sync-test-plans.sh
fi

if [ -n "$SKIP_BUILD" ]; then
    echo "==> Using the product from the build that just finished"
else
    echo "==> Building $SCHEME ($CONFIGURATION)"
    xcodebuild -project "$PROJECT" \
        -scheme "$SCHEME" \
        -configuration "$CONFIGURATION" \
        -destination 'platform=macOS' \
        -derivedDataPath "$DERIVED" \
        build
fi

# Always by timestamp, never by name: the workspace build location decides
# where the product lands, and it overrides -derivedDataPath, so the path this
# build wrote to is not the one the flag above names.
APP="$(newest_built_app || true)"

if [ -z "${APP:-}" ] || [ ! -d "$APP" ]; then
    echo "No compiled Moonlight.app found for configuration $CONFIGURATION." >&2
    [ -n "$SKIP_BUILD" ] && echo "Build the scheme first, or drop --skip-build." >&2
    exit 1
fi
echo "    $APP"

echo "==> Installing into $DESTINATION"
# The running copy holds the bundle open; replacing it underneath leaves the
# process talking to a deleted bundle.
osascript -e 'tell application "Moonlight" to quit' 2>/dev/null || true

rm -rf "$DESTINATION"
cp -R "$APP" "$DESTINATION"

echo "==> Verifying the signature"
codesign --verify --strict "$DESTINATION"

echo "==> Registering"
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister"
"$LSREGISTER" -f "$DESTINATION"

# The build product carries the same identifier as the installed app, and a
# second registered bundle is what makes Spotlight show duplicate entries.
echo "==> Dropping the other registered copies"
bash Scripts/clean-app-registrations.sh

echo
bash Scripts/status.sh
