#!/usr/bin/env bash
# Scan a project's public API surface and report docstring coverage.
# Usage: public-api-scan.sh <project-dir>
# Output: JSON with publicSymbols, undocumented, coverage

set -uo pipefail

if [ $# -lt 1 ]; then
    echo "Usage: public-api-scan.sh <project-dir>" >&2
    exit 2
fi

DIR="$1"
PTYPE=$(bash "$(dirname "$0")/detect.sh" "$DIR")

case "$PTYPE" in
    node)
        # Look at .ts/.js files; collect "export function NAME" / "export class NAME" / "export const NAME"
        symbols_file=$(mktemp)
        undoc_file=$(mktemp)
        trap "rm -f $symbols_file $undoc_file" EXIT

        while IFS= read -r f; do
            grep -nE '^export (async )?(function|class|const|let|var) [A-Za-z_][A-Za-z0-9_]*' "$f" 2>/dev/null \
                | sed -E "s#^([0-9]+):export (async )?(function|class|const|let|var) ([A-Za-z_][A-Za-z0-9_]*).*#\4 ${f}#"
        done < <(find "$DIR/src" "$DIR/lib" 2>/dev/null -type f \( -name '*.ts' -o -name '*.tsx' -o -name '*.js' -o -name '*.jsx' \) ! -path '*/node_modules/*') > "$symbols_file"

        total=0
        > "$undoc_file"

        while IFS= read -r line; do
            [ -z "$line" ] && continue
            name=$(echo "$line" | awk '{print $1}')
            file=$(echo "$line" | awk '{print $2}')
            lineno=$(grep -nE "^export (async )?(function|class|const|let|var) $name" "$file" | head -1 | cut -d: -f1)
            [ -z "$lineno" ] && continue

            # Check if any of the 5 preceding lines contain a doc comment (/** or */)
            prev_start=$((lineno - 5))
            [ "$prev_start" -lt 1 ] && prev_start=1
            if sed -n "${prev_start},$((lineno-1))p" "$file" | grep -qE '/\*\*|\*/'; then
                :  # documented
            else
                echo "$name|$file|$lineno" >> "$undoc_file"
            fi
            total=$((total + 1))
        done < "$symbols_file"

        undoc_count=$(wc -l < "$undoc_file" | tr -d ' ')
        if [ "$total" -gt 0 ]; then
            coverage=$(awk -v d="$undoc_count" -v t="$total" 'BEGIN { printf "%.2f", (t-d)/t }')
        else
            coverage="1.00"
        fi

        undoc_json="[]"
        if [ "$undoc_count" -gt 0 ]; then
            undoc_json=$(jq -Rn '[inputs | select(length > 0) | split("|") | {name: .[0], file: .[1], line: (.[2] | tonumber)}]' "$undoc_file")
        fi

        jq -n \
            --arg language "typescript" \
            --argjson total "$total" \
            --argjson undoc "$undoc_count" \
            --arg coverage "$coverage" \
            --argjson undocumented "$undoc_json" \
            '{
                language: $language,
                publicSymbols: $total,
                undocumented: $undocumented,
                coverage: ($coverage | tonumber | . + 0)
            }'
        ;;
    python)
        # Simple grep: lines like "def name(" or "class name" at column 0 (public).
        # Public = not prefixed with _.
        symbols_file=$(mktemp)
        undoc_file=$(mktemp)
        trap "rm -f $symbols_file $undoc_file" EXIT
        while IFS= read -r f; do
            grep -nE '^(def|class) [A-Za-z]' "$f" 2>/dev/null | while IFS=: read -r lineno content; do
                name=$(echo "$content" | sed -E 's/^(def|class) ([A-Za-z_][A-Za-z0-9_]*).*/\2/')
                if [[ ! "$name" =~ ^_ ]]; then
                    echo "$name|$f|$lineno"
                fi
            done
        done < <(find "$DIR" -type f -name '*.py' ! -path '*/.venv/*' ! -path '*/__pycache__/*' ! -path '*/node_modules/*') > "$symbols_file"

        total=$(wc -l < "$symbols_file" | tr -d ' ')
        > "$undoc_file"
        while IFS='|' read -r name file lineno; do
            [ -z "$name" ] && continue
            prev_start=$((lineno - 3))
            [ "$prev_start" -lt 1 ] && prev_start=1
            if sed -n "${prev_start},$((lineno-1))p" "$file" | grep -qE '"""'; then
                :
            else
                echo "$name|$file|$lineno" >> "$undoc_file"
            fi
        done < "$symbols_file"

        undoc_count=$(wc -l < "$undoc_file" | tr -d ' ')
        if [ "$total" -gt 0 ]; then
            coverage=$(awk -v d="$undoc_count" -v t="$total" 'BEGIN { printf "%.2f", (t-d)/t }')
        else
            coverage="1.00"
        fi
        undoc_json="[]"
        if [ "$undoc_count" -gt 0 ]; then
            undoc_json=$(jq -Rn '[inputs | select(length > 0) | split("|") | {name: .[0], file: .[1], line: (.[2] | tonumber)}]' "$undoc_file")
        fi
        jq -n \
            --arg language "python" \
            --argjson total "$total" \
            --argjson undoc "$undoc_count" \
            --arg coverage "$coverage" \
            --argjson undocumented "$undoc_json" \
            '{
                language: $language,
                publicSymbols: $total,
                undocumented: $undocumented,
                coverage: ($coverage | tonumber | . + 0)
            }'
        ;;
    java)
        # Simplified: scan for "public class NAME" or "public TYPE NAME("
        # Not exhaustively tested in fixtures; basic schema is enough for v1.
        total=0
        undoc_count=0
        coverage="1.00"
        undoc_json="[]"
        while IFS= read -r f; do
            while IFS=: read -r lineno content; do
                if echo "$content" | grep -qE '^public (class|[A-Za-z<>]+ [A-Za-z_][A-Za-z0-9_]*\()'; then
                    total=$((total + 1))
                    prev_start=$((lineno - 5))
                    [ "$prev_start" -lt 1 ] && prev_start=1
                    if ! sed -n "${prev_start},$((lineno-1))p" "$f" | grep -qE '/\*\*'; then
                        undoc_count=$((undoc_count + 1))
                    fi
                fi
            done < <(grep -nE '^public ' "$f")
        done < <(find "$DIR/src" -type f -name '*.java' 2>/dev/null)

        if [ "$total" -gt 0 ]; then
            coverage=$(awk -v d="$undoc_count" -v t="$total" 'BEGIN { printf "%.2f", (t-d)/t }')
        fi
        jq -n \
            --arg language "java" \
            --argjson total "$total" \
            --argjson undoc "$undoc_count" \
            --arg coverage "$coverage" \
            --argjson undocumented "$undoc_json" \
            '{
                language: $language,
                publicSymbols: $total,
                undocumented: $undocumented,
                coverage: ($coverage | tonumber | . + 0)
            }'
        ;;
    *)
        jq -n '{language: null, publicSymbols: 0, undocumented: [], coverage: 1.00}'
        ;;
esac
