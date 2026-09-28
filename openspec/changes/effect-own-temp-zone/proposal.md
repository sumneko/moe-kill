# Proposal

## Why

`Effect:getTempZone()` 的默认值与**最常用的用法相反**。

现在的默认是「沿 `parent` 回溯」：自己没有区就向父效果要，一路问到「自己就是一次结算」的那次。于是**每一个「自己就是一次结算」的效果都得重写它**：

| 效果 | 位置 | 重写 |
| --- | --- | --- |
| `UseCard`（一次用牌） | `server/core/effect/use-card.lua` | `return self:createTempZone()` |
| `CardEffect`（对某目标的一次生效） | 同上 | 同上 |
| `UseCardToCard`（一次对牌使用） | `server/core/effect/use-card-to-card.lua` | 同上 |
| `CardEffectToCard`（对某张牌的一次生效） | 同上 | 同上 |
| `判定`（一次判定，内容侧） | `package/@基础/判定.lua` | 同上 |

而反方向的「向父层借区」全仓**只有一个**消费者：`AskPlayCard:onAnswered()`（打出的牌要落在发起这次询问的那次结算的区里）。

也就是说：5 处为了「我是结算单位、要一块自己的区」写样板，1 处真的需要回溯。内容侧写一次判定（`package/@基础/判定.lua`）也得先抄一遍内核的 `getTempZone()` 重写 + `createTempZone()` 这套概念。

用户 2026-09-28 定：**把「自建」做成基类默认**。

## What Changes

- **`Effect:getTempZone()` 默认 = 自己这块**：懒建自己那块临时区、不再沿 `parent` 回溯。要**外层结算**那块区就**显式点名** `parent:getTempZone()`。
- **删掉 `Effect:createTempZone()`**：它存在的唯一理由就是「重写 `getTempZone()` 时用它」；默认自建之后不再有重写，所以不需要它（`getTempZone()` 自己就是「懒建 + 返回」）。
- **删掉 5 处重写**（上表四处内核 + 内容侧 `判定`）—— 它们要的行为现在就是默认行为。
- **`AskPlayCard:onAnswered()` 改为显式点名**：`self.game:moveCard(card, self.parent:getTempZone())`（仍然以「有外层结算」为条件）。**行为不变**：打出的牌仍进发起那次结算的区、仍由那次结算收尾时统一送 `弃牌`。
- **收尾语义不变**：`self.tempZone` 非空 ⇒ 它就是这块区的归属者 ⇒ 结完时 fire `'效果-收尾'` 并把区里剩下的牌送 `弃牌`（判据不变，只是现在「归属者」= 「自己碰过这块区」）。
- **BREAKING（对内容侧写法）**：`'效果-收尾'` 与「谁是区的主人」的判据不变，但**「内层效果自动接到外层结算那块区」这个隐式行为没了** —— 想借就写 `parent:getTempZone()`，不写就落进自己那块。

## Capabilities

### New Capabilities

无。本变更属探索期的**架构决策记录**，不写规格增量（`.openspec.yaml` 设 `skip_specs: true`）。

### Modified Capabilities

无（同上）。

## Impact

- 内核：`server/core/effect/effect.lua`（`getTempZone` / `createTempZone`）、`use-card.lua`、`use-card-to-card.lua`、`ask-play-card.lua`。
- 内容：`package/@基础/判定.lua`（删重写）。
- 测试：`server/test/core/effect/init.lua`（继承用例语义反转 + 补「显式点名父层」用例）。
- 文档：`references/architecture.md`（`Effect` / `CardEffect` / `askPlayCard` 三行的临时区口径）、`SKILL.md`、`references/progress.md`。

## Non-goals

- 不引入任何标记字段（不区分「主要 / 次要效果」，`parent` 只管嵌套）。
- 不做 git 历史 / 归档变更的改写（`inherit-temp-zone` 的记录保留原样）。
