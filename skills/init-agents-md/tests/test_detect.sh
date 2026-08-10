#!/usr/bin/env bash
set -uo pipefail
source "$(dirname "$0")/helpers.sh"

DIR="$(cd "$(dirname "$0")/.." && pwd)"

result=$("$DIR/scripts/detect.sh" "$(fix node-project)")
assert_eq "$result" "node" "node-project → node"

result=$("$DIR/scripts/detect.sh" "$(fix python-project)")
assert_eq "$result" "python" "python-project → python"

result=$("$DIR/scripts/detect.sh" "$(fix java-project)")
assert_eq "$result" "java" "java-project → java"

# Missing arg should emit usage and fail
if "$DIR/scripts/detect.sh" 2>/dev/null; then
    fail "detect.sh with no arg should exit non-zero"
else
    pass "detect.sh with no arg exits non-zero"
fi
