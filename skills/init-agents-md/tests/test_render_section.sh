#!/usr/bin/env bash
set -uo pipefail
source "$(dirname "$0")/helpers.sh"

DIR="$(cd "$(dirname "$0")/.." && pwd)"
TMPL="$DIR/templates/sections/02-tech-stack.md"

DATA='{"language":"typescript","packageManager":"pnpm","framework":"next","testFramework":"vitest","linter":"eslint"}'

OUT=$(bash "$DIR/scripts/render-section.sh" "$TMPL" "$DATA")

assert_contains "$OUT" "语言: typescript"  "language substituted"
assert_contains "$OUT" "包管理器: pnpm"    "packageManager substituted"
assert_contains "$OUT" "框架: next"         "framework substituted"
assert_contains "$OUT" "测试: vitest"       "testFramework substituted"
assert_contains "$OUT" "Lint: eslint"       "linter substituted"

# Process substitution data path (Task 20 integration key path)
OUT=$(bash "$DIR/scripts/render-section.sh" "$TMPL" <(echo "$DATA"))
assert_contains "$OUT" "语言: typescript"  "process substitution data accepted"

# Non-object JSON (array) must exit 1 with a clean error, not a traceback
ERR=$(bash "$DIR/scripts/render-section.sh" "$TMPL" '["a","b"]' 2>&1 > /dev/null)
rc=$?
assert_eq "$rc" "1" "non-object JSON rejected (exit 1)"
assert_contains "$ERR" "JSON object" "non-object JSON: clean error message"

# Unknown key preserved: tokens missing from data stay in the output
OUT=$(bash "$DIR/scripts/render-section.sh" "$TMPL" '{"language":"typescript"}' 2>/dev/null)
assert_contains "$OUT" "{{packageManager}}" "unknown key placeholder preserved"
