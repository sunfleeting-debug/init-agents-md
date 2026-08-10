#!/usr/bin/env bash
# Extract runnable commands from a detect.json document.
# Usage: extract-commands.sh <detect.json>
# Output: commands.json — only fields that have a real value
# Exit codes: 0 = extracted, 1 = unknown project type, 2 = usage error

set -uo pipefail

if [ $# -lt 1 ]; then
    echo "Usage: extract-commands.sh <detect.json>" >&2
    exit 2
fi

DETECT="$1"

TYPE=$(echo "$DETECT" | jq -r '.type')

case "$TYPE" in
    node)
        scripts=$(echo "$DETECT" | jq -r '.scripts // {}')
        jq -n \
            --argjson s "$scripts" \
            '{
                dev:        ($s.dev        // null),
                build:      ($s.build      // null),
                test:       ($s.test       // null),
                lint:       ($s.lint       // null),
                format:     ($s.format     // null),
                typecheck:  ($s.typecheck  // null),
                setup:      "install"
            } | with_entries(if .value == null then empty else . end)'
        ;;
    python)
        pkg=$(echo "$DETECT" | jq -r '.packageManager')
        jq -n \
            --arg testCmd "$(echo "$DETECT" | jq -r '.testCommand // "none"')" \
            --arg lintCmd "$(echo "$DETECT" | jq -r '.lintCommand // "none"')" \
            --arg fmtCmd  "$(echo "$DETECT" | jq -r '.formatCommand // "none"')" \
            --arg tcCmd   "$(echo "$DETECT" | jq -r '.typecheckCommand // "none"')" \
            --arg setup   "$pkg install" \
            '{
                dev:       "python -m <entry>",
                build:     "python -m build",
                test:      $testCmd,
                lint:      (if $lintCmd == "ruff" then "ruff check ." else $lintCmd end),
                format:    $fmtCmd,
                typecheck: $tcCmd,
                setup:     $setup
            } | with_entries(select(.value != "none"))'
        ;;
    java)
        bt=$(echo "$DETECT" | jq -r '.buildTool')
        jq -n \
            --arg bt "$bt" \
            --argjson detect "$DETECT" \
            '{
                dev:       ("mvn spring-boot:run"),
                build:     ($detect.buildCommand // "mvn package"),
                test:      ($detect.testCommand  // "mvn test"),
                lint:      ($detect.lintCommand  // null),
                format:    ($detect.formatCommand // null),
                typecheck: null,
                setup:     ($bt + " install")
            } | with_entries(if .value == null then empty else . end)'
        ;;
    *)
        echo "extract-commands.sh: unknown type $TYPE" >&2
        exit 1
        ;;
esac
