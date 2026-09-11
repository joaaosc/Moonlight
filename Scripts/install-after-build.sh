#!/bin/bash
# Entry point for Xcode's "When build succeeds" behavior.
#
# The behavior sheet takes a script path and nothing else: it cannot pass
# arguments, so the flags live here instead of in the Xcode setting.
#
# It also runs after every successful build, including builds for testing, and
# installing means quitting the running copy. So this checks first and does
# nothing when the installed copy is already current — an unchanged build should
# not interrupt whatever is on screen.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

if bash "$ROOT/Scripts/status.sh" >/dev/null 2>&1; then
    logger -t moonlight-install "installed copy already current; nothing to do"
    exit 0
fi

# Output goes nowhere visible from a behavior, so the record goes to the system
# log, where `log show --predicate 'process == "logger"'` can find it.
if output="$(bash "$ROOT/Scripts/dev-install.sh" --skip-build 2>&1)"; then
    logger -t moonlight-install "installed: $(printf '%s' "$output" | tail -1)"
else
    status=$?
    logger -t moonlight-install "install FAILED ($status): $(printf '%s' "$output" | tail -3)"
    exit "$status"
fi
