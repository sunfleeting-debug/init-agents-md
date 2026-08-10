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
