# Proposal

## Why

内容侧要「把这张牌挪到别处去」（打进弃牌堆、收进处理区、交给别人）时，内核现在**答不出「这张牌现在在哪儿」**：当初定的「薄模型」是内核不记录牌的归属，于是唯一的出路是**遍历所有牌区去找**；而且同一张牌技术上可以同时出现在两个牌区里 —— 那是个不该存在的假状态。将来「匹配系统」（按牌找位置、按位置找牌）还要依赖这个答案。

用户 2026-09-20 定：**卡牌要记录自己的位置**，`game:moveCard` 据此落地。

## What Changes

- **`Card` 记录自己所在的牌区**：`card:getZone()` 读出「现在在哪个牌区」（不在任何牌区时为「不存在」）；这本书由**牌区自己维护** —— 放入 / 取出 / 移动 / 清空时顺手记上或抹掉，调用方不用管。**只记「哪个牌区」，不记下标**（下标会被任何一次插入改掉）。
- **`Zone:put` 只接受不在任何牌区里的牌**（**BREAKING**）：已经有归属的牌要换区 MUST 走移动（`Zone:move`），直接放进别的牌区 MUST 明确失败。于是「同一张牌同时在两个牌区里」不再成立。
- 归属只记在牌自己身上，进出的这几个操作 MUST NOT 产生事件、记录或其它流程性副作用（沿用原口径）。
- **`game:moveCard(cards, zoneName)` 落地**（内容侧挪牌的入口）：按每张牌自己记的归属找到源区并移动到指定名字的目标牌区；可以**成批**挪。目标牌区不存在、或某张牌不在任何牌区里时 MUST 明确失败，且 **MUST NOT 改动任何状态**（先整批校验通过再动手）。省略位置 ⇒ 落到目标牌区**底部**（与移动的默认一致）。
- 本批**不做**：移动产生时机 / 记录（将来要「牌离开某区」的时机另开变更）、按位置（下标）查询、跨局挪牌。

## Capabilities

### New Capabilities

（无 —— 是既有能力的行为反转 + 一个既有接口的落地，不引入新对象。）

### Modified Capabilities

- `core-move`: 「内核不记录牌的归属」**反转为「牌记自己的归属」**（`put` 拒收已有归属的牌、进出时由牌区维护这本书）；新增「把牌挪进某个牌区」（`game:moveCard` 成批挪牌、整批校验、两种明确失败）。

## Impact

- 内核：`server/core/card.lua`（归属字段 + `getZone` / `bindZone`）、`server/core/zone.lua`（`put` / `take` / `move` / `clear` 维护归属，`put` 新增拒绝）、`server/core/game.lua`（`M:moveCard` 由接口落成实现）。
- 内容侧（`package/**`）：无影响 —— 挪牌一律走 `game:moveCard`，建堆（新牌直接 `put`）与回收（打出的牌先取出、再挪）都满足新约束。
- 测试：`server/test/core/move.lua`（薄模型那条用例换成归属用例）、`server/test/core/game.lua`（补 `moveCard` 用例）。
- 文档：`moe-kill-dev` 的 `references/architecture.md` 第 12 节（接口表 + 归属说明）、`server/core/loader/env-meta.lua`（`moveCard` 声明已在）。
