# Proposal

## Why

`Effect` 的临时处理区现在是「每个效果各自一块」——谁问谁建。于是子效果想用**这次结算**的暂存区时，只能自己去翻 `parent`：`AskPlayCard:onAnswered()` 硬写 `self.parent:getTempZone()`，而 `@基础/使用.lua` / `@基础/判定.lua` 又各自点名 `useCard` / `judge`。这种人工点名在**结算里再嵌一次结算**时必然写错（【借刀杀人】的「令别人使用【杀】」一出现就有两个用牌结算），而且「这块区归谁、什么时候清」也说不清。用户 2026-09-24 定：把继承关系做进内核。

## What Changes

- **临时处理区沿 `parent` 继承**：`Effect:getTempZone()` 自己没有区就向父层要，一路问到「自己就是一次结算」的那个效果 —— `UseCard` / `CardEffect` / `Judge` 重写该方法**自建、不向上取**；一路都没有（例如装配侧在顶层直接发起一次询问）由**最外层**那次结算建。一次结算只有一块区。
- **`tempZone` 保持普通字段、不做 `__getter`**：读它就是「自己建的那块区」（没建过为空），它存在的意义正是**绕过** `getTempZone()` —— 不建、也不向上取。内核判归属与内容侧 `@基础/收尾.lua` 都读它。
- **BREAKING：`'效果-收尾'` 只发给「区的归属者」**（自己建了这块区的那次结算）。今天每个效果结完都发一次，内容侧 `@基础/收尾.lua` 靠「没建过区 ⇒ `effect.tempZone` 为空」天然只清一次；读法改成继承之后这个天然保证没了，于是把「谁负责清」收进内核：继承来的区由归属者在它收尾时清。
- `AskPlayCard:onAnswered()` 改用 `self:getTempZone()`（不再把 `parent` 当区的归属者；仍然以「有没有外层结算」为条件 —— 顶层不动那张牌）。
- **不加标记字段**：归属靠重写表达 —— 于是「效果分主要 / 次要」那件事不必现在做，这个无标记版本已经给出「只有开结算的效果才有处理区」。

## Capabilities

本变更不写 specs 增量（`.openspec.yaml` 设 `skip_specs: true`）：`openspec/specs/` 是探索期的冻结快照，本变更改的是内核内部的归属规则与用例；`game-events` 规格只规定「按时机名注册 / 触发」的机制，不涉及具体时机名的触发条件，因此没有 requirement 级的行为变更。

### New Capabilities

- 无。

### Modified Capabilities

- 无。

## Impact

- 内核：`server/core/effect/effect.lua`（`getTempZone` / `bindFinish`）、`use-card.lua`（`UseCard` 与 `CardEffect` 各重写一处）、`judge.lua`、`ask-play-card.lua`。
- 内容：`package/@基础/收尾.lua` 不用改（仍读 `effect.tempZone`）；`@基础/使用.lua`、`@基础/判定.lua`、`标准/卡牌/五谷丰登.lua` 照旧。
- 文档：`references/architecture.md` 第 10 节与第 12 节（`Effect` 行、收尾时机的触发条件）、`references/progress.md` 第 3 节（「主要 / 次要」中已由本变更覆盖的部分）。
- 用例：`server/test/core/effect/init.lua`（4 条「收尾」用例要先要一块区才发收尾；新增继承 / 归属 / 只发归属者）、`ask-play-card.lua`、`play.lua` 复核。
- **行为保持不变**（已逐一核对）：打出的【闪】仍在「该目标那次生效结束」进弃牌堆（`CardEffect` 自建）、判定牌仍在「该次判定结束」进弃牌堆（`Judge` 自建）、【五谷丰登】亮出的牌仍在整次用牌结束时进弃牌堆（`UseCard` 自建）、顶层 `game:damage` 里打出的牌仍随这次伤害结束而进弃牌堆（最外层建）。
