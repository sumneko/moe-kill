# Proposal

## Why

用户 2026-09-21 指出：**游戏流程不该是 Effect**。核实结果比"不合适"更糟 —— `Flow : Effect` 走 `Effect:apply()` ⇒ 它是根效果，于是**从 `runFlow()` 那一刻起，局上的记牌器里唯一的一条就是 flow**：`game:getEffect()` 永远返回 flow、`getEffects()` 永远只有它一条，之后所有真结算（伤害 / 用牌 / 濒死）都成了它的子效果，按"只记根效果"的规则根本不进记牌器。**记牌器等于废了。**

而且流程本来就不是一次"结算"：它没有 `'即将生效'`（不该被取消 / 替换），也没有伤害那种"点数与来源"的语义 —— 用 Effect 只是顺手拿到了 `await` 与 `remove`。

## What Changes

- `game:runFlow()` 改成返回一个 **Task**（`moe.task`）：等它 = `task:await()`、结果 / 失败 = `task.result` / `task.err`、停它 = 新加的 **`task:cancel()`**。
- `server/tools/task.lua` 新增 `Task:cancel()`：`reject(CANCELED)` 收尾（`reject` 本来就会 `Delete` 掉、顺带关掉挂着的执行体）—— 与效果侧的取消同一口径（`.err` = `canceled`）。
- **`Flow : Effect` 退休**：删 `server/core/flow.lua`、`server/core/init.lua` 去掉 `include 'core.flow'`；`game:registerFlow(handler)` 与「加载期登记、装配侧启动」这套不动。
- 连带修好：从此**根效果就是真结算**，`game:getEffect()` / `getEffects()` 恢复意义（`Effect.parent` 对根结算为「不存在」）。
- 用例：`test/rule/flow.lua`（4 处）与 `test/rule/turn.lua`（2 处）改用 Task API；`ltest.assertFailed` 的注解从 `Effect` 放成 `Effect|Task`。
- 文档：`architecture.md` §12 两处、`sanguosha-rules` §9.2 一处、`infrastructure.md` 的 `task.lua` 行。

**MUST NOT 改**：流程的登记与启动时机、内容侧写法（`game:registerFlow`）、回合流程本身、`'游戏-开始'` 的触发。

## Capabilities

### New Capabilities

- （无）

### Modified Capabilities

- （无）

> 探索期不写规格（`.openspec.yaml` 设了 `skip_specs: true`）：契约由用例承担 —— `--test rule.flow` / `rule.turn`，以及新加的一条「记牌器里只有真结算」。

## Impact

- 改动：`server/core/game.lua`（`runFlow`）、`server/tools/task.lua`（`cancel`）、`server/core/init.lua`、`server/test/rule/{flow,turn}.lua`、`server/test/ltest.lua`（注解）、3 份技能文档
- 删除：`server/core/flow.lua`（已与用户确认：`Flow : Effect` 与 `moe.flow` 一起退休）
- 不改：`package/**`（内容侧只用 `game:registerFlow`，感知不到这次变化）
