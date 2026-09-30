# Proposal

## Why

【八卦阵】已经落地，但它的实现是**硬替代**：内核在「要一张打出的牌」之前发两个固定时机（`'打出-技能替代'` → `'打出-装备替代'`），订阅者返回一张牌就把这次答复顶掉。这条路有三个限制：

1. **机制散在技能里**：每个「产出一张虚拟牌」的技能都要自己订时机、自己认领牌名、自己造牌 —— 没有共享的形状（【丈八蛇矛】「两张手牌当【杀】」这类**素材未定**的转化牌根本写不出来）。
2. **顺序与身份是硬编码的**：「先武将技能、后装备技能」写死成两个时机名的先后；再加一类技能还要再插一个时机名。
3. **替代是「顶替」不是「玩家选择」**：技能段给出替代后询问就不发了，玩家没有「我不用八卦阵、直接打实体闪」的余地（只能靠技能自己 `askChoice` 问一句）。

本变更把这条链路换成**声明 + 依次尝试**的形状。

## What Changes

- 内核新对象 **`ViewAs`（视为声明）**：`player:addViewAs('闪')` 声明「我能产出一张【闪】」，返回声明对象（撤销用 `viewAs:remove()`，与 `addBuff` 同形）；声明挂在玩家身上、**按声明顺序**排列。
- 声明对象上登记钩子，本批只做 **`'发动'`** 一个：**异步**，返回真 = 这次视为成立（自己问「要不要发动」、自己判定），**牌由内核照声明的牌名造**。
- **`AskPlayCard:beforeAsk()`** 换成「**依次试被问者身上的声明**」：牌名对得上这次要的牌（条件里的 `names`）才试；谁先产出一张牌就当答复落定（**不再发询问**）；全试完 ⇒ 照常要实体牌。
- **删掉 `'打出-技能替代'` / `'打出-装备替代'` 两个时机**（内核、`env-meta` 声明与相关用例）—— 它们被声明集合取代。
- 【八卦阵】改写：`'被动'` 里 `owner:addViewAs('闪') : on('发动', …)`，**行为不变**（判红 ⇒ 视为打出一张【闪】；判黑 / 不发动 ⇒ 照常要实体【闪】；拆下 ⇒ 不发动）。

## Capabilities

无。本变更属探索期的**决策记录**，不写规格增量（`.openspec.yaml` 设 `skip_specs: true`）。可执行契约由用例承担，见 `AGENTS.md`「工作流」。

## Impact

- 内核：新增 `server/core/view-as.lua`；`server/core/player.lua`（声明列表 + `addViewAs` / `removeViewAs` / `getViewAsList`）；`server/core/effect/ask-play-card.lua`（`beforeAsk` 改写）；`server/core/init.lua`（装载顺序）；`server/core/loader/env-meta.lua`（删两个时机、补 `ViewAs` 类型）。
- 内容侧：`package/标准/卡牌/八卦阵.lua`。
- 测试：新增 `server/test/core/view-as.lua`（并在 `test/core/init.lua` 注册）；改 `server/test/core/effect/ask-play-card.lua` / `ask-offset-card.lua` 里的替代用例；`server/test/rule/equip.lua` 的八卦阵组**一行不改**（行为不变）。
- 文档：`references/architecture.md` / `progress.md` / `sanguosha-rules` 同步。
