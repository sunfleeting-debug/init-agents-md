#!/usr/bin/env bash
set -uo pipefail
source "$(dirname "$0")/helpers.sh"

DIR="$(cd "$(dirname "$0")/.." && pwd)"
JSON=$(bash "$DIR/scripts/vendor-rules-scan.sh" "$(fix node-project)")

assert_json_eq "$JSON" '.files | length' "1"   "1 vendor rule file found"
assert_json_eq "$JSON" '.files[0].path' ".claude/CLAUDE.md" "found .claude/CLAUDE.md"
assert_json_eq "$JSON" '.files[0].tool' "claude-code"     "tool=claude-code"
assert_json_eq "$JSON" '.files[0].lines' "3"             "lines=3"
