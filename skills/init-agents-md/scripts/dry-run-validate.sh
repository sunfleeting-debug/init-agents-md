#!/usr/bin/env bash
# Run sanity checks against a generated shell script.
# Usage: dry-run-validate.sh <script-path>
# Exit: 0 if all checks pass, non-zero otherwise.
#
# Checks performed:
#   1. bash -n  — syntax
#   2. bash <script> --help  — at least runs (script returns non-error on --help)
#   3. If the script references a known tool, check it's on PATH (informational)

set -uo pipefail

if [ $# -lt 1 ]; then
    echo "Usage: dry-run-validate.sh <script>" >&2
    exit 2
fi

SCRIPT="$1"

if [ ! -f "$SCRIPT" ]; then
    echo "dry-run-validate: not a file: $SCRIPT" >&2
    exit 1
fi

# Check 1: syntax
if ! bash -n "$SCRIPT"; then
    echo "FAIL: bash -n syntax error in $SCRIPT" >&2
    exit 1
fi
echo "OK: syntax check passed for $SCRIPT"

# Check 2: --help runs without error.
# The `if` guard keeps a non-zero exit from --help non-fatal (no set -e in
# play, but `if` makes that explicit). Most well-formed scripts that don't
# implement --help print to stderr and exit non-zero.
# Guard with `timeout` (Git Bash ships coreutils timeout) so a wrapper command
# that blocks (e.g. `npm run dev`) can't hang the validator. A timed-out run
# (exit 124) is non-zero and lands in the non-fatal NOTE branch. If `timeout`
# is unavailable, fall back to running the script directly.
if command -v timeout > /dev/null 2>&1; then
    timeout 10 bash "$SCRIPT" --help > /dev/null 2>&1
else
    bash "$SCRIPT" --help > /dev/null 2>&1
fi
if [ $? -eq 0 ]; then
    echo "OK: --help ran successfully"
else
    # Not necessarily fatal — many wrapper scripts don't implement --help.
    # Just record the observation; do not fail.
    echo "NOTE: --help did not exit 0 (acceptable for wrapper scripts)"
fi

# Check 3: if the script references a known tool, report whether it's on PATH.
# Per-tool (not combined), so a script that uses one missing tool gets a WARN
# even when a sibling tool happens to be installed (e.g. gradle present but
# mvn absent). `\bmvn\b` does not match `./mvnw`, so wrapper scripts are not
# mis-flagged.
for tool in pnpm npm yarn bun mvn gradle pytest; do
    if grep -qE "\b$tool\b" "$SCRIPT"; then
        if command -v "$tool" > /dev/null 2>&1; then
            echo "OK: $tool is on PATH"
        else
            echo "WARN: $tool not on PATH (script may fail at runtime)"
        fi
    fi
done

exit 0
