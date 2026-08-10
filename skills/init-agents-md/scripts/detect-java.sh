#!/usr/bin/env bash
# Parse a Java project's pom.xml (or build.gradle fallback).
# Usage: detect-java.sh <project-dir>
# Output: JSON document
# Exit codes: 0 = parsed, 1 = no manifest or no python, 2 = usage error

set -uo pipefail

if [ $# -lt 1 ]; then
    echo "Usage: detect-java.sh <project-dir>" >&2
    exit 2
fi

# Windows (Git Bash / MSYS): normalize path to mixed form (E:/...) so native
# Python can open it. MSYS rewrites argument paths, not strings inside code.
if command -v cygpath > /dev/null 2>&1; then
    DIR=$(cygpath -m "$1")
else
    DIR="$1"
fi

POM="$DIR/pom.xml"
GRADLE="$DIR/build.gradle"
GRADLE_KTS="$DIR/build.gradle.kts"

if [ ! -f "$POM" ] && [ ! -f "$GRADLE" ] && [ ! -f "$GRADLE_KTS" ]; then
    echo "detect-java.sh: no Java manifest found in $DIR" >&2
    exit 1
fi

if [ -f "$POM" ]; then
    if ! command -v python3 > /dev/null && ! command -v python > /dev/null; then
        echo "detect-java.sh: python required for XML parsing" >&2
        exit 1
    fi
    PY=python3
    command -v python3 > /dev/null || PY=python

    # The manifest path is passed via env var (not interpolated into the
    # Python source) so quotes/backslashes in the path cannot break parsing.
    # On malformed XML the body degrades silently to the ${VAR:-default}
    # values used below, matching detect-python.sh's behavior.
    eval "$(POM_FILE="$POM" $PY -c "
import xml.etree.ElementTree as ET, json, shlex, os, sys
try:
    ns = {'m': 'http://maven.apache.org/POM/4.0.0'}
    root = ET.parse(os.environ['POM_FILE']).getroot()
    parent = root.find('m:parent', ns)
    java_version = root.findtext('m:properties/m:java.version', namespaces=ns, default='')
    sb_version = ''
    if parent is not None:
        pid = parent.findtext('m:artifactId', namespaces=ns, default='')
        if pid == 'spring-boot-starter-parent':
            sb_version = parent.findtext('m:version', namespaces=ns, default='')
    deps = [d.findtext('m:artifactId', namespaces=ns) for d in root.findall('m:dependencies/m:dependency', ns)]
    deps = [d for d in deps if d]
    framework = 'spring-boot' if sb_version else 'none'
    data = {
        'buildTool': 'maven',
        'javaVersion': java_version,
        'springBootVersion': sb_version,
        'framework': framework,
        'mainDeps': deps,
        'testCommand': 'mvn test',
        'buildCommand': 'mvn package',
        'lintCommand': 'none',
        'formatCommand': 'none',
        'jarPackaging': 'jar'
    }
    for k, v in data.items():
        if isinstance(v, list):
            v = json.dumps(v)
        print(f'{k.upper()}={shlex.quote(str(v))}')
except Exception as e:
    print('', file=sys.stderr)
")"
else
    # Gradle fallback (minimal — only basic schema)
    GRADLE_FILE="$GRADLE"
    [ -f "$GRADLE_KTS" ] && GRADLE_FILE="$GRADLE_KTS"
    BUILDTOOL="gradle"
    JAVA_VERSION=$(grep -oP 'JavaVersion\.VERSION_\K\d+' "$GRADLE_FILE" 2>/dev/null | head -1)
    [ -z "$JAVA_VERSION" ] && JAVA_VERSION=$(grep -oP 'sourceCompatibility\s*=\s*[\"\x27]?\K\d+' "$GRADLE_FILE" 2>/dev/null | head -1)
    TESTCOMMAND="gradle test"
    BUILDCOMMAND="gradle build"
fi

# --- ciSystem / preCommitHooks / dockerSupport / envFiles ---
ciSystem="none"
[ -d "$DIR/.github/workflows" ] && ciSystem="github-actions"

preCommitHooks="none"
[ -d "$DIR/.husky" ] && preCommitHooks="husky"

dockerSupport="false"
[ -f "$DIR/Dockerfile" ] && dockerSupport="true"

# jq -s emits '[]' when the glob matches nothing, so no fallback is needed.
envFiles=$(ls "$DIR"/.env* 2>/dev/null | sed "s|^$DIR/||" | jq -R . | jq -s '.')

# --- Final JSON (Maven path uses variables from python; Gradle path uses defaults) ---
if [ -f "$POM" ]; then
    jq -n \
        --arg type "java" \
        --arg buildTool "${BUILDTOOL:-maven}" \
        --arg javaVersion "${JAVAVERSION:-}" \
        --arg framework "${FRAMEWORK:-none}" \
        --arg springBootVersion "${SPRINGBOOTVERSION:-}" \
        --arg testCommand "${TESTCOMMAND:-mvn test}" \
        --arg buildCommand "${BUILDCOMMAND:-mvn package}" \
        --arg lintCommand "${LINTCOMMAND:-none}" \
        --arg formatCommand "${FORMATCOMMAND:-none}" \
        --arg jarPackaging "${JARPACKAGING:-jar}" \
        --argjson mainDeps "${MAINDEPS:-[]}" \
        --arg ciSystem "$ciSystem" \
        --arg preCommitHooks "$preCommitHooks" \
        --arg dockerSupport "$dockerSupport" \
        --argjson envFiles "$envFiles" \
        '{
            type: $type,
            buildTool: $buildTool,
            javaVersion: $javaVersion,
            framework: $framework,
            springBootVersion: (if $springBootVersion == "" then null else $springBootVersion end),
            testCommand: $testCommand,
            buildCommand: $buildCommand,
            lintCommand: $lintCommand,
            formatCommand: $formatCommand,
            jarPackaging: $jarPackaging,
            mainDeps: $mainDeps,
            ciSystem: $ciSystem,
            preCommitHooks: $preCommitHooks,
            dockerSupport: ($dockerSupport == "true"),
            envFiles: $envFiles
        }'
else
    jq -n \
        --arg type "java" \
        --arg buildTool "$BUILDTOOL" \
        --arg javaVersion "$JAVA_VERSION" \
        --arg framework "none" \
        --arg springBootVersion "" \
        --arg testCommand "$TESTCOMMAND" \
        --arg buildCommand "$BUILDCOMMAND" \
        --arg lintCommand "none" \
        --arg formatCommand "none" \
        --arg jarPackaging "jar" \
        --argjson mainDeps '[]' \
        --arg ciSystem "$ciSystem" \
        --arg preCommitHooks "$preCommitHooks" \
        --arg dockerSupport "$dockerSupport" \
        --argjson envFiles "$envFiles" \
        '{
            type: $type,
            buildTool: $buildTool,
            javaVersion: $javaVersion,
            framework: $framework,
            springBootVersion: null,
            testCommand: $testCommand,
            buildCommand: $buildCommand,
            lintCommand: $lintCommand,
            formatCommand: $formatCommand,
            jarPackaging: $jarPackaging,
            mainDeps: $mainDeps,
            ciSystem: $ciSystem,
            preCommitHooks: $preCommitHooks,
            dockerSupport: ($dockerSupport == "true"),
            envFiles: $envFiles
        }'
fi
