#!/bin/sh
# Runs after Xcode Cloud clones the repository, before anything is built.
#
# Two jobs, in order:
#   1. Write the build number. Xcode Cloud owns it, and Config/Version.xcconfig
#      picks it up through an optional include. Nothing is committed.
#   2. Regenerate the Xcode project from project.yml, so a stale .pbxproj can
#      never make the cloud build something the source no longer describes.
set -e

# Xcode Cloud runs custom scripts with ci_scripts as the working directory.
REPO="${CI_PRIMARY_REPOSITORY_PATH:-$(cd "$(dirname "$0")/.." && pwd)}"
cd "$REPO"

echo "==> Repository: $REPO"
echo "==> Workflow: ${CI_WORKFLOW:-unknown} on ${CI_BRANCH:-unknown branch}"

echo "==> Writing the build number"
# Reads CI_BUILD_NUMBER from the environment. The commit-count fallback in the
# script is for local runs; the clone here is shallow and would count wrong.
./Scripts/version.sh

echo "==> Regenerating the project from project.yml"
if ! command -v xcodegen > /dev/null 2>&1; then
    # Homebrew is part of the temporary build environment and sudo is neither
    # available nor needed. The install is allowed to fail on purpose: Apple
    # has documented Homebrew breaking on prerelease macOS images, and a
    # missing generator must not take the build down with it.
    brew install --quiet xcodegen || true
fi

if command -v xcodegen > /dev/null 2>&1; then
    xcodegen generate --quiet
else
    # Not fatal: the project is committed, so the build still has a
    # project to use. It is only no longer guaranteed to match project.yml,
    # which is worth saying out loud in the build log.
    echo "    xcodegen unavailable; building the committed project as-is."
fi

echo "==> Post-clone finished"
