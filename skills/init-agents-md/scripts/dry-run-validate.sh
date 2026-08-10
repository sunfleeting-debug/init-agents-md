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
if bash "$SCRIPT" --help > /dev/null 2>&1; then
    echo "OK: --help ran successfully"
else
    # Not necessarily fatal — many wrapper scripts don't implement --help.
    # Just record the observation; do not fail.
    echo "NOTE: --help did not exit 0 (acceptable for wrapper scripts)"
fi

# Check 3: if script references a known tool (pnpm/npm/mvn/pytest), check it's on PATH
if grep -qE '\b(pnpm|npm|yarn|bun)\b' "$SCRIPT"; then
    for tool in pnpm npm yarn bun; do
        if grep -qE "\b$tool\b" "$SCRIPT"; then
            if command -v "$tool" > /dev/null 2>&1; then
                echo "OK: $tool is on PATH"
            else
                echo "WARN: $tool not on PATH (script may fail at runtime)"
            fi
        fi
    done
fi
if grep -qE '\b(mvn|gradle)\b' "$SCRIPT" && ! command -v mvn > /dev/null && ! command -v gradle > /dev/null; then
    echo "WARN: mvn/gradle not on PATH (script may fail at runtime)"
fi
if grep -qE '\bpytest\b' "$SCRIPT" && ! command -v pytest > /dev/null; then
    echo "WARN: pytest not on PATH (script may fail at runtime)"
fi

exit 0
