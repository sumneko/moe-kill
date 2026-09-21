# Proposal

## Why

「人真的会死」已经落地（濒死结算 + `'玩家-死亡'` 时机），但死后**什么都不会发生**：

1. **没人判胜负**：`package/身份场/` 只管发身份与抬主公体力，没有任何胜负判定。
2. **流程不会停**：`package/@基础/回合.lua` 的流程只以「场上还剩一个存活角色」结束 —— 主公死后若场上还剩 2 人（反贼 + 内奸），回合会一直转下去。
3. **没有结果可交**：装配侧 / 会话层拿不到「谁赢了」，前端无从知道这局结束；而且游戏结束后**还在起新的结算**（多目标【杀】打死主公后，下一个目标照样被结算）。

官方口径（见 `sanguosha-rules` §2）：主公 + 忠臣 = 消灭所有反贼与内奸；反贼 = 杀死主公（主公死亡时即使反贼已全灭仍算反贼胜）；内奸 = 成为最后的存活者（内奸与反贼同归于尽时反贼胜）。

## What Changes

- **内核给出「结束这一局」与「结果」**（`server/core/game.lua`）：
  - `game:endGame(result)`：**幂等**（只认第一次）；记下结果 → 触发 **`'游戏-结束'`**（上下文 = 那个结果）→ **停掉这一局的流程任务**。
  - `game:getResult()`：这一局的结果；还没结束就是「不存在」。
  - 结果类型 `Game.Result` = `{ side, reason }` —— `side` 取官方术语 `'主公方'` / `'反贼'` / `'内奸'`，`reason` 是给人看的中文短句（前端可直接显示）。
- **`runFlow()` 记住流程任务**（`Game.flowTask`）：`endGame` 靠它把流程就地收掉（挂起中的协程会被 `Task:cancel()` 关掉，见 design D2）。
- **结束后不再起新的结算**（`server/core/effect/init.lua`）：`Effect:apply()` 开头查一次结果，已结束 ⇒ 这次生效以「取消」收尾（不算失败、没有结果）。于是多目标【杀】打死主公后不会再结算下一个目标，已记账但还没起的濒死也不会再起。
- **规则侧新增 `package/身份场/胜负.lua`**：订阅 `'玩家-死亡'`，按官方口径判胜负 → `game:endGame { ... }`。
- **时机清单**：`env-meta.lua` 补 `'游戏-结束'` 的 `on` / `fire`（上下文 = `Game.Result`）。
- 用例：`core/game-over`（内核：结果 / 幂等 / 停流程 / 不再起结算）+ `rule/game-over`（身份场：主公方胜 / 反贼胜 / 内奸胜 / 打完就停）。

**明确不做**（留给后续功能点，按需就地补）：

- **死亡奖惩**（杀反贼摸 3 张、主公杀忠臣弃牌）：官方顺序是「死亡 → 奖惩 → 胜负判定」，将来写在同一个时机上、**注册在胜负判定之前**即可，内核不用动。
- **再开一局**（用户 2026-09-21 定）：将来做法是**重新建一个 `Game` 实例**，不是重置当前局；重载规则也不清已定的结果。
- 游戏结束时的收尾清理（取消所有已发起、还在跑的结算）：本批只做「不再起新的」。

## Capabilities

### New Capabilities

- （无）

### Modified Capabilities

- （无）

> 探索期不写规格（`.openspec.yaml` 设 `skip_specs: true`）：契约由用例承担 —— `--test core.game-over` / `rule.game-over`。

## Impact

- 新增：`package/身份场/胜负.lua`、`server/test/core/game-over.lua`、`server/test/rule/game-over.lua`
- 改动：`server/core/game.lua`（`endGame` / `getResult` / `flowTask` / `runFlow`）、`server/core/effect/init.lua`（结束后不再起结算）、`server/core/loader/env-meta.lua`（`'游戏-结束'`）、`server/test.lua`（登记套件）
- 文档：`sanguosha-rules` §2 / §7 / §9（「奖惩与胜负判定还没做」改成实际状态）、`moe-kill-dev` 的 `architecture.md`（结束口径 + 「再开一局 = 新建 Game 实例」）、`infrastructure.md`（新套件命令）
- 行为不变：没结束的对局一切照旧（`getResult()` 为空 ⇒ 所有新增检查都是空操作）
