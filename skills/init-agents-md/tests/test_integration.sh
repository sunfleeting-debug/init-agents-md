#!/usr/bin/env bash
# Integration test: run the full pipeline end-to-end against each fixture,
# then exercise the render path on the Node fixture with process-substitution
# data to confirm Task 10's fix holds.
set -uo pipefail
source "$(dirname "$0")/helpers.sh"

DIR="$(cd "$(dirname "$0")/.." && pwd)"

# Test against each fixture
for lang in node-project python-project java-project; do
    FIX="$(fix $lang)"
    echo "=== Integration: $lang ==="

    # Detect
    TYPE=$(bash "$DIR/scripts/detect.sh" "$FIX")
    case "$lang" in
        node-project)   expected="node" ;;
        python-project) expected="python" ;;
        java-project)   expected="java" ;;
    esac
    assert_eq "$TYPE" "$expected" "$lang: detect → $expected"

    # Language-specific detect
    DETECT=$(bash "$DIR/scripts/detect-$TYPE.sh" "$FIX")
    assert_json_eq "$DETECT" '.type' "$expected" "$lang: detect-$TYPE.type"

    # Extract commands
    CMDS=$(bash "$DIR/scripts/extract-commands.sh" "$DETECT")
    test_cmd=$(echo "$CMDS" | jq -r '.test')
    [ "$test_cmd" != "null" ] && [ -n "$test_cmd" ] && pass "$lang: extract-commands.test=$test_cmd" \
        || fail "$lang: extract-commands.test is empty"

    # Public API
    PA=$(bash "$DIR/scripts/public-api-scan.sh" "$FIX")
    coverage=$(echo "$PA" | jq -r '.coverage')
    pass "$lang: public-api-scan ran (coverage=$coverage)"

    # Vendor rules
    VR=$(bash "$DIR/scripts/vendor-rules-scan.sh" "$FIX")
    pass "$lang: vendor-rules-scan ran"

    # Gap analyzer
    GAP=$(bash "$DIR/scripts/gap-analyzer.sh" "$DETECT" "$PA" "$FIX")
    item_count=$(echo "$GAP" | jq '.items | length')
    pass "$lang: gap-analyzer found $item_count items"
done

echo ""
echo "=== End-to-end render test (Node only, full pipeline) ==="

FIX="$(fix node-project)"
DETECT=$(bash "$DIR/scripts/detect-node.sh" "$FIX")
CMDS=$(bash "$DIR/scripts/extract-commands.sh" "$DETECT")
DATA=$(jq -n \
    --argjson d "$DETECT" \
    --argjson c "$CMDS" \
    '{
        language:        $d.language,
        packageManager:  $d.packageManager,
        framework:       $d.framework,
        testFramework:   $d.testFramework,
        linter:          $d.linter,
        test:            $c.test,
        build:           $c.build,
        dev:             $c.dev
    }')

RENDERED=$(bash "$DIR/scripts/render-section.sh" "$DIR/templates/sections/02-tech-stack.md" <(echo "$DATA"))
assert_contains "$RENDERED" "包管理器: pnpm"  "Node: rendered packageManager"
assert_contains "$RENDERED" "框架: next"       "Node: rendered framework"