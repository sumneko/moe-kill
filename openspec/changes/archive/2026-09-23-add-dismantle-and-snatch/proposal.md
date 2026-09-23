# Proposal

## Why

普通锦囊 10 种，已落地 6 张（无中生有 / 南蛮入侵 / 万箭齐发 / 桃园结义 / 决斗 / 五谷丰登）。剩下的 4 张里，**【过河拆桥】与【顺手牵羊】是同一类**：都要求「**选一名其他角色区域里的一张牌**，再把它挪走」（一个弃置、一个获得）：

- 与已落地的 6 张都不同 —— 它们的目标只有**角色**，牌始终在**使用者自己**手上；这两张第一次要「**从别人的牌区里挑牌**」。
- 于是第一次撞上**信息可见性**：目标的手牌是暗的（谁都不能挑具体哪一张，只能随机），装备区 / 判定区是明的（可以挑）。
- 官方目标口径是「一名**区域里有牌**的其他角色」—— 而玩家的「装备」「判定」两个区到现在还没建（`package/身份场/奖惩.lua` 里那句「装备区还没做」就是记号），不建区就实现不了官方语义。

顺带说明：这两张牌**不动**多目标、逐目标生效、距离（`desk:getDistance`）、挪牌（`moveCard`）、随机（`random:pick`）—— 全都现成。

## What Changes

- **内核：牌区的可见性**（`server/core/zone.lua`）：`Zone` 加 `visible`（默认「所有人可见」）+ `owner`（玩家建区时自动记），并提供 `zone:setVisible(值)` / `zone:isVisibleTo(视角)`。
- **内核：询问的候选可以是「区域整体」**（`server/core/effect/ask-card.lua`）：`AskCard.Condition` 加 `zones?`、`AskCard.Answer` / `AskCard.Option` 加 `zone?` —— 表达「盲选某个区（里面有什么你看不见）」；与 `cards?` 可以同时给，于是**一次询问**就能说完「选一张你看得见的牌，或者从某个暗区里随机拿一张」。
- **内容：开局建两个空区**（`package/@基础/牌堆.lua`）：给每名角色加 `装备` / `判定`（**只建区，不实现装备机制**），并把 `手牌` 标成只有持有者看得见。
- **内容：两张牌**（`package/标准/卡牌/`）：
  - 【过河拆桥】`'获取目标'` = 其他**区域里有牌**的存活角色；`'生效'` = 按可见性挑一张（暗区随机），`game:moveCard(那张牌, '弃牌')`。
  - 【顺手牵羊】同上，但目标还要**距离 ≤ 1**，且拿到的牌进**使用者自己的手牌**。
- **用例**：`server/test/rule/trick.lua` 扩充；内核侧 `server/test/core/zone.lua`（可见性）与 `server/test/core/effect/ask-card.lua`（区域候选）扩充。

## Capabilities

### New Capabilities

无（探索期不写规格：见 `openspec/config.yaml` 与 `AGENTS.md` 的「工作流」；本变更在 `.openspec.yaml` 里设 `skip_specs: true`，可执行契约由用例承担）。

### Modified Capabilities

无（同上）。

## Impact

- 内核：`server/core/zone.lua`（可见性）、`server/core/player.lua`（建区时记归属）、`server/core/effect/ask-card.lua`（`zones` 候选）。
- 内容：`package/@基础/牌堆.lua`（两个空区 + 手牌可见性）、`package/标准/卡牌/{过河拆桥,顺手牵羊}.lua`（新）。
- 用例：`server/test/rule/trick.lua`、`server/test/core/zone.lua`、`server/test/core/effect/ask-card.lua`。
- 文档：`sanguosha-rules`（§4 牌分类表的已落地清单、§7 的「还没做」、§9.10 补两张牌）、`moe-kill-dev` 的 `references/{architecture,progress}.md`。
- 明确不做（都是**已定**的推迟项，不是本批漏掉）：
  - **正式的「弃置」/「失去牌」动作** —— 本批 `过河拆桥` 直接 `game:moveCard(牌, '弃牌')`（与 `add-draw` 那批把「获得 / 弃置」列为 Non-Goal 的口径、`奖惩.lua` 的现有写法一致）；它要的信号（谁弃的、从哪来）等**武将技能**那批一起定（那时可能要做的是更泛的「失去牌」）。
  - **装备机制与距离修正**（只建空区）、**借刀杀人**（要装备 + 「令别人使用【杀】」）、**无懈可击**（要嵌套询问）、**延时锦囊与判定区结算**（判定动作已落地）。
  - `package/身份场/奖惩.lua` 那句「现在只弃手牌」**不改** —— 装备区现在必然为空，改了没有任何行为差异（要改请单独提）。
