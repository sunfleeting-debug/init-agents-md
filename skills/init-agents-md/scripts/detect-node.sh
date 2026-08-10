#!/usr/bin/env bash
# Parse a Node.js project's package.json + lockfiles + workspace markers.
# Usage: detect-node.sh <project-dir>
# Output: JSON document (see references/node-detection.md for schema)
# Exit codes: 0 = parsed, 1 = no package.json, 2 = usage error

set -uo pipefail

if [ $# -lt 1 ]; then
    echo "Usage: detect-node.sh <project-dir>" >&2
    exit 2
fi

DIR="$1"
PKG="$DIR/package.json"

if [ ! -f "$PKG" ]; then
    echo "detect-node.sh: package.json not found in $DIR" >&2
    exit 1
fi

# --- packageManager (from field, fallback to lockfile) ---
pm=$(jq -r '.packageManager // empty' "$PKG" | sed 's/@.*//')
if [ -z "$pm" ]; then
    if [ -f "$DIR/pnpm-lock.yaml" ]; then pm="pnpm"
    elif [ -f "$DIR/yarn.lock" ]; then pm="yarn"
    elif [ -f "$DIR/bun.lockb" ]; then pm="bun"
    else pm="npm"; fi
fi

# --- language ---
if [ -f "$DIR/tsconfig.json" ]; then lang="typescript"; else lang="javascript"; fi

# --- framework (heuristic from dependencies) ---
framework="none"
for fw in next nuxt remix svelte-kit vite astro gatsby express fastify nestjs; do
    if jq -e --arg k "$fw" '.dependencies[$k] // .devDependencies[$k] // empty' "$PKG" > /dev/null; then
        framework="$fw"; break
    fi
done

# --- scripts ---
scripts=$(jq -c '.scripts // {}' "$PKG")

# --- testFramework (heuristic from devDependencies) ---
testFramework="none"
for tf in vitest jest mocha uvu tap; do
    if jq -e --arg k "$tf" '.devDependencies[$k] // .dependencies[$k] // empty' "$PKG" > /dev/null; then
        testFramework="$tf"; break
    fi
done

# --- linter / formatter ---
linter="none"
for l in eslint biome oxlint; do
    if jq -e --arg k "$l" '.devDependencies[$k] // .dependencies[$k] // empty' "$PKG" > /dev/null; then
        linter="$l"; break
    fi
done
formatter="none"
for f in prettier biome dprint; do
    if jq -e --arg k "$f" '.devDependencies[$k] // .dependencies[$k] // empty' "$PKG" > /dev/null; then
        formatter="$f"; break
    fi
done

# --- typeChecker ---
typeChecker="none"
if [ -f "$DIR/tsconfig.json" ]; then typeChecker="tsc"; fi

# --- bundler (heuristic) ---
bundler="none"
for b in webpack turbopack vite esbuild rollup parcel; do
    if jq -e --arg k "$b" '.devDependencies[$k] // .dependencies[$k] // empty' "$PKG" > /dev/null; then
        bundler="$b"; break
    fi
done

# --- lint-staged ---
lintStaged="false"
if jq -e '.["lint-staged"] // empty' "$PKG" > /dev/null; then lintStaged="true"; fi

# --- mainDeps ---
mainDeps=$(jq -c '[.dependencies // {} | keys[]]' "$PKG")

# --- ciSystem ---
ciSystem="none"
if [ -d "$DIR/.github/workflows" ]; then ciSystem="github-actions"
elif [ -f "$DIR/.gitlab-ci.yml" ]; then ciSystem="gitlab-ci"
elif [ -d "$DIR/.circleci" ]; then ciSystem="circleci"
fi

# --- preCommitHooks ---
preCommitHooks="none"
if [ -d "$DIR/.husky" ]; then preCommitHooks="husky"
elif [ -f "$DIR/.pre-commit-config.yaml" ]; then preCommitHooks="pre-commit"
elif [ -f "$DIR/lefthook.yml" ]; then preCommitHooks="lefthook"
fi

# --- dockerSupport ---
dockerSupport="false"
if [ -f "$DIR/Dockerfile" ] || ls "$DIR"/Dockerfile.* > /dev/null 2>&1; then
    dockerSupport="true"
fi

# --- envFiles ---
# jq -s emits '[]' when the glob matches nothing, so no fallback is needed;
# adding one would double the output (the ls failure triggers the fallback
# under pipefail while the pipeline still emits '[]' on stdout).
envFiles=$(ls "$DIR"/.env* 2>/dev/null | sed "s|^$DIR/||" | jq -R . | jq -s '.')

# --- Assemble final JSON ---
jq -n \
    --arg type "node" \
    --arg packageManager "$pm" \
    --arg language "$lang" \
    --arg framework "$framework" \
    --argjson scripts "$scripts" \
    --arg testFramework "$testFramework" \
    --arg linter "$linter" \
    --arg formatter "$formatter" \
    --arg typeChecker "$typeChecker" \
    --arg bundler "$bundler" \
    --arg lintStaged "$lintStaged" \
    --argjson mainDeps "$mainDeps" \
    --arg ciSystem "$ciSystem" \
    --arg preCommitHooks "$preCommitHooks" \
    --arg dockerSupport "$dockerSupport" \
    --argjson envFiles "$envFiles" \
    '{
        type: $type,
        packageManager: $packageManager,
        language: $language,
        framework: $framework,
        scripts: $scripts,
        testFramework: $testFramework,
        linter: $linter,
        formatter: $formatter,
        typeChecker: $typeChecker,
        bundler: $bundler,
        lintStaged: ($lintStaged == "true"),
        mainDeps: $mainDeps,
        ciSystem: $ciSystem,
        preCommitHooks: $preCommitHooks,
        dockerSupport: ($dockerSupport == "true"),
        envFiles: $envFiles
    }'
