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
