#!/usr/bin/env bash
set -uo pipefail
source "$(dirname "$0")/helpers.sh"

DIR="$(cd "$(dirname "$0")/.." && pwd)"
JSON=$(bash "$DIR/scripts/detect-python.sh" "$(fix python-project)")

assert_json_eq "$JSON" '.type'                  "python"    "type=python"
assert_json_eq "$JSON" '.packageManager'        "poetry"    "packageManager=poetry"
assert_json_eq "$JSON" '.pythonVersion'         "3.11"      "pythonVersion=3.11"
assert_json_eq "$JSON" '.framework'             "fastapi"   "framework=fastapi"
assert_json_eq "$JSON" '.testCommand'           "pytest"    "testCommand=pytest"
assert_json_eq "$JSON" '.lintCommand'           "ruff"      "lintCommand=ruff"
assert_json_eq "$JSON" '.formatCommand'         "ruff format" "formatCommand=ruff format"
assert_json_eq "$JSON" '.typecheckCommand'      "mypy"      "typecheckCommand=mypy"
assert_json_eq "$JSON" '.virtualEnv'            "poetry"    "virtualEnv=poetry"
assert_json_eq "$JSON" '.ciSystem'              "none"      "ciSystem=none"
