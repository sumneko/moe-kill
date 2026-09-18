# AGENTS.md — 项目入口（AI 助手必读）

本文件是本仓库 AI 助手的统一入口（厂商中立，任何 AI 客户端均可读取）：新会话请先阅读本文件，再按 OpenSpec 工作流开展需求规划与实现。

本项目的规格与技能以通用格式落盘，不依赖任何特定客户端：规格位于 `openspec/`，技能位于 `.agents/skills/`（通用 Agent Skills 格式）。

## 项目简介

- 名称：`moe-kill`
- 状态：初始化阶段（技术栈与玩法细节待补充，随项目推进更新本节）
- 文档与工件语言：简体中文（见 `openspec/config.yaml` 的 `context` 字段）

## 目录结构

| 路径 | 说明 |
| ---- | ---- |
| `openspec/specs/` | 规格真相源（系统当前行为；归档变更时同步更新） |
| `openspec/changes/` | 进行中的变更（proposal / specs / design / tasks） |
| `openspec/changes/archive/` | 已归档变更（保留历史） |
| `openspec/config.yaml` | OpenSpec 项目配置（语言、工件规则、操作指引） |
| `.agents/skills/openspec-*/` | 厂商中立技能（通用 Agent Skills 格式，任何客户端可加载；由 OpenSpec 生成，勿手改） |
| `.github/` | GitHub 平台目录（当前为空，预留 CI 工作流 / issue 模板等） |

## 工作流（OpenSpec / OPSX）

先规划、后实现。遵循"规划边界"：除非用户明确进入实施阶段，否则只创建规划工件，不直接改业务代码。

| 场景 | 通用调用（技能名，任意客户端） |
| ---- | ---- |
| 提出新变更（一步生成 proposal / specs / design / tasks） | `/openspec-propose` |
| 探索与讨论（无副作用的思考伙伴） | `/openspec-explore` |
| 按 `tasks.md` 实施变更 | `/openspec-apply-change` |
| 更新已有变更的工件 | `/openspec-update-change` |
| 将变更的 spec 增量同步进主规格 | `/openspec-sync-specs` |
| 归档已完成变更 | `/openspec-archive-change` |

- 技能文件位于 `.agents/skills/openspec-*/SKILL.md`，为通用 Agent Skills 格式；客户端可自动激活，不支持斜杠调用时直接提及技能名即可。
- 终端中等价操作：`openspec new change`、`openspec status`、`openspec instructions`、`openspec validate`、`openspec archive`。
- 本仓库不含任何厂商专属目录；`openspec update` 目前只维护 `agents` 一个目标。

**接入新客户端**：运行 `openspec init --tools <tool-id> --no-copilot-cloud` 可添加指定客户端集成（如 `github-copilot`、`claude`、`cursor`、`codex`；工具 ID 见 `openspec init --help`）。例如为 GitHub Copilot 生成 `/opsx-propose` 等斜杠命令：`openspec init --tools github-copilot`；`.agents/skills/` 与 `openspec/` 规格数据对所有客户端始终可用，无需重复配置。

## 项目约定

- 变更目录名使用小写 kebab-case（如 `add-battle-loop`，允许数字前缀如 `100-xxx`）。
- 工件正文使用简体中文；OpenSpec 结构性标题与 `SHALL` / `MUST` 关键词保持英文。
- 归档前先运行 `openspec validate <name>` 校验；实现完成后勾选 `tasks.md` 全部条目，再执行 `openspec archive <name> --yes`。
- `.agents/skills/` 下由 OpenSpec 生成的文件不要手动修改；升级 CLI 后运行 `openspec update` 刷新。
- 重大需求/架构调整先建变更提案，经确认后再写代码。

## 环境注意（Windows / PowerShell）

- 本机 PowerShell 执行策略禁止运行 `.ps1` 脚本：npm 请使用 `npm.cmd`，openspec 请使用 `openspec.cmd`。
- 前置依赖：Node.js ≥ 20.19.0（OpenSpec CLI 要求）。

## 常用命令速查

```bash
openspec list                     # 查看进行中的变更
openspec list --specs             # 查看已有规格
openspec show <name>              # 查看变更/规格详情
openspec status --change <name>   # 查看工件完成度
openspec validate --all           # 全量校验变更与规格
openspec archive <name> --yes     # 归档已完成的变更
openspec update                   # 升级 CLI 后刷新所有客户端集成文件
```
