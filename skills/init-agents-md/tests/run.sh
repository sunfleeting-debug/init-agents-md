#!/usr/bin/env bash
# Run all test_*.sh files. Exits non-zero on first failure.
set -uo pipefail

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
