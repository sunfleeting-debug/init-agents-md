#!/usr/bin/env bash
# Identify project type from manifest files in a directory.
# Usage: detect.sh <project-dir>
# Output: "node" | "python" | "java" | "unknown"

set -uo pipefail

if [ $# -lt 1 ]; then
    echo "Usage: detect.sh <project-dir>" >&2
    exit 2
fi

DIR="$1"

if [ -f "$DIR/package.json" ]; then
    echo "node"
    exit 0
fi

if [ -f "$DIR/pyproject.toml" ] || [ -f "$DIR/setup.py" ] || [ -f "$DIR/requirements.txt" ]; then
    echo "python"
    exit 0
fi

if [ -f "$DIR/pom.xml" ] || [ -f "$DIR/build.gradle" ] || [ -f "$DIR/build.gradle.kts" ]; then
    echo "java"
    exit 0
fi

echo "unknown"
exit 1
