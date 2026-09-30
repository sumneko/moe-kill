# Proposal

## Why

【八卦阵】落地了「视为」的**最瘦**那一半：声明不带条件、不拿素材，内核照牌名造一张光板虚拟牌。**【丈八蛇矛】「你可以将两张手牌当【杀】使用或打出」**写不出来，卡在三处：

1. **素材没人收**：声明自己造牌要 `createVirtualCard`，但「用哪两张手牌」是**玩家的牌**，不该由技能代码代填；而「素材够不够」只有内核按条件判过，才能做到「不够就不问玩家」。
2. **素材不会被消耗**：虚拟牌不属于任何牌区，`Zone:accept` 收到它就注销 —— 它的 `subcards`（两张手牌）**没人管**，结果是白嫖。
3. **条件筛不出牌面**：`AskCard.Condition` 只有 `name` / `zone` / `card` / `min` / `max`，连【丈八蛇矛】的「两张手牌」都要靠 `min` / `max` 硬凑，【武圣】的「一张红色手牌」根本表达不了。

## What Changes

- **`ViewAs` 声明带素材条件**（`player:addViewAs(牌名, 条件?)`，条件就是 `AskCard.Condition`）—— 内容侧只描述「要什么素材」，其余交给内核：**同步判「素材够不够」（不够就跳过这份声明、连问都不问）→ 跑 `'发动'` 表态 → 内核按条件收素材（问玩家）→ 照牌名 + 素材造牌**。内容侧**不再需要 `createVirtualCard`**、更不填目标。
- **`'发动'` 钩子省略 = 默认成立**（声明带条件时，素材给不给就是玩家的表态，不必再写一个 `return true` 的空钩子）。
- **`AskCard.Condition` 加牌面筛选项 `suit` / `point` / `color`**（数组 = 满足其一、单值归一化、不填 = 无要求），与 `name` 同一套；筛选收口成一个共用判断，「候选收集」从 `collectOptions` 里抽出来给「素材可行性」共用。
- **虚拟牌的实体子牌随虚拟牌一起搬**：`Zone:accept` 收到虚拟牌 ⇒ 注销它、**改收它的 `subcards`**（「搬虚拟牌 = 搬它的实体子牌」）。于是用牌 / 打出 / 收尾全都不用特判，两张手牌自然走 手牌 → 处理区 → 弃牌堆。
- 内容侧：【丈八蛇矛】落地（**打出侧** —— 【决斗】/【南蛮入侵】要【杀】时能用两张手牌顶上）。

## Capabilities

无。本变更属探索期的**决策记录**，不写规格增量（`.openspec.yaml` 设 `skip_specs: true`）。可执行契约由用例承担，见 `AGENTS.md`「工作流」。

## Impact

- 内核：`server/core/effect/ask-card.lua`（条件加筛选项、抽候选收集、归一化扩展）；`server/core/view-as.lua`（声明带条件、素材收集、默认成立）；`server/core/player.lua`（`addViewAs` 多一个参数）；`server/core/zone.lua`（收虚拟牌 ⇒ 收子牌）；`server/core/effect/ask-play-card.lua`（`onAnswered` 去掉虚拟牌特判）。
- 内容侧：`package/标准/卡牌/丈八蛇矛.lua`。
- 测试：`server/test/core/effect/ask-card.lua`（筛选项）、`server/test/core/view-as.lua`（素材）、`server/test/core/move.lua`（子牌随虚拟牌进区）、`server/test/rule/equip.lua`（丈八蛇矛）。
- 文档：`references/architecture.md` / `progress.md` / `sanguosha-rules` 同步。
