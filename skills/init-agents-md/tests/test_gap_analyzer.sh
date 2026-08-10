#!/usr/bin/env bash
set -uo pipefail
source "$(dirname "$0")/helpers.sh"

DIR="$(cd "$(dirname "$0")/.." && pwd)"

# Node fixture: has tests, lint, format — but no logger; CI=none; no pre-commit; no env file.
# Should propose: docstring-coverage (0.5 < 0.8), ci-missing (test command exists
# but no CI config), pre-commit-missing, env-example, logger (no logger module found).
DETECT=$(bash "$DIR/scripts/detect-node.sh" "$(fix node-project)")
PUBLIC_API=$(bash "$DIR/scripts/public-api-scan.sh" "$(fix node-project)")
GAP=$(bash "$DIR/scripts/gap-analyzer.sh" "$DETECT" "$PUBLIC_API" "$(fix node-project)")

item_count=$(echo "$GAP" | jq '.items | length')
[ "$item_count" -ge 1 ] && pass "at least 1 gap item" || fail "expected >=1 gap items, got $item_count"

# Coverage < 0.8 should trigger docstring item
docstring_item=$(echo "$GAP" | jq '[.items[] | select(.kind == "docstring-coverage")] | length')
assert_eq "$docstring_item" "1" "docstring-coverage gap is flagged"
