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
