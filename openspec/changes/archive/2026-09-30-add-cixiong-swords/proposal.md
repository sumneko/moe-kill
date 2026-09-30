# Proposal

## Why

装备技能的第六张（按「一张牌一个功能点」推进）。【雌雄双股剑】只有定义（武器 / 攻击范围 2），「指定异性目标后令其选择一项」的官方效果未实现。它比前几张多带三条**基础能力**（都有明确的首用消费者，不是提前设计）：

| 缺口 | 谁在用 |
| --- | --- |
| 没有「在若干具名选项里挑一个」的询问 —— 「是否发动」这类提示没有合适的类 | 【雌雄双股剑】（用户 2026-09-30 定：`askChoice` 给「是否发动」用） |
| `askCard` 只能收恰好一张；「弃一张手牌**或**不弃」这种**可以不给**的问法表达不了 | 【雌雄双股剑】（`min = 0, max = 1` + 空答复归一化） |
| 没有性别 —— 「异性角色」判不了 | 【雌雄双股剑】（`player.sex` 字段；将来武将系统写入） |

## What Changes

- **新类 `AskChoice`**（`server/core/effect/ask-choice.lua`）：`game:askChoice(被问者, 缘由, 选项)`（+ `moe.askChoice`）—— 选项（`any[]`）由发起方给、**答复必须是其中之一**（不在 ⇒ 拒收；**取消 = 不答 / 答复 nil，不算失败**）、读 **`.choice`**；走 `'决策-询问'` / `'决策-答复'`（载荷联合类型加 `AskChoice`）。
- **`askCard` 升张数**（`ask-card.lua`）：条件加 **`min?` / `max?`**（不填 = 1 / 1，`min` 可 0）；答复接受 **`Card | Card[]`**、入库统一成 `Card[]`；对象上新增 **`.cards`**（没答 = 空表）、**`.card` = `cards[1]`**；**张数不在区间 / 不在选项 / 重复给同一张 ⇒ 拒收**；**不给 / 给不出 / 被拒收 ⇒ `.card` 一律为空**（调用者只看 `.card`）。`askUseCard` / `askPlayCard` 不传 min/max ⇒ 恒为一张。
- **性别 = `player.sex` 字段**（`@基础/meta.lua` 声明 `基础.性别 = '男' | '女'`）：由将来的武将系统写入；缺了不发动（官方：没有性别的角色不能判断异性）。
- **【雌雄双股剑】**（`package/标准/卡牌/雌雄双股剑.lua`）：『被动』订 `owner:on('卡牌-结算前')`（沿用青釭先例）→ 逐目标判异性 → 装备主 `askChoice`「发动 / 不发动」→ 目标 `askCard`（0..1）：给一张 = 弃置；给不出 = `owner:draw(1)`。
- 用例：`core.effect.ask-card` +4、新套件 `core.effect.ask-choice` 5、`rule.equip` 雌雄一组 9。
- 文档：`architecture.md` 的 ask 家族表 / 说明、`sanguosha-rules` §9.11、`progress.md`。

## Capabilities

### New Capabilities

无。

### Modified Capabilities

无对外契约变化（询问家族是内容侧 API；时机名沿用 `'决策-询问'` / `'决策-答复'`，只加联合类型的成员）。探索期口径：本变更不写 `specs/`（`.openspec.yaml` 设 `skip_specs: true`）。

## Impact

- `server/core/effect/ask-choice.lua`（新）、`server/core/effect/ask-card.lua`、`server/core/effect/init.lua`、`server/core/game.lua`、`server/core/loader/env-meta.lua`
- `package/@基础/meta.lua`（`player.sex`）、`package/标准/卡牌/雌雄双股剑.lua`
- `server/test.lua`、`server/test/core/effect/ask-card.lua`、`server/test/core/effect/ask-choice.lua`（新）、`server/test/rule/equip.lua`
- 文档：`moe-kill-dev` 的 `references/architecture.md` / `references/progress.md`、`sanguosha-rules` 的 §9.11

## Non-goals

- 装备的**协议层表达**（明牌 / 前端展示）与其余装备技能（青龙偃月刀 / 丈八蛇矛 / 贯石斧）。
- 武将系统（性别的写入方）—— 本批只把读的口径定下（`player.sex`），真实对局里性别为空是正常态。
- 「指定目标后」的精确点位（成为目标时 / 逐目标再入标与编号重排）—— 等【享乐】/【流离】那批一起开，雌雄沿用青釭先例的 `'卡牌-结算前'`。
- `askCard` 的多张语义只备到「张数校验 + 列表答复」这一层（`max > 1` 的调用者尚未出现）。
