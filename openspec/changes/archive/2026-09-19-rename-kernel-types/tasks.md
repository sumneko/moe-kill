# Tasks

## 1. 代码改名

- [x] 1.1 批量删掉 Lua 文件里的字面量 `Moe.`（`server/**`，跳过 `server/tools/` 与 `server/tmp/`）：覆盖类型注解、`Class 'X'` / `New 'X'` / `Extends 'X'` 字符串、`loader/env-meta.lua` 里注入环境与各时机上下文的类型名。验证：`grep -r 'Moe\.'`（区分大小写）在 `server/`（除 tools/tmp）为 0
- [x] 1.2 逐文件 review diff：确认没有非类型的字符串被误改（错误消息、日志、探针内容），`MoeKill`（无点）没被碰到
- [x] 1.3 验证：全量 `--test` 0 失败；问题面板 information 及以上为 0（重点确认 `Card` 类型与加载期环境函数 `Card` 共存无诊断、`New`/`Extends` 的类名字符串与注解仍对得上）

## 2. 规格与文档

- [x] 2.1 直接编辑主规格的 Purpose：`openspec/specs/core-game/spec.md`（`Moe.Game` → `Game`）与 `openspec/specs/kernel-facade/spec.md`（改成新规则，顺带修掉 Purpose 里过期的 `moe.room` / `moe.rule` / 注入 `rule` 表述）
- [x] 2.2 `.agents/skills/**` 里的类型引用同步（`moe-kill-dev` 的 `architecture.md` / `code-style.md` / `infrastructure.md` / `SKILL.md`、`sanguosha-rules/SKILL.md`），并把「类型名统一 `Moe.` 前缀」的表述改成新规则

## 3. 验收与归档

- [x] 3.1 全量测试 0 失败、问题面板 information 及以上为 0、`openspec validate --all --strict` 全通过
- [x] 3.2 勾完任务 → 提交推送 → 归档（`openspec archive rename-kernel-types --yes`）→ 再提交推送
