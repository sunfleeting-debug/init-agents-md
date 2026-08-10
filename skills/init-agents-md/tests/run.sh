#!/usr/bin/env bash
# Run all test_*.sh files. Exits non-zero if any test fails.
set -uo pipefail

# Expand unmatched globs to nothing instead of passing the literal pattern.
shopt -s nullglob

DIR="$(cd "$(dirname "$0")" && pwd)"
FAIL=0

for t in "$DIR"/test_*.sh; do
    echo "=== $(basename "$t") ==="
    if ! bash "$t"; then
        echo "FAILED: $t" >&2
        FAIL=1
    fi
done

exit $FAIL
