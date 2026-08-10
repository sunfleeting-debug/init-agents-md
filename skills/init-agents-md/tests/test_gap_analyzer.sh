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

# --- Negative cases (synthetic inputs; no fixture changes) ---
TMPD=$(mktemp -d)
trap 'rm -rf "$TMPD"' EXIT

# Fully-provisioned input: coverage=1, CI configured, pre-commit present, env present.
echo '{"type":"node","ciSystem":"github-actions","preCommitHooks":"husky","envFiles":[".env"]}' > "$TMPD/detect.json"
echo '{"coverage":1,"undocumented":[]}' > "$TMPD/api.json"
GAP2=$(bash "$DIR/scripts/gap-analyzer.sh" "$(cat "$TMPD/detect.json")" "$(cat "$TMPD/api.json")" "$TMPD")

assert_json_eq "$GAP2" '[.items[] | select(.kind == "docstring-coverage")] | length' "0" "docstring-coverage NOT flagged at full coverage"
assert_json_eq "$GAP2" '[.items[] | select(.kind == "ci-missing")] | length' "0" "ci-missing NOT flagged when CI configured"
assert_json_eq "$GAP2" '[.items[] | select(.kind == "pre-commit-missing")] | length' "0" "pre-commit-missing NOT flagged when husky present"
assert_json_eq "$GAP2" '[.items[] | select(.kind == "env-example")] | length' "0" "env-example NOT flagged when env file present"

# A .js logger in src/ plus build output (dist/) must not produce any items:
# pino.js is detected (no logger gap) and dist/logger.ts is pruned (build output).
mkdir -p "$TMPD/dist" "$TMPD/src/lib"
touch "$TMPD/dist/logger.ts" "$TMPD/src/lib/pino.js"
GAP3=$(bash "$DIR/scripts/gap-analyzer.sh" '{"type":"node","ciSystem":"github-actions","preCommitHooks":"husky","envFiles":[".env"]}' '{"coverage":1,"undocumented":[]}' "$TMPD")
assert_json_eq "$GAP3" '.items | length' "0" "no items when pino.js logger exists and dist/ is ignored"

# Empty scripts.test string must NOT trigger ci-missing.
GAP4=$(bash "$DIR/scripts/gap-analyzer.sh" '{"type":"node","ciSystem":"none","preCommitHooks":"husky","envFiles":[".env"],"scripts":{"test":""}}' '{"coverage":1,"undocumented":[]}' "$TMPD")
assert_json_eq "$GAP4" '[.items[] | select(.kind == "ci-missing")] | length' "0" "ci-missing NOT flagged when scripts.test is empty"
