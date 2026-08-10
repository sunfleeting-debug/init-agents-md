#!/usr/bin/env bash
set -uo pipefail
source "$(dirname "$0")/helpers.sh"

DIR="$(cd "$(dirname "$0")/.." && pwd)"
JSON=$(bash "$DIR/scripts/detect-java.sh" "$(fix java-project)")

assert_json_eq "$JSON" '.type'              "java"            "type=java"
assert_json_eq "$JSON" '.buildTool'         "maven"           "buildTool=maven"
assert_json_eq "$JSON" '.javaVersion'       "17"              "javaVersion=17"
assert_json_eq "$JSON" '.framework'         "spring-boot"     "framework=spring-boot"
assert_json_eq "$JSON" '.springBootVersion' "3.3.0"           "springBootVersion=3.3.0"
assert_json_eq "$JSON" '.testCommand'       "mvn test"        "testCommand=mvn test"
assert_json_eq "$JSON" '.buildCommand'      "mvn package"     "buildCommand=mvn package"
assert_json_eq "$JSON" '.jarPackaging'      "jar"             "jarPackaging=jar"
assert_json_eq "$JSON" '.mainDeps | length' "1"               "mainDeps has 1 entry"
