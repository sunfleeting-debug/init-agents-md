<div align="center">
  <img src=".github/assets/icon.png" width="108" alt="init-agents-md" />
  <h1>init-agents-md</h1>
  <p><b>Generate an authoritative AGENTS.md for any project, in one command</b><br /><sub>Plus command wrappers, a migration report, and a list of obvious gaps in your project's quality infrastructure</sub></p>
  <p>
    <img src="https://img.shields.io/badge/Claude%20Code-Skill-D97757" alt="Claude Code Skill">
    <img src="https://img.shields.io/badge/works%20with-Codex%20%7C%20Gemini%20%7C%20Copilot-5F5E5A" alt="Works with Codex / Gemini / Copilot CLI">
    <img src="https://img.shields.io/badge/detects-Node%20%7C%20Python%20%7C%20Java-0C447C" alt="Detects Node / Python / Java">
    <img src="https://img.shields.io/badge/Shell-test%20suite-4EAA25" alt="Shell test suite">
  </p>
  <p>
    <a href="README.md">简体中文</a> ·
    <b>English</b>
  </p>
</div>

A Claude Code **Skill**: run `/init-agents-md` in a project and it reads the codebase, then generates an authoritative `AGENTS.md` that standardizes how **Claude Code / Codex CLI / Gemini CLI / GitHub Copilot CLI** behave — collapsing per-vendor rule files into a single source of truth.

## At a glance

| | |
| --- | --- |
| **Shape** | Claude Code Skill (`skills/init-agents-md/SKILL.md`) |
| **Primary output** | `AGENTS.md` (13 sections, rendered from templates) |
| **Also produces** | `scripts/*.sh` (7 command wrappers) · `AGENTS_MIGRATION.md` · `AGENTS_MISSING.md` |
| **Optional fills** | With your approval: a logger module, public-API docstrings, a `docs/api/openapi.yaml` skeleton |
| **Detects** | Node / Python / Java (per-language detection scripts + references) |
| **License** | None attached (see below) |

---

## ✨ What it does

```text
/init-agents-md
      │
      ├─ detect the stack        detect-{node,python,java}.sh
      ├─ extract commands        extract-commands.sh  → render scripts/*.sh wrappers
      ├─ render AGENTS.md        13 section templates
      ├─ scan existing rules     vendor-rules-scan.sh → AGENTS_MIGRATION.md
      └─ gap analysis            gap-analyzer.sh      → AGENTS_MISSING.md (optional fills)
```

- **`AGENTS.md` (13 sections)**: overview, tech stack, repository layout, dev environment, build & test, architecture, code conventions, database/external deps, PR & commit workflow, project background, forbidden zones, performance & security, troubleshooting.
- **`scripts/*.sh`**: seven wrappers (`setup` / `dev` / `build` / `test` / `lint` / `format` / `typecheck`) extracted from the project's real commands, so "how to run it" has exactly one home.
- **Migration report**: inventories existing per-vendor rule files (`.cursorrules`, `CLAUDE.md`, …) and recommends how to consolidate them.
- **Gap analysis (optional)**: when it finds a missing logger, undocumented public APIs or no API-docs skeleton, it **asks first** — it never edits your code unilaterally.

---

## 📦 Install

Drop the skill folder into Claude Code's skills directory:

```bash
git clone https://github.com/sunfleeting-debug/init-agents-md.git
cp -r init-agents-md/skills/init-agents-md ~/.claude/skills/
```

(Or place it under a project's `.claude/skills/` to scope it to that repo only.)

---

## 🚀 Use

```bash
# generate AGENTS.md in the current directory
/init-agents-md

# generate into a specific directory (e.g. a monorepo sub-package)
/init-agents-md --path ./packages/web

# point at a specific vendor rule file for detailed migration analysis
/init-agents-md --import ./.cursorrules
```

Both the generated `scripts/*.sh` and `AGENTS.md` are rendered from the project's actual commands — not generic boilerplate.

---

## 🧪 Tests

The skill ships a shell test suite (with Node / Python / Java fixture projects):

```bash
bash skills/init-agents-md/tests/run.sh
```

It covers detection, command extraction, section rendering, vendor-rule scanning, gap analysis and dry-run validation.

---

## 📁 Repository layout

```text
skills/init-agents-md/
├── SKILL.md                 the skill itself (triggers, inputs/outputs, workflow)
├── scripts/                 detection / extraction / rendering / scanning / gap analysis (shell)
├── templates/
│   ├── sections/            13 AGENTS.md section templates
│   ├── scripts/             7 command-wrapper templates
│   ├── code/                logger templates (TS / Java / Python)
│   └── docs/                API / module README skeletons
├── references/              per-language detection notes, compatibility matrix, docstring conventions
├── examples/sample-output/  a complete example output to compare against
└── tests/                   shell tests + fixture projects
```

---

## 📄 License

This repository **does not currently ship an open-source license**. If you want to republish or reuse the templates and scripts, please contact the author first.
