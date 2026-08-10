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
