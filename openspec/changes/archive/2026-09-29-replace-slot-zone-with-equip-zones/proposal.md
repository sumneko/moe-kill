# Proposal

## Why

装备区现在是**一个** `SlotZone`（四条槽位：`武器` / `防具` / `进攻马` / `防御马`）—— 一个区要按名字寻址里面的格子：`slots` / `setSlots` / `getSlot` / `slotMap`、`Zone.Move` 的 `slot` / `fromSlot`、`takeIn` / `accept` / `remove` / `notifyEnter` / `notifyLeave` 全线多一个槽位参数、专用入口 `game:moveCardWithSlot`，外加「同槽换新时旧牌进弃牌堆」的特殊收牌逻辑。

但官方规则集里**装备区本来就分成子区**：「一名角色的装备区包括其武器区、防具区、进攻坐骑区、防御坐骑区、特殊坐骑区和宝物区」。把子区直接建成**普通牌区**（按名字寻址）比给一个区造格子机制更贴事实，也让 `SlotZone` 这个特殊形状整个消失。

顺带把【青釭剑】的落点铺好：「禁用防具槽」= `目标:getZone('防具'):disable()`（禁用语义见 `rework-zone-disable`）—— 窗口内换装照样无效、拆装也不用追牌。

## What Changes

- **删掉槽位机制**：删 `server/core/slot-zone.lua`（连 `init.lua` 装载与 `moe.slotZone`）；删 `game:moveCardWithSlot`；删 `MoveCard` 的 `slot`；`Zone` 的槽位参数全线退役（`Zone.Move` 只剩 `card` / `from` / `to`，`takeIn` 去 slots，`accept` 回两个参数，`remove` 去槽位段，`notifyEnter` / `notifyLeave` 回 `(card, zone)`，删局部函数 `slotNameOf`）—— 牌钩子签名回到 `(card, zone)`。
- **玩家不再有「装备」区**：内核只建 `手牌` / `判定`（局上仍是 `抽牌` / `弃牌`）；`getZone` 的 `'装备'` 重载去掉。
- **内容侧建四个装备子区**：`@基础/装备.lua` 在 `'游戏-开始'` 给每个玩家 `addZone('武器')` / `'防具'` / `'进攻马'` / `'防御马'`（普通 `Zone`）；同文件加帮助（分类 → 子区名、`isEquipZoneOf`、`equipCard(玩家, 牌)` —— **「一个子区只能有一张」落在这里**、`equipCardsOf(玩家)`）。
- **装备模板改按子区启停**：`@基础/卡牌/装备牌.lua` 的 `'进入区域'` / `'离开区域'` 认「这个区是不是本人的、与分类对应的那个子区」；「使用」钩子改调 `equipCard`。
- **消费者改寻址**：【借刀杀人】直接取 `getZone('武器')`；【主公杀忠臣】遍历四个子区收集装备牌。
- **用例 / 文档同步**：`core.zone`（槽位段删）、`core.game` / `core.move` / `core.card-def` / `core.player`、`rule.equip`（大改）、`rule.trick` / `rule.game-over`；`architecture.md`、`sanguosha-rules` §9.11、`progress.md`、`code-style.md`（回调参数那条的 `slot`）。

## Capabilities

### New Capabilities

无 —— 探索期的决策记录，不写规格增量（`.openspec.yaml` 设 `skip_specs: true`）。

### Modified Capabilities

无（同上）。

## Impact

- 内核：`zone.lua`、`ordered-zone.lua`、`slot-zone.lua`（删）、`game.lua`、`effect/move-card.lua`、`player.lua`、`core/init.lua`、`loader/env-meta.lua`
- 内容：`@基础/装备.lua`、`@基础/卡牌/装备牌.lua`、`标准/卡牌/借刀杀人.lua`、`身份场/奖惩.lua`
- 用例：`core.zone` / `core.game` / `core.move` / `core.card-def` / `core.player` / `rule.equip` / `rule.trick` / `rule.game-over`
- 文档：见上

## Non-goals

- **宝物区 / 特殊坐骑区**（官方口径里还有）—— 用到再加名字。
- 「把牌置入装备区」的**技能**（巧变 3 / 甘露这类）—— 不在本批；`equipCard` 的形状要让它们将来好接。
- 装备区的**可见性 / 主动技能**—— 与槽位机制无关，已有。
