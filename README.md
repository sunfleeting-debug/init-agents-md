<div align="center">
  <img src=".github/assets/icon.png" width="108" alt="init-agents-md" />
  <h1>init-agents-md</h1>
  <p><b>一条命令为项目生成权威的 AGENTS.md</b><br /><sub>顺带产出脚本包装、迁移报告，并把项目质量基建的明显缺口列出来</sub></p>
  <p>
    <img src="https://img.shields.io/badge/Claude%20Code-Skill-D97757" alt="Claude Code Skill">
    <img src="https://img.shields.io/badge/%E5%85%BC%E5%AE%B9-Codex%20%7C%20Gemini%20%7C%20Copilot-5F5E5A" alt="兼容 Codex / Gemini / Copilot CLI">
    <img src="https://img.shields.io/badge/%E8%AF%86%E5%88%AB-Node%20%7C%20Python%20%7C%20Java-0C447C" alt="识别 Node / Python / Java">
    <img src="https://img.shields.io/badge/Shell-%E6%B5%8B%E8%AF%95%E5%A5%97%E4%BB%B6-4EAA25" alt="Shell 测试套件">
  </p>
  <p>
    <b>简体中文</b> ·
    <a href="README.en.md">English</a>
  </p>
</div>

一个 Claude Code **Skill**：在项目里跑 `/init-agents-md`，它会读你的项目、生成一份权威的 `AGENTS.md`，用来统一 **Claude Code / Codex CLI / Gemini CLI / GitHub Copilot CLI** 的行为 —— 把散落在各家工具里的规则文件收敛成一份单一事实源。

## 一览

| | |
| --- | --- |
| **形态** | Claude Code Skill（`skills/init-agents-md/SKILL.md`） |
| **主要产物** | `AGENTS.md`（13 个章节，由模板渲染） |
| **附带产物** | `scripts/*.sh` 7 个命令包装 · `AGENTS_MIGRATION.md` 迁移报告 · `AGENTS_MISSING.md` 缺口清单 |
| **可选补齐** | 经你确认后：logger 模块、公开 API docstring、`docs/api/openapi.yaml` 骨架 |
| **识别栈** | Node / Python / Java（各自的探测脚本 + 参考文档） |
| **许可** | 未附带开源许可（见文末） |

---

## ✨ 它做什么

```text
/init-agents-md
      │
      ├─ 探测技术栈        detect-{node,python,java}.sh
      ├─ 抽取项目命令      extract-commands.sh   → 渲染 scripts/*.sh 包装
      ├─ 渲染 AGENTS.md    13 个 section 模板
      ├─ 扫描既有规则文件  vendor-rules-scan.sh  → AGENTS_MIGRATION.md
      └─ 缺口分析          gap-analyzer.sh       → AGENTS_MISSING.md（可选补齐）
```

- **`AGENTS.md`（13 节）**：概览、技术栈、仓库结构、开发环境、构建测试、架构、代码规范、数据库/外部依赖、PR 与提交流程、项目背景、禁区、性能与安全、故障排查。
- **`scripts/*.sh`**：从项目真实命令抽取出的 7 个包装脚本（`setup` / `dev` / `build` / `test` / `lint` / `format` / `typecheck`），让「怎么跑」有唯一出处。
- **迁移报告**：把已有的 `.cursorrules` / `CLAUDE.md` 之类**按厂商分散的规则文件**盘点出来，给出合并建议。
- **缺口分析（可选）**：发现项目缺 logger、公开 API 缺 docstring、缺 API 文档骨架时**先问再补**，不会擅自改你的代码。

---

## 📦 安装

把 skill 目录放进 Claude Code 的 skills 目录即可：

```bash
git clone https://github.com/sunfleeting-debug/init-agents-md.git
cp -r init-agents-md/skills/init-agents-md ~/.claude/skills/
```

（也可放到项目级 `.claude/skills/` 下，只对当前仓库生效。）

---

## 🚀 使用

```bash
# 在当前目录生成 AGENTS.md
/init-agents-md

# 生成到指定目录（例如 monorepo 的子包）
/init-agents-md --path ./packages/web

# 指定某份厂商规则文件做详细迁移分析
/init-agents-md --import ./.cursorrules
```

生成的 `scripts/*.sh` 与 `AGENTS.md` 都按项目实际命令渲染，不是通用模板。

---

## 🧪 测试

skill 自带一套 shell 测试（含 Node / Python / Java 三种 fixture 项目）：

```bash
bash skills/init-agents-md/tests/run.sh
```

覆盖探测、命令抽取、章节渲染、厂商规则扫描、缺口分析与 dry-run 校验。

---

## 📁 目录结构

```text
skills/init-agents-md/
├── SKILL.md                  skill 主文件（触发条件、输入输出、工作流）
├── scripts/                  探测 / 抽取 / 渲染 / 扫描 / 缺口分析（shell）
├── templates/
│   ├── sections/             13 个 AGENTS.md 章节模板
│   ├── scripts/              7 个命令包装模板
│   ├── code/                 logger 模板（TS / Java / Python）
│   └── docs/                 API / 模块 README 骨架模板
├── references/               各语言探测说明、兼容性矩阵、docstring 约定
├── examples/sample-output/   一份完整示例产物（可直接对照）
└── tests/                    shell 测试 + fixture 项目
```

---

## 📄 许可

本仓库**暂未附带开源许可协议**。如需转载或复用其中的模板与脚本，请先联系作者。
