#!/usr/bin/env bash
set -uo pipefail
source "$(dirname "$0")/helpers.sh"

DIR="$(cd "$(dirname "$0")/.." && pwd)"
JSON=$(bash "$DIR/scripts/detect-node.sh" "$(fix node-project)")

assert_json_eq "$JSON" '.type'               "node"            "type=node"
assert_json_eq "$JSON" '.packageManager'     "pnpm"            "packageManager=pnpm"
assert_json_eq "$JSON" '.language'           "javascript"      "language=javascript (no tsconfig in fixture)"
assert_json_eq "$JSON" '.framework'          "next"            "framework=next"
assert_json_eq "$JSON" '.testFramework'      "vitest"          "testFramework=vitest"
assert_json_eq "$JSON" '.linter'             "eslint"          "linter=eslint"
assert_json_eq "$JSON" '.formatter'          "prettier"        "formatter=prettier"
assert_json_eq "$JSON" '.scripts.test'       "vitest run"      "scripts.test=vitest run"
assert_json_eq "$JSON" '.scripts.dev'        "next dev"        "scripts.dev=next dev"
assert_json_eq "$JSON" '.mainDeps | length'  "2"               "mainDeps has 2 entries"
assert_json_eq "$JSON" '.ciSystem'           "none"            "ciSystem=none (no .github/workflows)"
assert_json_eq "$JSON" '.dockerSupport'      "false"           "dockerSupport=false"
