# Proposal

## Why

装备技能按「一张牌一个功能点」推进时，青釭剑 / 雌雄双股剑这两个「指定目标后」类技能一直借 `'卡牌-结算前'` 当近似点位，并在技能里自己循环全目标（两处都记进 `sanguosha-rules` §9.11 当**已知近似**）。官方口径（Ch1/S1 雌雄例、Ch1/S2 无双例、Ch2/S7）显示「指定目标后」是一个**逐目标、在卡牌结算之前**的独立时机 —— 现在把它做出来，并让这两个技能迁过去。

## What Changes

- `UseCard:settle()` 里新增**逐目标**的「指定目标后」阶段（在 `'卡牌-结算前'` 之后、牌的 `'使用'` 钩子之前，按 `desk:actionOrder` 每个目标各一轮），每轮发**三份**（用户 2026-09-30 定名与份数）：`'卡牌-指定目标后'`（全局）→ `'卡牌-来源-指定目标后'`（使用者）→ `'卡牌-目标-指定目标后'`（目标）；载荷都是 `(useCard, target)`。
- **声明 `skipEffect` 的牌照发**这个时机（它跳的是「生效」—— 延时锦囊被指定时也有指定目标后）。
- 【青釭剑】与【雌雄双股剑】**迁移**：订 `owner:on('卡牌-来源-指定目标后')`、逐目标处理（不再自己循环全目标）；青釭从「一次做完」改成逐目标压 buff（窗口语义不变）。
- 用例：`core.effect.play` +1（逐目标三份 / 顺序 / 非目标不收）、skipEffect 用例补断言、`rule.equip` 两处借 `'卡牌-结算前'` 的模拟订阅改订新事件。
- 文档：`architecture.md`（`game:useCard` 行与用牌安置条目）、`sanguosha-rules` §9.11（青釭 / 雌雄两段）、`progress.md`、`HANDOVER.md`。

## Capabilities

### New Capabilities

无。

### Modified Capabilities

无对外契约变化（时机名新增三个；探索期口径：本变更不写 `specs/`）。

## Impact

- `server/core/effect/use-card.lua`、`server/core/loader/env-meta.lua`
- `package/标准/卡牌/青釭剑.lua`、`package/标准/卡牌/雌雄双股剑.lua`
- `server/test/core/effect/play.lua`、`server/test/rule/equip.lua`
- 文档四件（`architecture.md` / `sanguosha-rules` / `progress.md` / `HANDOVER.md`）

## Non-goals

- 「成为目标时」/「指定目标时」、再入标与编号重排（【求援】那类把新目标拖进来）、同时机多技能排序（官方优先级 / 每角色每时机选一个）。
- `UseCardToCard`（对牌使用）不发这一组事件 —— 目标是牌不是角色，没有消费者。
