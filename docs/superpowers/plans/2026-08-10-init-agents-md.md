# init-agents-md Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a Claude Code skill (`init-agents-md`) that bootstraps an authoritative `AGENTS.md` plus command wrapper scripts for Node / Python / Java team projects, replacing per-tool vendor rule files.

**Architecture:** Skill-orchestrator pattern. `SKILL.md` drives a 12-step pipeline (detect → extract → infer → Q&A → gap-analysis → render → validate → diff → write) using bash detection scripts that produce ground-truth JSON from `package.json` / `pyproject.toml` / `pom.xml`, plain-text templates that the LLM fills in via `{{placeholder}}` substitution, and an AI-judgment gap analyzer that surfaces missing project-quality items as a user-checked checklist. No command is ever invented by the LLM — every command traces back to a real manifest field.

**Tech Stack:** Bash (Git Bash compatible on Windows), `jq` for JSON parsing, Python 3 stdlib (`tomllib`, `xml.etree.ElementTree`) for TOML/XML parsing, plain Markdown templates, no external test framework (custom shell assertions).

---

## File Structure

All paths relative to repo root `E:/github/agents.md/`.

```
skills/init-agents-md/
├── SKILL.md                                # Main orchestrator (created in Task 18)
├── references/                             # LLM-consulted docs (created in Task 12)
│   ├── node-detection.md
│   ├── python-detection.md
│   ├── java-detection.md
│   ├── agent-compatibility.md
│   ├── vendor-rules-inventory.md
│   ├── public-api-scanning.md
│   └── docstring-conventions.md
├── scripts/                                # Detection + extraction (Tasks 2-11)
│   ├── detect.sh
│   ├── detect-node.sh
│   ├── detect-python.sh
│   ├── detect-java.sh
│   ├── extract-commands.sh
│   ├── public-api-scan.sh
│   ├── vendor-rules-scan.sh
│   ├── gap-analyzer.sh
│   ├── render-section.sh
│   └── dry-run-validate.sh
├── templates/                              # Content templates (Tasks 13-17)
│   ├── sections/
│   │   ├── 01-overview.md
│   │   ├── 02-tech-stack.md
│   │   ├── 03-repository-layout.md
│   │   ├── 04-dev-environment.md
│   │   ├── 05-build-test.md
│   │   ├── 06-architecture.md
│   │   ├── 07-code-conventions.md
│   │   ├── 08-database-external.md
│   │   ├── 09-pr-commit-workflow.md
│   │   ├── 10-project-background.md
│   │   ├── 11-forbidden-zones.md
│   │   ├── 12-perf-security.md
│   │   └── 13-troubleshooting.md
│   ├── scripts/
│   │   ├── setup.sh.tmpl
│   │   ├── dev.sh.tmpl
│   │   ├── build.sh.tmpl
│   │   ├── test.sh.tmpl
│   │   ├── lint.sh.tmpl
│   │   ├── format.sh.tmpl
│   │   └── typecheck.sh.tmpl
│   ├── code/
│   │   ├── logger.ts.tmpl
│   │   ├── logging.py.tmpl
│   │   └── LogConfig.java.tmpl
│   ├── docs/
│   │   ├── api-readme.md.tmpl
│   │   ├── openapi-skeleton.yaml.tmpl
│   │   └── module-readme.md.tmpl
│   ├── migration-report.md.tmpl
│   └── missing-items-report.md.tmpl
├── examples/
│   └── sample-output/                      # Full worked example (Task 19)
│       ├── AGENTS.md
│       ├── scripts/
│       ├── AGENTS_MIGRATION.md
│       └── AGENTS_MISSING.md
└── tests/                                  # Test framework + fixtures + assertions (Task 1)
    ├── helpers.sh                          # assert_eq, assert_json_eq, etc.
    ├── run.sh                              # Runs all test_*.sh
    ├── fixtures/
    │   ├── node-project/                   # pnpm + Next.js + TypeScript
    │   ├── python-project/                 # poetry + FastAPI
    │   └── java-project/                   # maven + Spring Boot
    ├── test_detect.sh
    ├── test_detect_node.sh
    ├── test_detect_python.sh
    ├── test_detect_java.sh
    ├── test_extract_commands.sh
    ├── test_public_api_scan.sh
    ├── test_vendor_rules_scan.sh
    ├── test_gap_analyzer.sh
    ├── test_render_section.sh
    ├── test_dry_run_validate.sh
    └── test_integration.sh                 # End-to-end on fixtures (Task 20)
```

---

## Task 1: Test framework + fixtures

**Files:**
- Create: `skills/init-agents-md/tests/helpers.sh`
- Create: `skills/init-agents-md/tests/run.sh`
- Create: `skills/init-agents-md/tests/fixtures/node-project/package.json`
- Create: `skills/init-agents-md/tests/fixtures/node-project/pnpm-lock.yaml`
- Create: `skills/init-agents-md/tests/fixtures/python-project/pyproject.toml`
- Create: `skills/init-agents-md/tests/fixtures/java-project/pom.xml`

- [ ] **Step 1: Create test helpers**

Write to `skills/init-agents-md/tests/helpers.sh`:

```bash
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
    local actual
    actual=$(echo "$1" | jq -r "$2")
    assert_eq "$actual" "$3" "$4"
}

# Resolve a fixture path. Usage: fix "node-project" "package.json"
fix() {
    echo "$(dirname "$0")/fixtures/$1/$2"
}
```

- [ ] **Step 2: Create test runner**

Write to `skills/init-agents-md/tests/run.sh`:

```bash
#!/usr/bin/env bash
# Run all test_*.sh files. Exits non-zero on first failure.
set -uo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
FAIL=0

for t in "$DIR"/test_*.sh; do
    echo "=== $(basename "$t") ==="
    if ! bash "$t"; then
        echo "FAILED: $t" >&2
        FAIL=1
    fi
done

exit $FAIL
```

- [ ] **Step 3: Create Node fixture (pnpm + Next.js + TypeScript)**

Write to `skills/init-agents-md/tests/fixtures/node-project/package.json`:

```json
{
  "name": "test-node-project",
  "version": "0.1.0",
  "private": true,
  "packageManager": "pnpm@9.15.1",
  "scripts": {
    "dev": "next dev",
    "build": "next build",
    "test": "vitest run",
    "lint": "eslint .",
    "format": "prettier --write .",
    "typecheck": "tsc --noEmit"
  },
  "dependencies": {
    "next": "16.1.0",
    "react": "19.2.3"
  },
  "devDependencies": {
    "typescript": "5",
    "vitest": "2",
    "eslint": "9",
    "prettier": "3"
  }
}
```

Write to `skills/init-agents-md/tests/fixtures/node-project/pnpm-lock.yaml`:

```yaml
lockfileVersion: '9.0'
```

- [ ] **Step 4: Create Python fixture (poetry + FastAPI)**

Write to `skills/init-agents-md/tests/fixtures/python-project/pyproject.toml`:

```toml
[project]
name = "test-python-project"
version = "0.1.0"
requires-python = ">=3.11"
dependencies = [
    "fastapi>=0.110",
    "pydantic>=2",
]

[project.optional-dependencies]
dev = [
    "pytest>=8",
    "ruff>=0.4",
    "mypy>=1.10",
]

[tool.poetry]
package-mode = false

[tool.pytest.ini_options]
testpaths = ["tests"]

[tool.ruff]
line-length = 100

[tool.mypy]
strict = true
```

- [ ] **Step 5: Create Java fixture (maven + Spring Boot)**

Write to `skills/init-agents-md/tests/fixtures/java-project/pom.xml`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0">
    <modelVersion>4.0.0</modelVersion>
    <parent>
        <groupId>org.springframework.boot</groupId>
        <artifactId>spring-boot-starter-parent</artifactId>
        <version>3.3.0</version>
    </parent>
    <groupId>com.example</groupId>
    <artifactId>test-java-project</artifactId>
    <version>0.1.0</version>
    <properties>
        <java.version>17</java.version>
    </properties>
    <dependencies>
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-web</artifactId>
        </dependency>
    </dependencies>
</project>
```

- [ ] **Step 6: Smoke-test the helpers**

Run:
```bash
chmod +x skills/init-agents-md/tests/run.sh skills/init-agents-md/tests/helpers.sh
cat > /tmp/smoke_test.sh <<'EOF'
#!/usr/bin/env bash
source skills/init-agents-md/tests/helpers.sh
assert_eq "a" "a" "smoke equality"
assert_contains "hello world" "world" "smoke contains"
assert_file_exists "skills/init-agents-md/tests/helpers.sh" "smoke file exists"
echo "smoke OK"
EOF
bash /tmp/smoke_test.sh
```

Expected: All three assertions print `PASS`, then `smoke OK`. No `FAIL` output.

- [ ] **Step 7: Commit**

```bash
git add skills/init-agents-md/tests/
git commit -m "test(init-agents-md): add test framework and three language fixtures"
```

---

## Task 2: detect.sh — project type identification

**Files:**
- Create: `skills/init-agents-md/scripts/detect.sh`
- Create: `skills/init-agents-md/tests/test_detect.sh`

- [ ] **Step 1: Write the failing test**

Write to `skills/init-agents-md/tests/test_detect.sh`:

```bash
#!/usr/bin/env bash
set -uo pipefail
source "$(dirname "$0")/helpers.sh"

DIR="$(cd "$(dirname "$0")/.." && pwd)"

result=$("$DIR/scripts/detect.sh" "$(fix node-project)")
assert_eq "$result" "node" "node-project → node"

result=$("$DIR/scripts/detect.sh" "$(fix python-project)")
assert_eq "$result" "python" "python-project → python"

result=$("$DIR/scripts/detect.sh" "$(fix java-project)")
assert_eq "$result" "java" "java-project → java"

# Missing arg should emit usage and fail
if "$DIR/scripts/detect.sh" 2>/dev/null; then
    fail "detect.sh with no arg should exit non-zero"
else
    pass "detect.sh with no arg exits non-zero"
fi
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash skills/init-agents-md/tests/test_detect.sh`
Expected: FAIL with "scripts/detect.sh: No such file or directory" or "Permission denied".

- [ ] **Step 3: Implement detect.sh**

Write to `skills/init-agents-md/scripts/detect.sh`:

```bash
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
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bash skills/init-agents-md/tests/test_detect.sh`
Expected: All four `PASS` lines, exit 0.

- [ ] **Step 5: Commit**

```bash
git add skills/init-agents-md/scripts/detect.sh skills/init-agents-md/tests/test_detect.sh
git commit -m "feat(init-agents-md): add detect.sh for project-type identification"
```

---

## Task 3: detect-node.sh — Node manifest parser

**Files:**
- Create: `skills/init-agents-md/scripts/detect-node.sh`
- Create: `skills/init-agents-md/tests/test_detect_node.sh`

- [ ] **Step 1: Write the failing test**

Write to `skills/init-agents-md/tests/test_detect_node.sh`:

```bash
#!/usr/bin/env bash
set -uo pipefail
source "$(dirname "$0")/helpers.sh"

DIR="$(cd "$(dirname "$0")/.." && pwd)"
JSON=$("$DIR/scripts/detect-node.sh" "$(fix node-project)")

assert_json_eq "$JSON" '.type'               "node"            "type=node"
assert_json_eq "$JSON" '.packageManager'     "pnpm"            "packageManager=pnpm"
assert_json_eq "$JSON" '.language'           "javascript"      "language=javascript (no tsconfig in fixture)"
assert_json_eq "$JSON" '.framework'          "next"            "framework=next"
assert_json_eq "$JSON" '.testFramework'      "vitest"          "testFramework=vitest"
assert_json_eq "$JSON" '.linter'             "eslint"          "linter=eslint"
assert_json_eq "$JSON" '.formatter'          "prettier"        "formatter=prettier"
assert_json_eq "$JSON" '.scripts.test'       "vitest run"      "scripts.test=vitest run"
assert_json_eq "$JSON" '.scripts.dev'        "next dev"        "scripts.dev=next dev"
assert_json_eq "$JSON" '.mainDeps | length'  "2"               "mainDeps has 2 entries"
assert_json_eq "$JSON" '.ciSystem'           "none"            "ciSystem=none (no .github/workflows)"
assert_json_eq "$JSON" '.dockerSupport'      "false"           "dockerSupport=false"
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash skills/init-agents-md/tests/test_detect_node.sh`
Expected: FAIL — script missing.

- [ ] **Step 3: Implement detect-node.sh**

Write to `skills/init-agents-md/scripts/detect-node.sh`:

```bash
#!/usr/bin/env bash
# Parse a Node.js project's package.json + lockfiles + workspace markers.
# Usage: detect-node.sh <project-dir>
# Output: JSON document (see references/node-detection.md for schema)

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
envFiles=$(ls "$DIR"/.env* 2>/dev/null | sed "s|^$DIR/||" | jq -R . | jq -s '.' || echo '[]')

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
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bash skills/init-agents-md/tests/test_detect_node.sh`
Expected: All assertions PASS.

- [ ] **Step 5: Commit**

```bash
git add skills/init-agents-md/scripts/detect-node.sh skills/init-agents-md/tests/test_detect_node.sh
git commit -m "feat(init-agents-md): add detect-node.sh for Node manifest parsing"
```

---

## Task 4: detect-python.sh — Python manifest parser

**Files:**
- Create: `skills/init-agents-md/scripts/detect-python.sh`
- Create: `skills/init-agents-md/tests/test_detect_python.sh`

- [ ] **Step 1: Write the failing test**

Write to `skills/init-agents-md/tests/test_detect_python.sh`:

```bash
#!/usr/bin/env bash
set -uo pipefail
source "$(dirname "$0")/helpers.sh"

DIR="$(cd "$(dirname "$0")/.." && pwd)"
JSON=$("$DIR/scripts/detect-python.sh" "$(fix python-project)")

assert_json_eq "$JSON" '.type'                  "python"    "type=python"
assert_json_eq "$JSON" '.packageManager'        "poetry"    "packageManager=poetry"
assert_json_eq "$JSON" '.pythonVersion'         "3.11"      "pythonVersion=3.11"
assert_json_eq "$JSON" '.framework'             "fastapi"   "framework=fastapi"
assert_json_eq "$JSON" '.testCommand'           "pytest"    "testCommand=pytest"
assert_json_eq "$JSON" '.lintCommand'           "ruff"      "lintCommand=ruff"
assert_json_eq "$JSON" '.formatCommand'         "ruff format" "formatCommand=ruff format"
assert_json_eq "$JSON" '.typecheckCommand'      "mypy"      "typecheckCommand=mypy"
assert_json_eq "$JSON" '.virtualEnv'            "poetry"    "virtualEnv=poetry"
assert_json_eq "$JSON" '.ciSystem'              "none"      "ciSystem=none"
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash skills/init-agents-md/tests/test_detect_python.sh`
Expected: FAIL — script missing.

- [ ] **Step 3: Implement detect-python.sh**

Write to `skills/init-agents-md/scripts/detect-python.sh`:

```bash
#!/usr/bin/env bash
# Parse a Python project's pyproject.toml (and fallback manifests).
# Usage: detect-python.sh <project-dir>
# Output: JSON document

set -uo pipefail

if [ $# -lt 1 ]; then
    echo "Usage: detect-python.sh <project-dir>" >&2
    exit 2
fi

DIR="$1"

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
grep -q '\[tool.ruff\]' "$PYPROJECT" 2>/dev/null && lintCommand="ruff check ."

formatCommand="none"
grep -q '\[tool.ruff\]' "$PYPROJECT" 2>/dev/null && formatCommand="ruff format ."

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

envFiles=$(ls "$DIR"/.env* 2>/dev/null | sed "s|^$DIR/||" | jq -R . | jq -s '.' 2>/dev/null || echo '[]')

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
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bash skills/init-agents-md/tests/test_detect_python.sh`
Expected: All assertions PASS.

- [ ] **Step 5: Commit**

```bash
git add skills/init-agents-md/scripts/detect-python.sh skills/init-agents-md/tests/test_detect_python.sh
git commit -m "feat(init-agents-md): add detect-python.sh for pyproject.toml parsing"
```

---

## Task 5: detect-java.sh — Java manifest parser

**Files:**
- Create: `skills/init-agents-md/scripts/detect-java.sh`
- Create: `skills/init-agents-md/tests/test_detect_java.sh`

- [ ] **Step 1: Write the failing test**

Write to `skills/init-agents-md/tests/test_detect_java.sh`:

```bash
#!/usr/bin/env bash
set -uo pipefail
source "$(dirname "$0")/helpers.sh"

DIR="$(cd "$(dirname "$0")/.." && pwd)"
JSON=$("$DIR/scripts/detect-java.sh" "$(fix java-project)")

assert_json_eq "$JSON" '.type'              "java"            "type=java"
assert_json_eq "$JSON" '.buildTool'         "maven"           "buildTool=maven"
assert_json_eq "$JSON" '.javaVersion'       "17"              "javaVersion=17"
assert_json_eq "$JSON" '.framework'         "spring-boot"     "framework=spring-boot"
assert_json_eq "$JSON" '.springBootVersion' "3.3.0"           "springBootVersion=3.3.0"
assert_json_eq "$JSON" '.testCommand'       "mvn test"        "testCommand=mvn test"
assert_json_eq "$JSON" '.buildCommand'      "mvn package"     "buildCommand=mvn package"
assert_json_eq "$JSON" '.jarPackaging'      "jar"             "jarPackaging=jar"
assert_json_eq "$JSON" '.mainDeps | length' "1"               "mainDeps has 1 entry"
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash skills/init-agents-md/tests/test_detect_java.sh`
Expected: FAIL — script missing.

- [ ] **Step 3: Implement detect-java.sh**

> **NOTE (from Task 4 code review):** This script embeds `$POM` inside a Python `-c` string. On Windows the path arrives as backslashes (mangled as escapes) or MSYS `/e/...` form (unopenable by native Python). Include the same cygpath guard from detect-python.sh (`if command -v cygpath > /dev/null 2>&1; then DIR=$(cygpath -m "$1"); else DIR="$1"; fi`) AND pass the manifest path to Python via an environment variable (`POM_FILE="$POM" $PY -c '... os.environ["POM_FILE"] ...'`) rather than string interpolation, so quotes/escapes in paths can't break the `-c` code.

Write to `skills/init-agents-md/scripts/detect-java.sh`:

```bash
#!/usr/bin/env bash
# Parse a Java project's pom.xml (or build.gradle fallback).
# Usage: detect-java.sh <project-dir>
# Output: JSON document

set -uo pipefail

if [ $# -lt 1 ]; then
    echo "Usage: detect-java.sh <project-dir>" >&2
    exit 2
fi

DIR="$1"
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

    eval "$($PY -c "
import xml.etree.ElementTree as ET, json, shlex
ns = {'m': 'http://maven.apache.org/POM/4.0.0'}
root = ET.parse('$POM').getroot()
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

envFiles=$(ls "$DIR"/.env* 2>/dev/null | sed "s|^$DIR/||" | jq -R . | jq -s '.' 2>/dev/null || echo '[]')

# --- Final JSON (Maven path uses variables from python; Gradle path uses defaults) ---
if [ -f "$POM" ]; then
    jq -n \
        --arg type "java" \
        --arg buildTool "${BUILDTOOL:-maven}" \
        --arg javaVersion "${JAVA_VERSION:-}" \
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
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bash skills/init-agents-md/tests/test_detect_java.sh`
Expected: All assertions PASS.

- [ ] **Step 5: Commit**

```bash
git add skills/init-agents-md/scripts/detect-java.sh skills/init-agents-md/tests/test_detect_java.sh
git commit -m "feat(init-agents-md): add detect-java.sh for pom.xml/build.gradle parsing"
```

---

## Task 6: extract-commands.sh — pull commands from detect.json

**Files:**
- Create: `skills/init-agents-md/scripts/extract-commands.sh`
- Create: `skills/init-agents-md/tests/test_extract_commands.sh`

- [ ] **Step 1: Write the failing test**

Write to `skills/init-agents-md/tests/test_extract_commands.sh`:

```bash
#!/usr/bin/env bash
set -uo pipefail
source "$(dirname "$0")/helpers.sh"

DIR="$(cd "$(dirname "$0")/.." && pwd)"

# Node case
DETECT=$("$DIR/scripts/detect-node.sh" "$(fix node-project)")
CMDS=$("$DIR/scripts/extract-commands.sh" "$DETECT")
assert_json_eq "$CMDS" '.test'       "vitest run"   "node: test=vitest run"
assert_json_eq "$CMDS" '.build'      "next build"   "node: build=next build"
assert_json_eq "$CMDS" '.dev'        "next dev"     "node: dev=next dev"
assert_json_eq "$CMDS" '.lint'       "eslint ."     "node: lint=eslint ."
assert_json_eq "$CMDS" '.format'     "prettier --write ." "node: format=prettier"
assert_json_eq "$CMDS" '.typecheck'  "tsc --noEmit" "node: typecheck=tsc --noEmit"

# Python case
DETECT=$("$DIR/scripts/detect-python.sh" "$(fix python-project)")
CMDS=$("$DIR/scripts/extract-commands.sh" "$DETECT")
assert_json_eq "$CMDS" '.test'       "pytest"        "python: test=pytest"
assert_json_eq "$CMDS" '.lint'       "ruff check ."  "python: lint=ruff check ."
assert_json_eq "$CMDS" '.format'     "ruff format"   "python: format=ruff format"
assert_json_eq "$CMDS" '.typecheck'  "mypy"          "python: typecheck=mypy"

# Java case
DETECT=$("$DIR/scripts/detect-java.sh" "$(fix java-project)")
CMDS=$("$DIR/scripts/extract-commands.sh" "$DETECT")
assert_json_eq "$CMDS" '.test'       "mvn test"      "java: test=mvn test"
assert_json_eq "$CMDS" '.build'      "mvn package"   "java: build=mvn package"
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash skills/init-agents-md/tests/test_extract_commands.sh`
Expected: FAIL — script missing.

- [ ] **Step 3: Implement extract-commands.sh**

Write to `skills/init-agents-md/scripts/extract-commands.sh`:

```bash
#!/usr/bin/env bash
# Extract runnable commands from a detect.json document.
# Usage: extract-commands.sh <detect.json>
# Output: commands.json — only fields that have a real value

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
                lint:      $lintCmd,
                format:    $fmtCmd,
                typecheck: $tcCmd,
                setup:     $setup
            } | with_entries(select(.value != "none"))'
        ;;
    java)
        # NOTE: "none" must be dropped along with null so downstream wrapper-script
        # templates (lint.sh/format.sh) don't generate literal `none` commands.
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
            } | with_entries(if .value == null or .value == "none" then empty else . end)'
        ;;
    *)
        echo "extract-commands.sh: unknown type $TYPE" >&2
        exit 1
        ;;
esac
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bash skills/init-agents-md/tests/test_extract_commands.sh`
Expected: All assertions PASS.

- [ ] **Step 5: Commit**

```bash
git add skills/init-agents-md/scripts/extract-commands.sh skills/init-agents-md/tests/test_extract_commands.sh
git commit -m "feat(init-agents-md): add extract-commands.sh for command extraction"
```

---

## Task 7: public-api-scan.sh — detect undocumented public API

**Files:**
- Create: `skills/init-agents-md/scripts/public-api-scan.sh`
- Create: `skills/init-agents-md/tests/fixtures/node-project/src/lib/util.ts` (a sample file to scan)
- Create: `skills/init-agents-md/tests/test_public_api_scan.sh`

- [ ] **Step 1: Add a sample source file for the Node fixture**

Write to `skills/init-agents-md/tests/fixtures/node-project/src/lib/util.ts`:

```typescript
// Undocumented public function
export function add(a: number, b: number): number {
    return a + b;
}

// Documented public function
/** Multiplies two numbers. */
export function multiply(a: number, b: number): number {
    return a * b;
}

// Internal (not exported)
function internalHelper(): void {
    return;
}
```

- [ ] **Step 2: Write the failing test**

Write to `skills/init-agents-md/tests/test_public_api_scan.sh`:

```bash
#!/usr/bin/env bash
set -uo pipefail
source "$(dirname "$0")/helpers.sh"

DIR="$(cd "$(dirname "$0")/.." && pwd)"
JSON=$("$DIR/scripts/public-api-scan.sh" "$(fix node-project)")

# 2 public exports (add, multiply); 1 undocumented (add)
assert_json_eq "$JSON" '.language'        "typescript" "language=typescript"
assert_json_eq "$JSON" '.publicSymbols | length' "2"  "2 public symbols"
assert_json_eq "$JSON" '.undocumented | length'  "1"  "1 undocumented"
assert_json_eq "$JSON" '.undocumented[0].name'   "add" "undocumented[0]=add"
assert_json_eq "$JSON" '.coverage'        "0.5"        "coverage=0.5"
```

- [ ] **Step 3: Run test to verify it fails**

Run: `bash skills/init-agents-md/tests/test_public_api_scan.sh`
Expected: FAIL — script missing.

- [ ] **Step 4: Implement public-api-scan.sh**

Write to `skills/init-agents-md/scripts/public-api-scan.sh`:

```bash
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
        trap "rm -f $symbols_file" EXIT

        while IFS= read -r f; do
            grep -nE '^export (async )?(function|class|const|let|var) [A-Za-z_][A-Za-z0-9_]*' "$f" 2>/dev/null \
                | sed -E "s|^([0-9]+):export (async )?(function|class|const|let|var) ([A-Za-z_][A-Za-z0-9_]*).*|\4 ${f}|"
        done < <(find "$DIR/src" "$_DIR/lib" 2>/dev/null -type f \( -name '*.ts' -o -name '*.tsx' -o -name '*.js' -o -name '*.jsx' \) ! -path '*/node_modules/*')

        total=0
        undoc_file=$(mktemp)
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
            undoc_json=$(awk -F'|' '{
                printf "{name: \"%s\", file: \"%s\", line: %s},", $1, $2, $3
            }' "$undoc_file" | sed 's/,$//' | jq -s '.')
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
                coverage: ($coverage | tonumber)
            }'
        ;;
    python)
        # Simple grep: lines like "def name(" or "class name" at column 0 (public).
        # Public = not prefixed with _.
        symbols_file=$(mktemp)
        > "$symbols_file"
        while IFS= read -r f; do
            grep -nE '^(def|class) [A-Za-z]' "$f" 2>/dev/null | while IFS=: read -r lineno content; do
                name=$(echo "$content" | sed -E 's/^(def|class) ([A-Za-z_][A-Za-z0-9_]*).*/\2/')
                if [[ ! "$name" =~ ^_ ]]; then
                    echo "$name|$f|$lineno"
                fi
            done
        done < <(find "$DIR" -type f -name '*.py' ! -path '*/.venv/*' ! -path '*/__pycache__/*' ! -path '*/node_modules/*')

        total=$(wc -l < "$symbols_file" | tr -d ' ')
        undoc_file=$(mktemp)
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
            undoc_json=$(awk -F'|' '{printf "{name: \"%s\", file: \"%s\", line: %s},", $1, $2, $3}' "$undoc_file" | sed 's/,$//' | jq -s '.')
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
                coverage: ($coverage | tonumber)
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
                coverage: ($coverage | tonumber)
            }'
        ;;
    *)
        jq -n '{language: null, publicSymbols: 0, undocumented: [], coverage: 1.00}'
        ;;
esac
```

- [ ] **Step 5: Run test to verify it passes**

Run: `bash skills/init-agents-md/tests/test_public_api_scan.sh`
Expected: All assertions PASS.

- [ ] **Step 6: Commit**

```bash
git add skills/init-agents-md/scripts/public-api-scan.sh skills/init-agents-md/tests/test_public_api_scan.sh skills/init-agents-md/tests/fixtures/node-project/src/lib/util.ts
git commit -m "feat(init-agents-md): add public-api-scan.sh for docstring coverage"
```

---

## Task 8: vendor-rules-scan.sh — detect existing vendor rule files

**Files:**
- Create: `skills/init-agents-md/scripts/vendor-rules-scan.sh`
- Create: `skills/init-agents-md/tests/fixtures/node-project/.claude/CLAUDE.md`
- Create: `skills/init-agents-md/tests/test_vendor_rules_scan.sh`

- [ ] **Step 1: Add a sample vendor rule file to the Node fixture**

Write to `skills/init-agents-md/tests/fixtures/node-project/.claude/CLAUDE.md`:

```markdown
# Project CLAUDE.md

Use pnpm, not npm. Run tests with `pnpm test`.
```

- [ ] **Step 2: Write the failing test**

Write to `skills/init-agents-md/tests/test_vendor_rules_scan.sh`:

```bash
#!/usr/bin/env bash
set -uo pipefail
source "$(dirname "$0")/helpers.sh"

DIR="$(cd "$(dirname "$0")/.." && pwd)"
JSON=$("$DIR/scripts/vendor-rules-scan.sh" "$(fix node-project)")

assert_json_eq "$JSON" '.files | length' "1"   "1 vendor rule file found"
assert_json_eq "$JSON" '.files[0].path' ".claude/CLAUDE.md" "found .claude/CLAUDE.md"
assert_json_eq "$JSON" '.files[0].tool' "claude-code"     "tool=claude-code"
```

- [ ] **Step 3: Run test to verify it fails**

Run: `bash skills/init-agents-md/tests/test_vendor_rules_scan.sh`
Expected: FAIL — script missing.

- [ ] **Step 4: Implement vendor-rules-scan.sh**

Write to `skills/init-agents-md/scripts/vendor-rules-scan.sh`:

```bash
#!/usr/bin/env bash
# Find known vendor-specific rule files in a project.
# Usage: vendor-rules-scan.sh <project-dir>
# Output: JSON listing paths and tools.
# IMPORTANT: This script reads paths only. It does NOT read or modify file contents.

set -uo pipefail

if [ $# -lt 1 ]; then
    echo "Usage: vendor-rules-scan.sh <project-dir>" >&2
    exit 2
fi

DIR="$1"

# Each entry: <path-glob>:<tool-name>
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

# Skip AGENTS.md itself (it's our target, not a "vendor" rule).
# Actually, we DO want to flag it if it exists, because the skill should diff against it.
# But its "tool" should reflect that it's the canonical spec.

jq -n --argjson files "$found" '{files: $files}'
```

- [ ] **Step 5: Run test to verify it passes**

Run: `bash skills/init-agents-md/tests/test_vendor_rules_scan.sh`
Expected: All assertions PASS.

- [ ] **Step 6: Commit**

```bash
git add skills/init-agents-md/scripts/vendor-rules-scan.sh skills/init-agents-md/tests/test_vendor_rules_scan.sh skills/init-agents-md/tests/fixtures/node-project/.claude/CLAUDE.md
git commit -m "feat(init-agents-md): add vendor-rules-scan.sh for vendor rule file detection"
```

---

## Task 9: gap-analyzer.sh — surface missing project-quality items

**Files:**
- Create: `skills/init-agents-md/scripts/gap-analyzer.sh`
- Create: `skills/init-agents-md/tests/test_gap_analyzer.sh`

- [ ] **Step 1: Write the failing test**

Write to `skills/init-agents-md/tests/test_gap_analyzer.sh`:

```bash
#!/usr/bin/env bash
set -uo pipefail
source "$(dirname "$0")/helpers.sh"

DIR="$(cd "$(dirname "$0")/.." && pwd)"

# Node fixture: has tests, lint, format — but no logger; CI=none; no pre-commit
DETECT=$("$DIR/scripts/detect-node.sh" "$(fix node-project)")
PUBLIC_API=$("$DIR/scripts/public-api-scan.sh" "$(fix node-project)")
GAP=$("$DIR/scripts/gap-analyzer.sh" "$DETECT" "$PUBLIC_API" "$(fix node-project)")

# Should propose: API docstrings (coverage < 0.8), no pre-commit
# Should NOT propose: logger (no info), CI (test framework exists; the heuristic flags CI only if commands exist but no CI)
item_count=$(echo "$GAP" | jq '.items | length')
[ "$item_count" -ge 1 ] && pass "at least 1 gap item" || fail "expected >=1 gap items, got $item_count"

# Coverage < 0.8 should trigger docstring item
docstring_item=$(echo "$GAP" | jq '[.items[] | select(.kind == "docstring-coverage")] | length')
assert_eq "$docstring_item" "1" "docstring-coverage gap is flagged"
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash skills/init-agents-md/tests/test_gap_analyzer.sh`
Expected: FAIL — script missing.

- [ ] **Step 3: Implement gap-analyzer.sh**

Write to `skills/init-agents-md/scripts/gap-analyzer.sh`:

```bash
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
        if ! find "$DIR" -path '*/node_modules' -prune -o -type f \( -name 'logger.ts' -o -name 'logger.js' -o -name 'pino*.ts' -o -name 'winston*.ts' \) -print 2>/dev/null | grep -q .; then
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
if [ "$coverage" != "null" ] && [ "$coverage" != "1.00" ]; then
    # Use awk for float comparison
    if awk -v c "$coverage" 'BEGIN { exit !(c < 0.8) }'; then
        add_item "docstring-coverage" "info" \
            "公开 API 注释覆盖率 $(awk -v c "$coverage" 'BEGIN { printf "%.0f%%", c*100 }'),未注释数 $undoc" \
            "补全公开 API 的 JSDoc / docstring / Javadoc"
    fi
fi

# --- CI missing ---
ci=$(echo "$DETECT" | jq -r '.ciSystem')
if [ "$ci" = "none" ]; then
    has_test=$(echo "$DETECT" | jq -r '.testCommand // .scripts.test // "none"')
    if [ "$has_test" != "none" ] && [ "$has_test" != "null" ]; then
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
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bash skills/init-agents-md/tests/test_gap_analyzer.sh`
Expected: All assertions PASS.

- [ ] **Step 5: Commit**

```bash
git add skills/init-agents-md/scripts/gap-analyzer.sh skills/init-agents-md/tests/test_gap_analyzer.sh
git commit -m "feat(init-agents-md): add gap-analyzer.sh for missing-quality detection"
```

---

## Task 10: render-section.sh — substitute {{placeholders}} in section templates

**Files:**
- Create: `skills/init-agents-md/scripts/render-section.sh`
- Create: `skills/init-agents-md/templates/sections/02-tech-stack.md` (one template as fixture)
- Create: `skills/init-agents-md/tests/test_render_section.sh`

- [ ] **Step 1: Write the test template**

Write to `skills/init-agents-md/templates/sections/02-tech-stack.md`:

```markdown
## 2. 技术栈

- 语言: {{language}}
- 包管理器: {{packageManager}}
- 框架: {{framework}}
- 测试: {{testFramework}}
- Lint: {{linter}}
```

- [ ] **Step 2: Write the failing test**

Write to `skills/init-agents-md/tests/test_render_section.sh`:

```bash
#!/usr/bin/env bash
set -uo pipefail
source "$(dirname "$0")/helpers.sh"

DIR="$(cd "$(dirname "$0")/.." && pwd)"
TMPL="$DIR/templates/sections/02-tech-stack.md"

DATA='{"language":"typescript","packageManager":"pnpm","framework":"next","testFramework":"vitest","linter":"eslint"}'

OUT=$("$DIR/scripts/render-section.sh" "$TMPL" "$DATA")

assert_contains "$OUT" "语言: typescript"  "language substituted"
assert_contains "$OUT" "包管理器: pnpm"    "packageManager substituted"
assert_contains "$OUT" "框架: next"         "framework substituted"
assert_contains "$OUT" "测试: vitest"       "testFramework substituted"
assert_contains "$OUT" "Lint: eslint"       "linter substituted"
```

- [ ] **Step 3: Run test to verify it fails**

Run: `bash skills/init-agents-md/tests/test_render_section.sh`
Expected: FAIL — script missing.

- [ ] **Step 4: Implement render-section.sh**

Write to `skills/init-agents-md/scripts/render-section.sh`:

```bash
#!/usr/bin/env bash
# Render a template file by substituting {{placeholder}} tokens from a JSON file.
# Usage: render-section.sh <template-path> <data.json>
# Output: rendered template to stdout

set -uo pipefail

if [ $# -lt 2 ]; then
    echo "Usage: render-section.sh <template> <data.json>" >&2
    exit 2
fi

TMPL="$1"
DATA="$2"

if [ ! -f "$TMPL" ]; then
    echo "render-section.sh: template not found: $TMPL" >&2
    exit 1
fi

# Walk every {{key}} token; substitute from $DATA.
# Use Python for reliable regex (jq alone can't iterate unknown keys cleanly).

python3 - "$TMPL" "$DATA" <<'PYEOF'
import sys, re, json
tmpl_path, data_path = sys.argv[1], sys.argv[2]
with open(tmpl_path, 'r', encoding='utf-8') as f:
    text = f.read()
with open(data_path, 'r', encoding='utf-8') as f:
    data = json.load(f)

def repl(m):
    key = m.group(1).strip()
    val = data.get(key)
    if val is None:
        return f"{{{{{key}}}}}"
    return str(val)

# Match {{ key }} with optional whitespace.
print(re.sub(r"\{\{\s*([A-Za-z_][A-Za-z0-9_]*)\s*\}\}", repl, text))
PYEOF
```

- [ ] **Step 5: Run test to verify it passes**

Run: `bash skills/init-agents-md/tests/test_render_section.sh`
Expected: All assertions PASS.

- [ ] **Step 6: Commit**

```bash
git add skills/init-agents-md/scripts/render-section.sh skills/init-agents-md/tests/test_render_section.sh skills/init-agents-md/templates/sections/02-tech-stack.md
git commit -m "feat(init-agents-md): add render-section.sh for template substitution"
```

---

## Task 11: dry-run-validate.sh — verify generated scripts are sane

**Files:**
- Create: `skills/init-agents-md/scripts/dry-run-validate.sh`
- Create: `skills/init-agents-md/tests/test_dry_run_validate.sh`

- [ ] **Step 1: Write the failing test**

Write to `skills/init-agents-md/tests/test_dry_run_validate.sh`:

```bash
#!/usr/bin/env bash
set -uo pipefail
source "$(dirname "$0")/helpers.sh"

DIR="$(cd "$(dirname "$0")/.." && pwd)"

# Create a temp scripts dir with one valid and one invalid script
TMPDIR=$(mktemp -d)
trap "rm -rf $TMPDIR" EXIT

cat > "$TMPDIR/valid.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
echo hello
EOF
chmod +x "$TMPDIR/valid.sh"

cat > "$TMPDIR/invalid.sh" <<'EOF'
#!/usr/bin/env bash
if [ x = y
EOF
chmod +x "$TMPDIR/invalid.sh"

# Valid script: exit 0
"$DIR/scripts/dry-run-validate.sh" "$TMPDIR/valid.sh" > /dev/null
assert_eq "$?" "0" "valid script: validation passes"

# Invalid script: exit non-zero
set +e
"$DIR/scripts/dry-run-validate.sh" "$TMPDIR/invalid.sh" > /dev/null 2>&1
rc=$?
set -e
[ "$rc" -ne 0 ] && pass "invalid script: validation fails" || fail "invalid script: validation should fail (rc=$rc)"
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash skills/init-agents-md/tests/test_dry_run_validate.sh`
Expected: FAIL — script missing.

- [ ] **Step 3: Implement dry-run-validate.sh**

Write to `skills/init-agents-md/scripts/dry-run-validate.sh`:

```bash
#!/usr/bin/env bash
# Run sanity checks against a generated shell script.
# Usage: dry-run-validate.sh <script-path>
# Exit: 0 if all checks pass, non-zero otherwise.
#
# Checks performed:
#   1. bash -n  — syntax
#   2. bash <script> --help  — at least runs (script returns non-error on --help)

set -uo pipefail

if [ $# -lt 1 ]; then
    echo "Usage: dry-run-validate.sh <script>" >&2
    exit 2
fi

SCRIPT="$1"

if [ ! -f "$SCRIPT" ]; then
    echo "dry-run-validate: not a file: $SCRIPT" >&2
    exit 1
fi

# Check 1: syntax
if ! bash -n "$SCRIPT"; then
    echo "FAIL: bash -n syntax error in $SCRIPT" >&2
    exit 1
fi
echo "OK: syntax check passed for $SCRIPT"

# Check 2: --help runs without error
# Wrap in set +e to capture exit, but most well-formed scripts that don't
# implement --help will print to stderr and exit non-zero.
if bash "$SCRIPT" --help > /dev/null 2>&1; then
    echo "OK: --help ran successfully"
else
    # Not necessarily fatal — many wrapper scripts don't implement --help.
    # Just record the observation; do not fail.
    echo "NOTE: --help did not exit 0 (acceptable for wrapper scripts)"
fi

# Check 3: if script references a known tool (pnpm/npm/mvn/pytest), check it's on PATH
if grep -qE '\b(pnpm|npm|yarn|bun)\b' "$SCRIPT"; then
    for tool in pnpm npm yarn bun; do
        if grep -qE "\b$tool\b" "$SCRIPT" && command -v "$tool" > /dev/null 2>&1; then
            echo "OK: $tool is on PATH"
        fi
    done
fi
if grep -qE '\b(mvn|gradle)\b' "$SCRIPT" && ! command -v mvn > /dev/null && ! command -v gradle > /dev/null; then
    echo "WARN: mvn/gradle not on PATH (script may fail at runtime)"
fi
if grep -qE '\bpytest\b' "$SCRIPT" && ! command -v pytest > /dev/null; then
    echo "WARN: pytest not on PATH (script may fail at runtime)"
fi

exit 0
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bash skills/init-agents-md/tests/test_dry_run_validate.sh`
Expected: Both assertions PASS.

- [ ] **Step 5: Commit**

```bash
git add skills/init-agents-md/scripts/dry-run-validate.sh skills/init-agents-md/tests/test_dry_run_validate.sh
git commit -m "feat(init-agents-md): add dry-run-validate.sh for script sanity checks"
```

---

## Task 12: References — LLM-consulted docs

**Files:** Create all 7 reference docs.

- [ ] **Step 1: Write references/node-detection.md**

```markdown
# Node.js Project Detection

When invoked on a project, the skill must inspect the following signals to
classify and characterize a Node.js project.

## Identification

- `package.json` exists → Node.js project.

## Characterization

- **packageManager**: read `.packageManager` field; fall back to lockfile:
  - `pnpm-lock.yaml` → pnpm
  - `yarn.lock`     → yarn
  - `bun.lockb`     → bun
  - `package-lock.json` → npm
- **language**: presence of `tsconfig.json` → TypeScript; else JavaScript.
- **framework**: scan `.dependencies` and `.devDependencies` for first match:
  next → nuxt → remix → svelte-kit → vite → astro → gatsby → express → fastify → nestjs.
  Default: `none`.
- **scripts**: read `.scripts` object; expect keys `dev`, `build`, `test`,
  `lint`, `format`, `typecheck` (any may be missing).
- **testFramework**: scan devDeps for vitest, jest, mocha, uvu, tap.
- **linter**: scan devDeps for eslint, biome, oxlint.
- **formatter**: scan devDeps for prettier, biome, dprint.
- **typeChecker**: `tsconfig.json` present → tsc; else none.
- **bundler**: scan devDeps for webpack, turbopack, vite, esbuild, rollup, parcel.
- **lint-staged**: presence of `lint-staged` key at root of package.json.

## Workspace & CI signals

- **ciSystem**: `.github/workflows` → github-actions; `.gitlab-ci.yml` → gitlab-ci;
  `.circleci` → circleci.
- **preCommitHooks**: `.husky` → husky; `.pre-commit-config.yaml` → pre-commit;
  `lefthook.yml` → lefthook.
- **dockerSupport**: any `Dockerfile*` in root.
- **envFiles**: any `.env*` file in root.

## Edge cases

- No `package.json` → not a Node project; do not invoke `detect-node.sh`.
- Multiple lockfiles (rare) → prefer the field; otherwise pnpm > yarn > bun > npm.
- Workspace (`pnpm-workspace.yaml` or `workspaces` in package.json) → mark as
  monorepo in the rendered `AGENTS.md` §3.
```

- [ ] **Step 2: Write references/python-detection.md**

```markdown
# Python Project Detection

## Identification

- `pyproject.toml` exists → Python project (modern).
- `setup.py` exists → legacy Python project.
- `requirements.txt` exists → at least a Python project.

## Characterization

- **packageManager**:
  - `uv.lock` or `[tool.uv]` section in pyproject.toml → uv
  - `poetry.lock` or `[tool.poetry]` section → poetry
  - `Pipfile` → pipenv
  - `requirements.txt` only → pip
- **pythonVersion**: from `.project.requires-python`; extract `X.Y` with regex.
- **framework**: scan dependencies for fastapi, django, flask, starlette, aiohttp, tornado.
- **testCommand**: presence of `[tool.pytest.*]` → pytest.
- **lintCommand**: presence of `[tool.ruff]` → ruff check .
- **formatCommand**: presence of `[tool.ruff]` → ruff format.
- **typecheckCommand**: presence of `[tool.mypy]` → mypy; else `[tool.pyright]` → pyright.
- **virtualEnv**: defaults to packageManager; if none, venv.
- **dbMigrations**: `[tool.alembic]` → alembic; `django` in deps → django.

## Edge cases

- Multiple package managers (rare): uv wins over poetry wins over pipenv wins over pip.
- No pyproject.toml: read `setup.py` for name/version; treat as legacy.
- venv-style project with only `requirements.txt`: packageManager=pip, virtualEnv=venv.
```

- [ ] **Step 3: Write references/java-detection.md**

```markdown
# Java Project Detection

## Identification

- `pom.xml` exists → Maven project.
- `build.gradle` exists → Gradle project (Groovy DSL).
- `build.gradle.kts` exists → Gradle project (Kotlin DSL).

## Characterization (Maven)

Parse with Python's `xml.etree.ElementTree`, namespace `m: http://maven.apache.org/POM/4.0.0`:

- **buildTool**: maven.
- **javaVersion**: `properties.java.version`.
- **springBootVersion**: if `parent.artifactId == "spring-boot-starter-parent"`,
  read `parent.version`.
- **framework**: `spring-boot` if springBootVersion is set; else `none`.
- **mainDeps**: list of `dependencies.dependency.artifactId`.
- **testCommand**: `mvn test`.
- **buildCommand**: `mvn package`.
- **lintCommand**: not auto-detected in v1; manual override.
- **formatCommand**: not auto-detected in v1.

## Characterization (Gradle)

Grep `build.gradle` for `JavaVersion.VERSION_<N>` or `sourceCompatibility = "<N>"`.
Use a more complete Gradle parser in v2.

## Edge cases

- Multi-module Maven project (parent pom with `<modules>`): treat parent dir
  as root; collect modules as workspace entries.
- Gradle wrapper present (`gradlew`): prefer `gradlew` over `gradle` in commands.
```

- [ ] **Step 4: Write references/agent-compatibility.md**

```markdown
# Agent Compatibility Reference

This file documents which AI coding agents read which rule/context files.
The skill generates an `AGENTS.md` at the project root, which is intended
to be the canonical, agent-agnostic context source.

## AGENTS.md readers (native)

- Claude Code: reads `./AGENTS.md` and `./CLAUDE.md` (the latter wins if both exist).
- OpenAI Codex CLI: reads `./AGENTS.md`.
- Google Gemini CLI: reads `./AGENTS.md`.
- GitHub Copilot CLI: reads `./AGENTS.md`.
- Aider: reads `./AGENTS.md` and `.aider.conf.yml`.
- aider.chat conventions doc: https://aider.chat/docs/usage/conventions.html

## Tool-specific rule files (NOT modified by this skill)

- Claude Code: `./CLAUDE.md`, `~/.claude/CLAUDE.md`.
- Cursor: `.cursorrules`, `.cursor/rules`.
- Cline: `.clinerules`.
- Windsurf: `.windsurfrules`.
- GitHub Copilot (VS Code ext): `.github/copilot-instructions.md`.
- Aider: `.aider.conf.yml`.

The skill lists detected vendor rule files in `AGENTS_MIGRATION.md` so the
user can manually migrate content into the canonical `AGENTS.md`.

## Implications for SKILL.md

When generating `AGENTS.md`, follow the open spec at https://agents.md —
plain Markdown, no frontmatter required, sections are convention not standard.
The skill uses 13 sections (see `templates/sections/`).
```

- [ ] **Step 5: Write references/vendor-rules-inventory.md**

```markdown
# Vendor Rule File Inventory

Paths the skill scans for in `vendor-rules-scan.sh`:

| Path                          | Tool               |
|-------------------------------|--------------------|
| `.claude/CLAUDE.md`           | Claude Code        |
| `CLAUDE.md`                   | Claude Code        |
| `.cursorrules`                | Cursor             |
| `.cursor/rules`               | Cursor (multi-file)|
| `.clinerules`                 | Cline              |
| `.windsurfrules`              | Windsurf           |
| `.aider.conf.yml`             | Aider              |
| `.github/copilot-instructions.md` | GitHub Copilot |
| `AGENTS.md`                   | agents.md spec     |
| `GEMINI.md`                   | Gemini CLI         |

The skill reports these paths and line counts in `AGENTS_MIGRATION.md` but
**never reads their content into AGENTS.md**. The user reviews the report
and manually migrates sections if desired.

If you discover a new vendor rule path, add it to this table and to the
KNOWN array in `scripts/vendor-rules-scan.sh`.
```

- [ ] **Step 6: Write references/public-api-scanning.md**

```markdown
# Public API Scanning

The skill needs to know what counts as "public" in each language so it can
measure docstring coverage and (optionally) fill in missing docstrings.

## TypeScript / JavaScript (Node)

Public = exported symbol. Scan:

- `^export (async )?function NAME`
- `^export class NAME`
- `^export const NAME`
- `^export let NAME`
- `^export var NAME`
- `^export interface NAME`
- `^export type NAME`

Skip files under `node_modules`, `dist`, `build`, `.next`.

## Python

Public = top-level `def NAME` or `class NAME` at column 0, where NAME does
not start with `_`. Scan `.py` files; skip `.venv`, `__pycache__`.

## Java

Public = `public class NAME`, `public interface NAME`, or method declarations
starting with `public`. Scan `.java` files under `src/main/java`.

## Docstring detection

- TypeScript: a `/** ... */` block on the line(s) immediately preceding.
- Python: a `"""..."""` block on the line(s) immediately preceding.
- Java: a `/** ... */` block on the line(s) immediately preceding.

Coverage = (publicSymbols - undocumented) / publicSymbols.

## Threshold

Below 80% coverage, the gap-analyzer emits a `docstring-coverage` gap item.
```

- [ ] **Step 7: Write references/docstring-conventions.md**

```markdown
# Docstring Conventions

When the skill auto-fills missing docstrings on public API, it follows these
language-specific conventions.

## TypeScript (JSDoc)

```typescript
/**
 * Short description.
 *
 * Longer description if needed.
 *
 * @param paramName - description
 * @returns description
 * @throws description (if applicable)
 */
export function fnName(paramName: Type): ReturnType {
    ...
}
```

## Python (Google-style)

```python
def fn_name(param_name: Type) -> ReturnType:
    """Short description.

    Longer description if needed.

    Args:
        param_name: Description.

    Returns:
        Description.

    Raises:
        ExceptionType: Description.
    """
    ...
```

## Java (Javadoc)

```java
/**
 * Short description.
 *
 * <p>Longer description if needed.
 *
 * @param paramName description
 * @return description
 * @throws ExceptionType description
 */
public ReturnType fnName(Type paramName) {
    ...
}
```

## What the skill does NOT do

- Touch internal/private symbols.
- Modify function bodies or signatures.
- Add docstrings to test files (those are typically not part of public API).
- Generate docstrings with fabricated behavior descriptions — if the
  function's behavior is unclear from the name/signature alone, the skill
  asks the user instead of guessing.
```

- [ ] **Step 8: Commit**

```bash
git add skills/init-agents-md/references/
git commit -m "docs(init-agents-md): add reference docs for LLM consultation"
```

---

## Task 13: Section templates — 13 AGENTS.md sections

**Files:** Create all 13 section templates under `templates/sections/`.

- [ ] **Step 1: Write `templates/sections/01-overview.md`**

```markdown
## 1. 项目概览

{{overview}}

**读者**: {{audience}}
```

- [ ] **Step 2: Write `templates/sections/03-repository-layout.md`**

```markdown
## 3. 仓库布局

```
{{tree}}
```

**关键目录**:

{{directoryAnnotations}}
```

- [ ] **Step 3: Write `templates/sections/04-dev-environment.md`**

```markdown
## 4. 开发环境

- 语言运行时: {{runtimeVersion}}
- 包管理器: {{packageManager}}
- 安装依赖: `./scripts/setup.sh`
- 启动开发服务: `./scripts/dev.sh`
- 必需环境变量: {{envFiles}}
```

- [ ] **Step 4: Write `templates/sections/05-build-test.md`**

```markdown
## 5. 构建与测试

| 任务        | 命令                  |
|-------------|-----------------------|
| 类型检查    | `./scripts/typecheck.sh`  |
| 代码格式化  | `./scripts/format.sh`     |
| Lint        | `./scripts/lint.sh`       |
| 单元测试    | `./scripts/test.sh`       |
| 生产构建    | `./scripts/build.sh`      |

> 所有命令都通过 `scripts/*.sh` 包装；底层命令源自真实 manifest，不允许代理改动命令源。
```

- [ ] **Step 5: Write `templates/sections/06-architecture.md`**

```markdown
## 6. 架构概览

{{architecture}}

**核心模块**:

{{coreModules}}
```

- [ ] **Step 6: Write `templates/sections/07-code-conventions.md`**

```markdown
## 7. 代码规范

- Lint: {{linter}} ({{linterConfig}})
- 格式化: {{formatter}} ({{formatterConfig}})
- 类型检查: {{typeChecker}}
- 命名约定: {{namingConventions}}

**风格细节**:

{{styleNotes}}
```

- [ ] **Step 7: Write `templates/sections/08-database-external.md`**

```markdown
## 8. 数据库与外部服务

{{databaseSetup}}

**外部服务依赖**:

{{externalServices}}
```

- [ ] **Step 8: Write `templates/sections/09-pr-commit-workflow.md`**

```markdown
## 9. PR 与 Commit 流程

- 分支命名: {{branchNaming}}
- Commit 格式: {{commitFormat}}
- PR 标题: {{prTitleFormat}}
- 必需检查: {{requiredChecks}}
```

- [ ] **Step 9: Write `templates/sections/10-project-background.md`**

```markdown
## 10. 项目背景

{{background}}
```

- [ ] **Step 10: Write `templates/sections/11-forbidden-zones.md`**

```markdown
## 11. 禁区

以下区域/模式绝对不能改动,改动前请先与团队对齐:

{{forbiddenZones}}

> 任何对禁区的修改必须先在团队会议讨论并通过 PR review。
```

- [ ] **Step 11: Write `templates/sections/12-perf-security.md`**

```markdown
## 12. 性能与安全

**性能指引**:

{{performanceGuidelines}}

**安全注意**:

{{securityGuidelines}}
```

- [ ] **Step 12: Write `templates/sections/13-troubleshooting.md`**

```markdown
## 13. 故障排查

**常见问题**:

{{commonIssues}}

**调试技巧**:

{{debuggingTips}}
```

- [ ] **Step 13: Run tests to confirm render still works on a few templates**

Run:
```bash
bash skills/init-agents-md/tests/test_render_section.sh
```
Expected: PASS (no regression — only added files, didn't change render logic).

- [ ] **Step 14: Commit**

```bash
git add skills/init-agents-md/templates/sections/
git commit -m "feat(init-agents-md): add 13 AGENTS.md section templates"
```

---

## Task 14: Script templates — 7 command wrappers

**Files:** Create 7 shell-script templates.

- [ ] **Step 1: Write `templates/scripts/setup.sh.tmpl`**

```bash
#!/usr/bin/env bash
# setup.sh — install project dependencies
# Source: {{setup}} (commands.json)
# Generated by init-agents-md; do not edit unless you intend to fork from the skill.

set -euo pipefail
cd "$(dirname "$0")/.."

{{setup}}
```

- [ ] **Step 2: Write `templates/scripts/dev.sh.tmpl`**

```bash
#!/usr/bin/env bash
# dev.sh — start the development server
# Source: commands.json dev field
# Generated by init-agents-md.

set -euo pipefail
cd "$(dirname "$0")/.."

{{dev}}
```

- [ ] **Step 3: Write `templates/scripts/build.sh.tmpl`**

```bash
#!/usr/bin/env bash
# build.sh — produce a production build
# Source: commands.json build field
# Generated by init-agents-md.

set -euo pipefail
cd "$(dirname "$0")/.."

{{build}}
```

- [ ] **Step 4: Write `templates/scripts/test.sh.tmpl`**

```bash
#!/usr/bin/env bash
# test.sh — run the project's test suite
# Source: commands.json test field
# Generated by init-agents-md.

set -euo pipefail
cd "$(dirname "$0")/.."

{{test}}
```

- [ ] **Step 5: Write `templates/scripts/lint.sh.tmpl`**

```bash
#!/usr/bin/env bash
# lint.sh — run the configured linter
# Source: commands.json lint field
# Generated by init-agents-md.

set -euo pipefail
cd "$(dirname "$0")/.."

{{lint}}
```

- [ ] **Step 6: Write `templates/scripts/format.sh.tmpl`**

```bash
#!/usr/bin/env bash
# format.sh — apply the configured formatter
# Source: commands.json format field
# Generated by init-agents-md.

set -euo pipefail
cd "$(dirname "$0")/.."

{{format}}
```

- [ ] **Step 7: Write `templates/scripts/typecheck.sh.tmpl`**

```bash
#!/usr/bin/env bash
# typecheck.sh — run the type checker (only emitted for typed languages)
# Source: commands.json typecheck field
# Generated by init-agents-md.

set -euo pipefail
cd "$(dirname "$0")/.."

{{typecheck}}
```

- [ ] **Step 8: Commit**

```bash
git add skills/init-agents-md/templates/scripts/
git commit -m "feat(init-agents-md): add 7 command wrapper script templates"
```

---

## Task 15: Code templates — logger modules per language

**Files:** Create 3 logger templates.

- [ ] **Step 1: Write `templates/code/logger.ts.tmpl`**

```typescript
/**
 * logger.ts — unified logger (pino)
 * Generated by init-agents-md on {{date}}.
 *
 * Usage:
 *   import { logger } from "@/lib/logger";
 *   logger.info({ key: "value" }, "message");
 */

import pino from "pino";

const level = process.env.LOG_LEVEL ?? "info";

export const logger = pino({
    level,
    base: { service: process.env.SERVICE_NAME ?? "{{packageName}}" },
    timestamp: pino.stdTimeFunctions.isoTime,
});

export type Logger = typeof logger;
```

- [ ] **Step 2: Write `templates/code/logging.py.tmpl`**

```python
"""logging.py — unified logger (stdlib logging).

Generated by init-agents-md on {{date}}.

Usage:
    from src.logging import get_logger
    logger = get_logger(__name__)
    logger.info("message", extra={"key": "value"})
"""

import logging
import os
import sys
from typing import Any

_DEFAULT_LEVEL = os.environ.get("LOG_LEVEL", "INFO").upper()


def _configure() -> None:
    root = logging.getLogger()
    if root.handlers:
        return
    handler = logging.StreamHandler(sys.stderr)
    handler.setFormatter(
        logging.Formatter(
            fmt='{"ts":"%(asctime)s","level":"%(levelname)s","logger":"%(name)s","msg":%(message)s}',
            datefmt="%Y-%m-%dT%H:%M:%S%z",
        )
    )
    root.addHandler(handler)
    root.setLevel(_DEFAULT_LEVEL)


_configure()


def get_logger(name: str) -> logging.Logger:
    return logging.getLogger(name)
```

- [ ] **Step 3: Write `templates/code/LogConfig.java.tmpl`**

```java
package {{basePackage}}.config;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * LogConfig — SLF4J/Logback configuration helper.
 * Generated by init-agents-md on {{date}}.
 *
 * Set the LOG_LEVEL environment variable to control verbosity.
 */
public final class LogConfig {

    private LogConfig() {
        // utility class
    }

    public static Logger getLogger(Class<?> clazz) {
        return LoggerFactory.getLogger(clazz);
    }

    public static Logger getLogger(String name) {
        return LoggerFactory.getLogger(name);
    }
}
```

- [ ] **Step 4: Commit**

```bash
git add skills/init-agents-md/templates/code/
git commit -m "feat(init-agents-md): add logger templates for Node/Python/Java"
```

---

## Task 16: Docs templates — API docs skeletons

**Files:** Create 3 docs templates.

- [ ] **Step 1: Write `templates/docs/api-readme.md.tmpl`**

```markdown
# {{projectName}} — API Documentation

This directory documents the public API of `{{projectName}}`.

## Contents

- `openapi.yaml` — REST API specification (if applicable).
- `modules.md` — exported modules / functions (library projects).

## Generating up-to-date docs

After changing public API, regenerate this directory:

```bash
/path/to/regen-docs.sh
```

(or manually update the relevant file — see `AGENTS.md` §5.)
```

- [ ] **Step 2: Write `templates/docs/openapi-skeleton.yaml.tmpl`**

```yaml
openapi: 3.0.3
info:
  title: {{projectName}} API
  version: "0.1.0"
  description: |
    Auto-generated skeleton. Fill in paths and schemas as endpoints are added.
    Keep this file in sync with the actual API.
servers:
  - url: http://localhost:3000
    description: Local development

paths:
  # Add endpoints here. Example:
  # /healthz:
  #   get:
  #     summary: Health check
  #     responses:
  #       '200':
  #         description: OK
```

- [ ] **Step 3: Write `templates/docs/module-readme.md.tmpl`**

```markdown
# {{moduleName}}

{{moduleDescription}}

## Public API

{{publicApi}}

## Usage example

```{{language}}
{{usageExample}}
```
```

- [ ] **Step 4: Commit**

```bash
git add skills/init-agents-md/templates/docs/
git commit -m "feat(init-agents-md): add API documentation skeleton templates"
```

---

## Task 17: Report templates — migration + missing-items reports

**Files:** Create 2 report templates.

- [ ] **Step 1: Write `templates/migration-report.md.tmpl`**

```markdown
# AGENTS.md Migration Recommendations

Generated by init-agents-md on {{date}}.

The following vendor-specific rule files were detected in this project. They
were **NOT modified** — review the suggestions below and migrate content into
the canonical `AGENTS.md` when ready.

---

{{vendorEntries}}

---

After migrating content, you may delete the vendor rule files above. All
agents (Claude Code, Codex CLI, Gemini CLI, etc.) will read the canonical
`AGENTS.md` instead.
```

- [ ] **Step 2: Write `templates/missing-items-report.md.tmpl`**

```markdown
# AGENTS.md Missing Items Report

Generated by init-agents-md on {{date}}.

The following items were detected as missing in this project but were **NOT**
filled in this run (you can address them in future sessions or manually).

{{missingEntries}}

---

Re-run `/init-agents-md` after addressing these items, or use this report as
a checklist for incremental fixes.
```

- [ ] **Step 3: Commit**

```bash
git add skills/init-agents-md/templates/migration-report.md.tmpl skills/init-agents-md/templates/missing-items-report.md.tmpl
git commit -m "feat(init-agents-md): add migration and missing-items report templates"
```

---

## Task 18: SKILL.md — main orchestrator

**Files:** Create `skills/init-agents-md/SKILL.md`.

- [ ] **Step 1: Write SKILL.md frontmatter + body**

Write to `skills/init-agents-md/SKILL.md`:

```markdown
---
name: init-agents-md
description: Use when initializing or updating a project-level AGENTS.md file
  for AI coding agents (Claude Code, Codex CLI, Gemini CLI, GitHub Copilot CLI).
  Generates the AGENTS.md, command wrapper scripts under ./scripts/, and a
  migration recommendation report for existing vendor rule files. Also detects
  and proposes filling obvious gaps in project quality infrastructure (logger
  modules, public API docstrings, API docs skeletons).
---

# init-agents-md

Generate an authoritative `AGENTS.md` (plus `scripts/*.sh` wrappers, a
migration report, and optional quality fills) for a team project.

## When to invoke

Invoke when:

- A new project is being bootstrapped and needs an `AGENTS.md`.
- An existing project is being onboarded and the team wants a single
  canonical context file replacing per-tool vendor rule files.
- A previously generated `AGENTS.md` needs to be regenerated after the
  project has changed (commands, dependencies, scripts).

Do NOT invoke when:

- The project explicitly forbids automated documentation generation.
- The user only wants one section of AGENTS.md updated (use Edit directly).

## Inputs

- Optional: `--path <dir>` — generate into a specific directory (e.g., monorepo
  sub-package). Default: current working directory.
- Optional: `--import <file>` — point at a specific vendor rule file for
  detailed migration analysis. Default: auto-scan all known paths.

## Outputs

| Output                         | Always?  | Source                              |
|--------------------------------|----------|-------------------------------------|
| `AGENTS.md`                    | yes      | 13 sections, rendered from templates|
| `scripts/setup.sh` etc.        | yes      | 7 wrappers, commands from commands.json |
| `AGENTS_MIGRATION.md`          | yes      | vendor-rules-scan output            |
| `src/lib/logger.ts` etc.       | optional | user-approved gap-analyzer items    |
| Public API docstring fills     | optional | user-approved gap-analyzer items    |
| `docs/api/openapi.yaml` etc.   | optional | user-approved gap-analyzer items    |
| `AGENTS_MISSING.md`            | if any items unchecked | unchecked gap items |

## Workflow

Follow this exact sequence. Each step's output feeds the next.

### Step 1: Detect project type

```bash
PROJECT_DIR="${1:-$(pwd)}"
TYPE=$(bash skills/init-agents-md/scripts/detect.sh "$PROJECT_DIR")
```

If `unknown`, ask the user to confirm project type manually.

### Step 2: Run language-specific detection

```bash
case "$TYPE" in
    node)   DETECT=$(bash skills/init-agents-md/scripts/detect-node.sh "$PROJECT_DIR") ;;
    python) DETECT=$(bash skills/init-agents-md/scripts/detect-python.sh "$PROJECT_DIR") ;;
    java)   DETECT=$(bash skills/init-agents-md/scripts/detect-java.sh "$PROJECT_DIR") ;;
esac
```

Validate `DETECT` is valid JSON. If parsing fails, surface the error and stop.

### Step 3: Extract commands

```bash
CMDS=$(bash skills/init-agents-md/scripts/extract-commands.sh "$DETECT")
```

This is the **ground-truth** command list. Treat `CMDS` as authoritative;
do NOT invent commands elsewhere.

### Step 4: Scan public API + vendor rules

```bash
PUBLIC_API=$(bash skills/init-agents-md/scripts/public-api-scan.sh "$PROJECT_DIR")
VENDOR=$(bash skills/init-agents-md/scripts/vendor-rules-scan.sh "$PROJECT_DIR")
```

### Step 5: Read references (consult, don't quote)

Open and read the relevant reference doc for the detected language:

- Node → `references/node-detection.md`
- Python → `references/python-detection.md`
- Java → `references/java-detection.md`

Also read `references/agent-compatibility.md`, `references/public-api-scanning.md`.

Use these docs to guide inferences about framework, conventions, and
architecture — but always quote commands from `CMDS`, never invent.

### Step 6: Q&A

Ask the user three questions (use AskUserQuestion). All are skippable
(Enter → use empty default).

**Q1 — 项目目标与读者**:
> 一句话描述这个项目是干什么的、解决什么问题、给谁用？

**Q2 — 禁区**:
> 有哪些区域/文件/模式是代理绝对不能碰或必须小心的？（每条一句话说原因）

**Q3 — PR / Commit 流程**:
> PR 标题、分支命名、Commit 消息有没有强制规范？CI 失败能合并吗？

Save the answers as `USER_INPUT.json` for later steps.

### Step 7: Infer architecture

Read `$PROJECT_DIR/README.md` (if present) and the top-level directory tree.
Generate a 2–4 paragraph architecture overview suitable for §6. List the
3–5 most important modules with one-line annotations.

### Step 8: Gap analysis

```bash
GAP=$(bash skills/init-agents-md/scripts/gap-analyzer.sh "$DETECT" "$PUBLIC_API" "$PROJECT_DIR")
```

Surface the checklist to the user via AskUserQuestion (multi-select).
Items not selected go into `AGENTS_MISSING.md`.

### Step 9: Render AGENTS.md sections

For each of the 13 sections, build a JSON data object (combining detect
output, user Q&A, inferred architecture, gap analysis), then render the
template:

```bash
bash skills/init-agents-md/scripts/render-section.sh \
    skills/init-agents-md/templates/sections/01-overview.md \
    <(echo '{"overview":"...","audience":"..."}')
```

Concatenate the 13 rendered sections, prefixed by an audit metadata comment:

```markdown
<!-- Generated by init-agents-md on <date>.
     Source: detect.json sha256:<hash>. Re-run with /init-agents-md. -->

# <project-name>

<all 13 sections in order>
```

### Step 10: Render scripts/*.sh

For each of the 7 script templates, substitute the corresponding field from
`CMDS`:

```bash
for script in setup dev build test lint format typecheck; do
    # Substitute {{<script>}} with CMDS.<script>
done
```

Make scripts executable:

```bash
chmod +x scripts/*.sh
```

### Step 11: Render migration + missing reports

Render `templates/migration-report.md.tmpl` with `VENDOR` data → `AGENTS_MIGRATION.md`.
Render `templates/missing-items-report.md.tmpl` with unchecked gap items → `AGENTS_MISSING.md`.

### Step 12: Dry-run validation

```bash
for s in scripts/*.sh; do
    bash skills/init-agents-md/scripts/dry-run-validate.sh "$s"
done
```

If any check fails, surface the failure to the user and stop.

### Step 13: Diff vs existing AGENTS.md (if present)

If `AGENTS.md` already exists, generate a per-section diff. Use
AskUserQuestion to ask the user per section: keep, overwrite, or merge.

### Step 14: Backup & write

```bash
[ -f AGENTS.md ] && cp AGENTS.md AGENTS.md.bak
[ -d scripts ] && cp -r scripts scripts.bak
```

Write the new files. **Do NOT auto-commit or auto-push.**

### Step 15: Summary

Print:

- Files created.
- Migration report excerpt.
- Number of missing items.
- Validation result.

## Rules

- **Never invent commands.** Every command in `AGENTS.md` and `scripts/*.sh`
  must come from `CMDS` (extracted from real manifest fields).
- **Never modify existing vendor rule files.** Only emit migration report.
- **Never auto-commit or auto-push.** Files are written; commit is up to the user.
- **Always backup** before overwriting `AGENTS.md` or `scripts/`.
- **Only touch public API** for docstring fills. Never modify internal code.
```

- [ ] **Step 2: Commit**

```bash
git add skills/init-agents-md/SKILL.md
git commit -m "feat(init-agents-md): add SKILL.md orchestrator"
```

---

## Task 19: Worked example

**Files:** Create complete example outputs.

- [ ] **Step 1: Create `examples/sample-output/AGENTS.md`**

This is a static example file demonstrating what the skill produces.
Fill in realistic content for a fictional pnpm + Next.js project called
"acme-web". Reference the section templates in `templates/sections/`.

The file should be ~200 lines and cover all 13 sections with concrete
content. Save as `examples/sample-output/AGENTS.md`.

- [ ] **Step 2: Create `examples/sample-output/scripts/test.sh`**

```bash
#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
# Commands sourced from package.json scripts.test (vitest run)
vitest run
```

- [ ] **Step 3: Create `examples/sample-output/scripts/dev.sh`**

```bash
#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
next dev
```

- [ ] **Step 4: Create `examples/sample-output/scripts/build.sh`, `lint.sh`, `format.sh`, `typecheck.sh`, `setup.sh`**

One file per script, each with the appropriate command. Use the section
templates in Task 14 as the shape.

- [ ] **Step 5: Create `examples/sample-output/AGENTS_MIGRATION.md`**

A realistic example showing what the migration report looks like when
`.claude/CLAUDE.md` is detected.

- [ ] **Step 6: Create `examples/sample-output/AGENTS_MISSING.md`**

A realistic example showing what the missing items report looks like
when logger and CI are detected as gaps.

- [ ] **Step 7: Commit**

```bash
git add skills/init-agents-md/examples/
git commit -m "docs(init-agents-md): add worked example outputs"
```

---

## Task 20: Integration test — run on fixtures, verify outputs

**Files:** Create `tests/test_integration.sh`. This is the highest-level
test: run the full pipeline on each fixture and verify the expected
output shape.

- [ ] **Step 1: Write the integration test**

Write to `skills/init-agents-md/tests/test_integration.sh`:

```bash
#!/usr/bin/env bash
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
```

- [ ] **Step 2: Run the integration test**

Run: `bash skills/init-agents-md/tests/test_integration.sh`
Expected: All assertions PASS for all three languages.

- [ ] **Step 3: Run the full test suite**

Run: `bash skills/init-agents-md/tests/run.sh`
Expected: All `test_*.sh` files PASS. Exit code 0.

- [ ] **Step 4: Commit**

```bash
git add skills/init-agents-md/tests/test_integration.sh
git commit -m "test(init-agents-md): add end-to-end integration test"
```

---

## Self-Review Notes (run after writing the plan)

- **Spec coverage**:
  - §6 Architecture → Task 18 (SKILL.md)
  - §7 Components → Tasks 2-11 (scripts), 12 (references), 13-17 (templates)
  - §8 Outputs → Tasks 13 (sections), 14 (scripts), 15 (logger), 16 (docs), 17 (reports), 18 (orchestration), 19 (examples)
  - §9 Workflow steps 1-15 → Task 18 (SKILL.md sections numbered 1-15)
  - §10 Detection schemas → Tasks 3, 4, 5 (one per language)
  - §11 Templates → Tasks 13, 14, 15, 16, 17
  - §12 AI-Judgment → Task 9 (gap-analyzer) + Task 18 step 8
  - §13 Validation → Task 11 (dry-run-validate) + Task 18 step 12
  - §14 Error handling → Task 18 SKILL.md rules
  - §15 Installation → outside scope (user-side install via symlink)
  - §16 YAGNI → not violated; Go/Rust/Ruby excluded
- **Placeholder scan**: Each task has concrete file paths, code, commands, expected output. No TBD/TODO/"implement later".
- **Type consistency**: `CMDS` shape used uniformly across Task 6 (definition), Tasks 9/10 (consumers), Task 18 (orchestration). Same for `DETECT`, `PUBLIC_API`, `GAP`, `VENDOR`.
- **Order dependencies**: Each commit leaves the project in a working state. Tasks 2-11 are independent of each other except Task 6 depends on Tasks 3/4/5 (only at integration time). Templates (Tasks 13-17) don't depend on scripts except via Task 20's integration test.