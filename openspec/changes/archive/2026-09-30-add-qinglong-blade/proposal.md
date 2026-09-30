# Proposal

## Why

装备技能按「一张牌一个功能点」推进到第七张。【青龙偃月刀】只有定义（武器 / 攻击范围 3），「被【闪】抵消时再对其使用一张【杀】」未实现。它带出一条**内核能力**（有明确的首用消费者，不是提前设计）：

| 缺口 | 谁在用 |
| --- | --- |
| 「这次使用」缺一组放行 / 记账开关：无视距离 / 不受次数限制 / 不计入次数 | 【青龙偃月刀】的追加【杀】（用户 2026-09-30 定：三件事分开，不做「加一次机会」的账本手术） |
| 「杀被闪抵消」的判定点 | 【青龙偃月刀】（用既有 `'卡牌-答复后'` 近似，零内核改动） |

## What Changes

- **内核新表 `Game.UseOptions`**（`game:useCard` / `game:askUseCard` 的第 4 个参数；`UseCard.useOptions` / `AskUseCard.useOptions` 各存一份；`canUse` 透传）：
  - `ignoreDistance` —— 内核把选项**随 `'获取目标'` 的回调传下去**（第 2 个参数）；射程判断走 **`Player:isInRange(对方, 范围, 选项)`**、**认它直接算在**（`distance` 保持诚实；【杀】把选项喂给 `isInRange`；顺手牵羊 / 借刀杀人等有消费者时跟）；
  - `ignoreUseLimit` —— `checkCardItself` **跳过次数上限检查**；
  - `notCounted` —— `UseCard:settle` **不写 `useCount`**（不计入使用次数）。
  - 参照 FreeKill 的 `bypass_distances` / `bypass_times` / `extraUse`。
- **【青龙偃月刀】**（`package/标准/卡牌/青龙偃月刀.lua`）：『被动』订阅 `game:on('卡牌-答复后')`，筛出「你使用的【杀】被目标打出的【闪】答复」（askPlayCard + 【闪】 + reason `'杀'` + `parent`（那次杀的 `CardEffect`）`.user == owner`）⇒ **直接 `askUseCard`**（`{ name = '杀', target = parent.target }` + 三个旗标；**不再先问「是否发动」** —— 取消 = 不发动）。
- 用例：`core.effect.play` +3（三个旗标各自行为 / `askUseCard` 候选与用出去都按选项来）、`rule.equip` +7（正例+次数 / 不发动 / 候选空 / 链 / 旁人 / 万箭的闪 / 拆下）。
- 文档：`architecture.md`（canUse / useCard / askUseCard 三行 + `Game.UseOptions` 新行）、`sanguosha-rules` §9.11、`progress.md`、`HANDOVER.md`。

## Capabilities

### New Capabilities

无。

### Modified Capabilities

无对外契约变化（探索期口径：本变更不写 `specs/`）。

## Impact

- 内核：`server/core/game.lua`、`server/core/effect/use-card.lua`、`server/core/effect/ask-use-card.lua`、`server/core/loader/env-meta.lua`
- 内容：`package/标准/卡牌/杀.lua`（一处条件）、`package/标准/卡牌/青龙偃月刀.lua`（技能）
- 用例：`server/test/core/effect/play.lua`、`server/test/rule/equip.lua`
- 文档四件

## Non-goals

- **真正的「抵消」模型**（`CardEffect` 上的被抵消状态 + 可翻转）—— 【贯石斧】批再做（FreeKill 的 `CardEffectCancelledOut` / `isCancellOut` 是参照；青龙届时一起迁）。
- 顺手牵羊 / 借刀杀人的 `ignoreDistance` 接线（没有消费者）。
- `'卡牌-能否使用'` 载荷带选项、`UseCardToCard` 带选项 —— 都没消费者。
