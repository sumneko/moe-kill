# Tasks

## 1. 内核：伤害对象

- [x] 1.1 新增 `server/core/damage.lua`：`Damage` 类（公开字段 `game` / `from` / `to` / `amount`）+ `Damage.CreateOptions` 类型 + `Damage.create(options)` 工厂 + `Damage:apply()`（触发「伤害-前」→ 目标体力减点数 → 触发「伤害-后」）。验证：`--test core.damage` 用例通过
- [x] 1.2 `server/core/init.lua` 挂 `moe.damage`；`server/moe-kill.lua` 的类型注解补上它。验证：问题面板 information 及以上为 0
- [x] 1.3 `server/core/game.lua`：`game:damage(from, to, amount)` 改成便利入口（`moe.damage.create { game = self, from = from, to = to, amount = amount }:apply()`）。验证：既有 `--test rule.slash` 不改一行仍通过
- [x] 1.4 `server/core/loader/env-meta.lua`：伤害时机的上下文改成 `Damage`（撤掉 `Game.EventCtx.伤害`），并按名收窄的重载同步。验证：问题面板 0

## 2. 测试

- [x] 2.1 `server/test/core/damage.lua` 补用例：建实例先不结算则体力不变、`:apply()` 之后才扣、`:apply()` 幂等性以外的重复结算照常再扣、两个时机收到**同一个**实例、`game:damage(...)` 与手写两步等价。验证：`--test core.damage` 全绿
- [x] 2.2 全量 `server\bin\moe-kill.exe --test` 0 失败；问题面板 information 及以上为 0

## 3. 文档与验收

- [x] 3.1 文档同步：`moe-kill-dev` 的 `architecture.md` 第 12 节（伤害改成对象、门面加 `moe.damage`）、`sanguosha-rules/SKILL.md` §7（伤害实例的形状）
- [x] 3.2 `openspec validate --all --strict` 全通过；勾完任务 → 提交推送 → 归档 → 再提交推送
