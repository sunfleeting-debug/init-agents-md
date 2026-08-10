#!/usr/bin/env bash
set -uo pipefail
source "$(dirname "$0")/helpers.sh"

DIR="$(cd "$(dirname "$0")/.." && pwd)"

# Node case
DETECT=$(bash "$DIR/scripts/detect-node.sh" "$(fix node-project)")
CMDS=$(bash "$DIR/scripts/extract-commands.sh" "$DETECT")
assert_json_eq "$CMDS" '.test'       "vitest run"   "node: test=vitest run"
assert_json_eq "$CMDS" '.build'      "next build"   "node: build=next build"
assert_json_eq "$CMDS" '.dev'        "next dev"     "node: dev=next dev"
assert_json_eq "$CMDS" '.lint'       "eslint ."     "node: lint=eslint ."
assert_json_eq "$CMDS" '.format'     "prettier --write ." "node: format=prettier"
assert_json_eq "$CMDS" '.typecheck'  "tsc --noEmit" "node: typecheck=tsc --noEmit"

# Python case
DETECT=$(bash "$DIR/scripts/detect-python.sh" "$(fix python-project)")
CMDS=$(bash "$DIR/scripts/extract-commands.sh" "$DETECT")
assert_json_eq "$CMDS" '.test'       "pytest"        "python: test=pytest"
assert_json_eq "$CMDS" '.lint'       "ruff check ."  "python: lint=ruff check ."
assert_json_eq "$CMDS" '.format'     "ruff format"   "python: format=ruff format"
assert_json_eq "$CMDS" '.typecheck'  "mypy"          "python: typecheck=mypy"

# Java case
DETECT=$(bash "$DIR/scripts/detect-java.sh" "$(fix java-project)")
CMDS=$(bash "$DIR/scripts/extract-commands.sh" "$DETECT")
assert_json_eq "$CMDS" '.test'       "mvn test"      "java: test=mvn test"
assert_json_eq "$CMDS" '.build'      "mvn package"   "java: build=mvn package"
