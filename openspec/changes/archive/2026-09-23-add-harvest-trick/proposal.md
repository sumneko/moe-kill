# Proposal

## Why

【五谷丰登】是剩下的普通锦囊里唯一一张要「亮牌 → 逐人从这批牌里选一张」的牌 —— 上一批（`add-more-trick-cards`）正因为如此把它单独留了出来（用户 2026-09-23 定：晚点做）。它要三个口子，都是**通用**能力、不是为它特制：

1. **牌自己的「使用结算开始时 / 结束后」钩子**。官方写的是「当此牌**指定目标后**，你亮出牌堆顶的 X 张牌」与「**使用结算结束后**，将这些牌中剩余的牌置入弃牌堆」。现有钩子只有 `'获取目标'` 与 `'生效'`：前者**不能**用来亮牌（`canUse` 每次算合法目标都会调用它，会把牌堆提前掏空），后者是逐目标的。
2. **询问的候选可以来自"给定的一批牌"**。亮出的这批牌此刻**不属于任何人的牌区**，而 `AskCard` 现在的选项是"遍历被问者的牌区按条件筛"。
3. **效果上的标签袋**。亮出的牌要在 `'结算前'` → 每个 `'生效'` → `'结算后'` 之间传递；`'生效'` 的上下文是 `CardEffect`（可以顺 `ctx.parent` 找到这次用牌），但效果实例上得有个地方挂这类临时数据 —— `Phase` / `Player` 早就有同形的标签袋。

三个口子都小，且后面的东西都要用：「选**别人区域里**的牌」（过河拆桥 / 顺手牵羊）要的正是第 2 条，技能与无懈可击要的正是第 1 条的两个时机。

## What Changes

- **内核：`CardDef` 多两个钩子** —— `'结算前'` / `'结算后'`，各跑一次（前者在全局 `'卡牌-结算前'` 之后、逐目标之前；后者在全部生效之后、全局 `'卡牌-结算后'` 之前），上下文 = 这次用牌的效果实例（`UseCard`）。
- **内核：`AskCard.Condition.cards?`** —— 给了就以这批牌为候选（不再遍历被问者的牌区），`name` / `targets` 的语义不变（可叠加）；答复仍必须落在选项里。
- **内核：`Effect` 加标签袋**（`setTag` / `getTag` / `removeTag`，与 `Phase` / `Player` 同形）—— 内容侧在这次结算上挂临时数据。
- **内容侧：【五谷丰登】**（`package/标准/卡牌/五谷丰登.lua`）：`'获取目标'` = 所有存活角色；`'结算前'` 亮出 `抽牌:draw(目标数)` 并把它记在这次用牌上；`'生效'` 从"剩余"里问一张（`{ cards = 剩余 }`）⇒ `game:moveCard(选中, 目标的手牌)`；`'结算后'` 把剩余送 `弃牌`。
- **用例**：`server/test/rule/trick.lua`（4 条：拿牌 + 弃牌、没人答、顺序、起点是锚点而不是使用者）、`server/test/core/effect/play.lua`（1 条：牌钩子的顺序）、`server/test/core/effect/ask-card.lua`（2 条：候选来自给定的一批牌 / 手牌里的不算数）、`server/test/core/effect/init.lua`（1 条：效果标签袋）。
- **明确不做**：过河拆桥 / 顺手牵羊 / 借刀杀人 / 无懈可击、延时锦囊与判定区、锦囊的前端表现。

## Capabilities

### New Capabilities

无（探索期不写规格：见 `openspec/config.yaml` 与 `AGENTS.md` 的「工作流」；本变更在 `.openspec.yaml` 里设 `skip_specs: true`，可执行契约由用例承担）。

### Modified Capabilities

无（同上）。

## Impact

- 内核：`server/core/effect/init.lua`（标签袋）、`server/core/effect/use-card.lua`（调两个新钩子）、`server/core/effect/ask-card.lua`（条件的候选来源）、`server/core/loader/env-meta.lua`（钩子与条件的类型）。
- 内容：`package/标准/卡牌/五谷丰登.lua`（新）；牌表不用动。
- 用例：`server/test/rule/trick.lua`、`server/test/core/effect/{play,ask-card,init}.lua`。
- 文档：`sanguosha-rules`（§4 分类表、§7 的「还没做」、§9.10 五谷丰登的官方原文与实现口径）、`moe-kill-dev` 的 `references/{architecture,progress}.md`（牌钩子清单、`AskCard.Condition` 的 `cards`、`Effect` 标签袋、内容包现状）。
