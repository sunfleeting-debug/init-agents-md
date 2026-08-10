#!/usr/bin/env bash
# Find known vendor-specific rule files in a project.
# Usage: vendor-rules-scan.sh <project-dir>
# Output: JSON listing paths and tools.
# IMPORTANT: This script reads paths only. It does NOT read or modify file contents.
# Exit codes: 0 = scanned, 2 = usage error

set -uo pipefail

if [ $# -lt 1 ]; then
    echo "Usage: vendor-rules-scan.sh <project-dir>" >&2
    exit 2
fi

DIR="$1"

# Each entry: <path>:<tool-name>
KNOWN=(
    ".claude/CLAUDE.md:claude-code"
    "CLAUDE.md:claude-code"
    ".cursorrules:cursor"
    ".cursor/rules:cursor"
    ".clinerules:cline"
    ".windsurfrules:windsurf"
    ".aider.conf.yml:aider"
    ".github/copilot-instructions.md:github-copilot"
    "AGENTS.md:agents.md-spec"
    "GEMINI.md:gemini-cli"
)

found="[]"
for entry in "${KNOWN[@]}"; do
    path="${entry%%:*}"
    tool="${entry##*:}"
    if [ -f "$DIR/$path" ]; then
        # Get line count
        lines=$(wc -l < "$DIR/$path" | tr -d ' ')
        entry_json=$(jq -n --arg p "$path" --arg t "$tool" --arg l "$lines" '{path: $p, tool: $t, lines: ($l | tonumber)}')
        found=$(echo "$found" | jq --argjson e "$entry_json" '. + [$e]')
    fi
done

jq -n --argjson files "$found" '{files: $files}'
