#!/usr/bin/env bash
set -uo pipefail
source "$(dirname "$0")/helpers.sh"

DIR="$(cd "$(dirname "$0")/.." && pwd)"
JSON=$(bash "$DIR/scripts/public-api-scan.sh" "$(fix node-project)")

# 2 public exports (add, multiply); 1 undocumented (add)
assert_json_eq "$JSON" '.language'        "typescript" "language=typescript"
assert_json_eq "$JSON" '.publicSymbols | length' "2"  "2 public symbols"
assert_json_eq "$JSON" '.undocumented | length'  "1"  "1 undocumented"
assert_json_eq "$JSON" '.undocumented[0].name'   "add" "undocumented[0]=add"
assert_json_eq "$JSON" '.coverage'        "0.5"        "coverage=0.5"
