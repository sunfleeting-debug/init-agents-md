#!/usr/bin/env bash
# Analyze a project for missing quality infrastructure.
# Usage: gap-analyzer.sh <detect.json> <public-api.json> <project-dir>
# Output: JSON { items: [{kind, severity, message, suggestion}] }
#
# Each item has:
#   kind       — short identifier
#   severity   — "info" | "warning"
#   message    — human-readable description
#   suggestion — what would be added if user approves

set -uo pipefail

if [ $# -lt 3 ]; then
    echo "Usage: gap-analyzer.sh <detect.json> <public-api.json> <project-dir>" >&2
    exit 2
fi

DETECT="$1"
PUBLIC_API="$2"
DIR="$3"

items="[]"

add_item() {
    local kind="$1" severity="$2" message="$3" suggestion="$4"
    local entry
    entry=$(jq -n --arg k "$kind" --arg s "$severity" --arg m "$message" --arg sug "$suggestion" \
        '{kind: $k, severity: $s, message: $m, suggestion: $sug}')
    items=$(echo "$items" | jq --argjson e "$entry" '. + [$e]')
}

# --- logger missing ---
PTYPE=$(echo "$DETECT" | jq -r '.type')
case "$PTYPE" in
    node)
        # Match .js loggers too (JS projects use pino.js/winston.js), and prune
        # build output so dist/logger.ts or .next/logger.js can't suppress the gap.
        if ! find "$DIR" -path '*/node_modules' -prune -o -path '*/dist' -prune -o -path '*/.next' -prune -o -type f \( -name 'logger.ts' -o -name 'logger.js' -o -name 'pino*.ts' -o -name 'pino*.js' -o -name 'winston*.ts' -o -name 'winston*.js' \) -print 2>/dev/null | grep -q .; then
            add_item "logger" "info" "未检测到统一 logger 模块" "生成 src/lib/logger.ts (pino)"
        fi
        ;;
    python)
        if ! find "$DIR" -path '*/.venv' -prune -o -type f -name 'logging*.py' -print 2>/dev/null | grep -q .; then
            add_item "logger" "info" "未检测到统一 logging 模块" "生成 src/logging.py (stdlib logging)"
        fi
        ;;
    java)
        if ! find "$DIR" -type f -name 'LogConfig*.java' 2>/dev/null | grep -q .; then
            add_item "logger" "info" "未检测到统一 LogConfig 类" "生成 src/main/java/.../LogConfig.java (SLF4J)"
        fi
        ;;
esac

# --- docstring coverage ---
coverage=$(echo "$PUBLIC_API" | jq -r '.coverage // 1.0')
undoc=$(echo "$PUBLIC_API" | jq -r '.undocumented | length // 0')
# The // 1.0 fallback already covers null/missing coverage, so the awk float
# comparison below is the sole gate (a literal "1.00" string never reaches here).
if awk -v c="$coverage" 'BEGIN { exit !(c < 0.8) }'; then
    pct=$(awk -v c="$coverage" 'BEGIN { printf "%.0f%%", c*100 }')
    add_item "docstring-coverage" "info" \
        "公开 API 注释覆盖率 $pct,未注释数 $undoc" \
        "补全公开 API 的 JSDoc / docstring / Javadoc"
fi

# --- CI missing ---
ci=$(echo "$DETECT" | jq -r '.ciSystem')
if [ "$ci" = "none" ]; then
    has_test=$(echo "$DETECT" | jq -r '.testCommand // .scripts.test // "none"')
    # -n guards the empty-string case: jq's // keeps "" (only null/null values are
    # replaced), so scripts.test:"" would otherwise slip past the != checks.
    if [ -n "$has_test" ] && [ "$has_test" != "none" ] && [ "$has_test" != "null" ]; then
        add_item "ci-missing" "warning" "项目有测试但无 CI 配置" "添加 .github/workflows/ci.yml 运行 lint+test"
    fi
fi

# --- pre-commit hooks missing ---
hooks=$(echo "$DETECT" | jq -r '.preCommitHooks')
if [ "$hooks" = "none" ]; then
    add_item "pre-commit-missing" "info" "未配置 pre-commit hooks" "添加 husky + lint-staged"
fi

# --- env example missing ---
env_files=$(echo "$DETECT" | jq -r '.envFiles | length')
if [ "$env_files" = "0" ]; then
    add_item "env-example" "info" "未发现 .env.example 文件" "扫描代码后生成 .env.example 模板"
fi

# --- Output ---
jq -n --argjson items "$items" '{items: $items}'
