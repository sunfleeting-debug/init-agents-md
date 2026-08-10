#!/usr/bin/env bash
# Test helpers — assertion functions for bash tests.
# Source this from each test_*.sh:  source "$(dirname "$0")/helpers.sh"

# Color output if stdout is a tty
if [ -t 1 ]; then
    _RED='\033[0;31m'; _GRN='\033[0;32m'; _RST='\033[0m'
else
    _RED=''; _GRN=''; _RST=''
fi

pass() { echo -e "${_GRN}PASS${_RST}: $1"; }
fail() { echo -e "${_RED}FAIL${_RST}: $1" >&2; exit 1; }

assert_eq() {
    # assert_eq <actual> <expected> <label>
    if [ "$1" = "$2" ]; then
        pass "$3"
    else
        fail "$3 — expected: [$2] got: [$1]"
    fi
}

assert_contains() {
    # assert_contains <haystack> <needle> <label>
    if echo "$1" | grep -qF -- "$2"; then
        pass "$3"
    else
        fail "$3 — expected to contain: [$2]"
    fi
}

assert_file_exists() {
    if [ -f "$1" ]; then
        pass "$2"
    else
        fail "$2 — file not found: $1"
    fi
}

assert_json_eq() {
    # assert_json_eq <json-string> <jq-filter> <expected> <label>
    command -v jq >/dev/null 2>&1 || { echo "jq required" >&2; exit 1; }
    local actual
    actual=$(echo "$1" | jq -r "$2")
    assert_eq "$actual" "$3" "$4"
}

# Resolve a fixture path. Usage: fix "node-project" "package.json"
fix() {
    echo "${BASH_SOURCE[0]%/*}/fixtures/$1/$2"
}
