# add-cast

## Why

技能与装备发动**没有归因**：【奸雄】在 `'伤害-目标-结束'` 里那次 `moveCard`，事后看不出「这是【奸雄】做的」——

```lua
if not skill:confirm() then return end
game:moveCard(cards, owner:getZone('手牌'))      -- 这件事挂在哪？
```

底本 `Chapter2/Section7.md` 开头：「角色操作牌、**发动一个技能**或进行一次响应，即产生一个事件」⇒ 官方里「发动技能」本来就是个**事件**，我们缺的是把它记下来的那层。

## What Changes

- **新增 `Cast : Effect`**（`server/core/effect/cast.lua`，`kind = 'cast'`）：字段 `source`（`Skill|Card`，谁发动的）/ `body`；`settle()` 就是跑 `body` ⇒ **里面起的结算都挂在它下面**。
- **`Skill:cast(函数)`** —— `from` = `owner`（发动者），返回 `Cast` 实例。
- **`Card:cast(函数)`** —— `from` = 它所在区的主人（装备的持有者）。
- **【奸雄】改用它**：`confirm()` 放行后 `skill:cast(function () game:moveCard(…) end)`。
- **装备也一起改**（用户追加）：十张装备技能里有「发动后做事」那一段的 **6 张**包上 `card:cast(…)`（麒麟弓 / 青釭剑 / 雌雄双股剑 / 青龙偃月刀 / 贯石斧 / 八卦阵）；另外 4 张没有那一段，不动（方天画戟只改数量、诸葛连弩装上就生效、仁王盾只返回阻止原因、丈八蛇矛只声明「视为」）。
- 用例 +3（新 `core.effect.cast`）。

## Non-goals

- **不进记牌器**（用户 2026-10-01 定）：它是**响应**，在时机回调里调 ⇒ `parent` 非空 ⇒ 本来就不是根效果。将来真要一条「发动记录」，在那 `cast` 里加代码。
- 不做专门记录器、不给「发动」加时机（官方里它是**事件**，不是带编号的时机）。
- 不改 `Effect` 的记账口径（根效果才进记牌器这件事不动，只是名字起得不好）。
