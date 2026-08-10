#!/usr/bin/env bash
# Parse a Python project's pyproject.toml (and fallback manifests).
# Usage: detect-python.sh <project-dir>
# Output: JSON document
# Exit codes: 0 = parsed, 1 = no manifest or no python, 2 = usage error

set -uo pipefail

if [ $# -lt 1 ]; then
    echo "Usage: detect-python.sh <project-dir>" >&2
    exit 2
fi

# Windows bash may pass MSYS (/e/...) or backslash (E:\...) paths that the
# inline Python below cannot open (MSYS only rewrites argument paths, not
# strings); cygpath -m normalizes both to E:/... mixed mode. On POSIX
# cygpath is absent, so DIR is used as passed (already /-separated).
if command -v cygpath > /dev/null 2>&1; then
    DIR=$(cygpath -m "$1")
else
    DIR="$1"
fi

if ! command -v python3 > /dev/null && ! command -v python > /dev/null; then
    echo "detect-python.sh: python not found on PATH" >&2
    exit 1
fi
PY=python3
command -v python3 > /dev/null || PY=python

# Locate a manifest to parse
PYPROJECT="$DIR/pyproject.toml"
SETUP_PY="$DIR/setup.py"
REQUIREMENTS="$DIR/requirements.txt"

if [ ! -f "$PYPROJECT" ] && [ ! -f "$SETUP_PY" ] && [ ! -f "$REQUIREMENTS" ]; then
    echo "detect-python.sh: no Python manifest found in $DIR" >&2
    exit 1
fi

# --- Python version (from pyproject) ---
pythonVersion=""
if [ -f "$PYPROJECT" ]; then
    pythonVersion=$($PY -c "
import sys, json
try:
    import tomllib
    with open('$PYPROJECT', 'rb') as f:
        d = tomllib.load(f)
    pv = d.get('project', {}).get('requires-python', '')
    # extract major.minor
    import re
    m = re.search(r'(\d+\.\d+)', pv)
    print(m.group(1) if m else '')
except Exception as e:
    print('', file=sys.stderr)
")
fi

# --- packageManager ---
packageManager="none"
if [ -f "$DIR/uv.lock" ] || grep -q '\[tool.uv\]' "$PYPROJECT" 2>/dev/null; then
    packageManager="uv"
elif [ -f "$DIR/poetry.lock" ] || grep -q '\[tool.poetry\]' "$PYPROJECT" 2>/dev/null; then
    packageManager="poetry"
elif [ -f "$DIR/Pipfile" ]; then
    packageManager="pipenv"
elif [ -f "$REQUIREMENTS" ]; then
    packageManager="pip"
fi

# --- framework (heuristic from dependencies) ---
framework="none"
for fw in fastapi django flask starlette aiohttp tornado; do
    if grep -q "\"$fw" "$PYPROJECT" 2>/dev/null || grep -q "^$fw" "$REQUIREMENTS" 2>/dev/null; then
        framework="$fw"; break
    fi
done

# --- commands (heuristic from tool sections) ---
testCommand="none"
grep -q '\[tool.pytest' "$PYPROJECT" 2>/dev/null && testCommand="pytest"

lintCommand="none"
grep -q '\[tool.ruff\]' "$PYPROJECT" 2>/dev/null && lintCommand="ruff"

formatCommand="none"
grep -q '\[tool.ruff\]' "$PYPROJECT" 2>/dev/null && formatCommand="ruff format"

typecheckCommand="none"
grep -q '\[tool.mypy\]' "$PYPROJECT" 2>/dev/null && typecheckCommand="mypy"
grep -q '\[tool.pyright\]' "$PYPROJECT" 2>/dev/null && typecheckCommand="pyright"

# --- virtualEnv (matches packageManager by default) ---
virtualEnv="$packageManager"
[ "$virtualEnv" = "none" ] && virtualEnv="venv"

# --- dbMigrations ---
dbMigrations="none"
grep -q '\[tool.alembic\]' "$PYPROJECT" 2>/dev/null && dbMigrations="alembic"
grep -q 'django' "$PYPROJECT" 2>/dev/null && dbMigrations="django"

# --- mainDeps ---
mainDeps="[]"
if [ -f "$PYPROJECT" ]; then
    mainDeps=$($PY -c "
import json, tomllib
with open('$PYPROJECT', 'rb') as f:
    d = tomllib.load(f)
deps = d.get('project', {}).get('dependencies', [])
import re
names = []
for dep in deps:
    m = re.match(r'^([A-Za-z0-9_.-]+)', dep)
    if m: names.append(m.group(1).lower())
print(json.dumps(names))
")
fi

# --- ciSystem / preCommitHooks / dockerSupport / envFiles (same patterns as Node) ---
ciSystem="none"
[ -d "$DIR/.github/workflows" ] && ciSystem="github-actions"
[ -f "$DIR/.gitlab-ci.yml" ] && ciSystem="gitlab-ci"

preCommitHooks="none"
[ -f "$DIR/.pre-commit-config.yaml" ] && preCommitHooks="pre-commit"

dockerSupport="false"
[ -f "$DIR/Dockerfile" ] && dockerSupport="true"

# jq -s emits '[]' when the glob matches nothing, so no fallback is needed;
# adding one would double the output (the ls failure triggers the fallback
# under pipefail while the pipeline still emits '[]' on stdout).
envFiles=$(ls "$DIR"/.env* 2>/dev/null | sed "s|^$DIR/||" | jq -R . | jq -s '.')

# --- Final JSON ---
jq -n \
    --arg type "python" \
    --arg packageManager "$packageManager" \
    --arg pythonVersion "$pythonVersion" \
    --arg framework "$framework" \
    --arg testCommand "$testCommand" \
    --arg lintCommand "$lintCommand" \
    --arg formatCommand "$formatCommand" \
    --arg typecheckCommand "$typecheckCommand" \
    --arg virtualEnv "$virtualEnv" \
    --arg dbMigrations "$dbMigrations" \
    --argjson mainDeps "$mainDeps" \
    --arg ciSystem "$ciSystem" \
    --arg preCommitHooks "$preCommitHooks" \
    --arg dockerSupport "$dockerSupport" \
    --argjson envFiles "$envFiles" \
    '{
        type: $type,
        packageManager: $packageManager,
        pythonVersion: $pythonVersion,
        framework: $framework,
        testCommand: $testCommand,
        lintCommand: $lintCommand,
        formatCommand: $formatCommand,
        typecheckCommand: $typecheckCommand,
        virtualEnv: $virtualEnv,
        dbMigrations: $dbMigrations,
        mainDeps: $mainDeps,
        ciSystem: $ciSystem,
        preCommitHooks: $preCommitHooks,
        dockerSupport: ($dockerSupport == "true"),
        envFiles: $envFiles
    }'
