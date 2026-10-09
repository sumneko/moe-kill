# Tasks

> 本批 = **能力 + 武将技能全迁 + 装备同迁**（用户 2026-10-09 定；装备那半是同日「提交，然后改卡牌」追加的，见第 6 批）。
> **形状中途改判过**：第 1 批按「甲·自动问 + 套 `cast`」实现，迁移时发现条件前置会让无关触发也被问（详见 `design.md` D2）⇒ 用户改判 **乙·只订阅**，第 4 批把它改回来并迁移。

## 1. 内核

- [x] 1.1 `server/core/skill.lua`：`SkillDef` 加 `event(name, handler)` / `globalEvent(name, handler)`（可多次调，各存一份声明列表）+ 读法 `getEventList()` / `getGlobalEventList()`（快照，照 `getViewAsList`），新类型 `SkillDef.EventDecl`（`name` / `handler`）；验证：`--test core.skill` 全绿
- [x] 1.2 `server/core/skill.lua`：`Skill:applyPassive()` 在跑完 `'被动'`、挂完 viewAs 之后照声明挂 —— `host:bindGC(owner:on(名, 包过 tryCast 的回调))` / `host:bindGC(game:on(…))`；验证：`--test core.skill` 全绿，且「停用后收不到、重新启用又收得到」有断言
- [x] 1.3 `server/core/loader/env-meta.lua`：`SkillDef` 的 `on` 旁加 `event` / `globalEvent` 的按名收窄（内核常用几条 + `string` 兜底，照 `Game.on` / `Player.on` 的配方）；验证：问题面板 information 及以上 0

## 2. 用例（`server/test/core/skill.lua`；探针技能 + 自定义时机名，`game:on` / `game:fire` 已不受加载期限制）

- [x] 2.1 `event` 订自己：启用收得到 / 停用收不到 / 重新启用又收得到；且**订的确实是自己那份**（同一时机 `game:fire` 收不到）
- [x] 2.2 `globalEvent` 订局：`game:fire` 收得到；且**订的确实是局那份**（同一时机 `player:fire` 收不到）
- [x] 2.3 自动性 + 归因：`auto(true)` ⇒ 不问、`'效果-能否生效'` 里 `kind == 'cast'` 的次数 +1；`auto(false)` + 答「不发动」⇒ 回调没跑、cast 次数不涨；答「发动」⇒ 跑且 +1
- [x] 2.4 一条技能可多次调：两条 `event` 都挂上（`#def:getEventList() == 2`），且与 `'被动'` 共存互不影响
- [x] 2.5 反向验证：把 wrapper 里的 `tryCast` 摘成「直接跑回调」⇒ 2.3 该红（记录实际红了哪几条）；验完改回

## 3. 验收与文档

- [x] 3.1 全量 `server/bin/moe-kill.exe --test` 0 失败（报出基线数）
- [x] 3.2 `moe-kill-dev/references/architecture.md` §12 的 `SkillDef` 行：补两个声明 + 三条口径（订自己 / 订局不可互换；收集式时机不许用；`auto` 不认锁定技标签）
- [x] 3.3 `sanguosha-rules/SKILL.md` §9.15：技能写法三选一（声明式 `viewAs` / `event` 订阅 / `'被动'` 兜底）
- [x] 3.4 `moe-kill-dev/references/progress.md` §1 记账（含基线与本次产出的两条口径）
- [x] 3.5 收尾清单过一遍：问题面板 information 及以上 0、硬约束自查（键的落点 / 命名 / 注释）、停在待确认状态

## 4. 形状改判为「只订阅」+ 迁移武将

- [x] 4.1 包装改成只订阅：`S:makeEventCallback` 原样转发（第一参补技能自己；**多参数与返回值都转** —— 修掉「载荷多参时机只转一个」的缺口）；`env-meta` 的兜底签名改 `fun(skill: Skill, ...: any): any`
- [x] 4.2 `core.skill` 的「自动性 + 归因」用例改写成「只订阅」（内核不替它问、也不起 cast；回调里 `tryCast` 照常；条件不过连问都不问）
- [x] 4.3 迁移武将 11 处订阅：奸雄 / 集智 / 奇才 / 克己 / 铁骑 / 鬼才 / 反馈 / 刚烈 / 裸衣 / 洛神×2（洛神两条：`globalEvent('判定-后')` + `event('阶段-开始')`）；【马术】【咆哮】保留 `'被动'`
- [x] 4.4 类型面补内容侧时机：`package/@基础/meta.lua` 的 `SkillDef` 块加 `event`（伤害 / 治疗各四阶段 × 来源/承受两侧）+ `globalEvent`（`'判定-前'` / `'判定-后'`）+ 兜底；`env-meta` 补 `'卡牌-来源-使用选项'`；hover 验证收窄（`damage.cardsInPlace` ⇒ `Card[]`）
- [x] 4.5 全量 `server/bin/moe-kill.exe --test` 0 失败（964）+ 问题面板 information 及以上 0

## 5. 补：使用者那份的时机名带方向词（2026-10-09，用户提）

- [x] 5.1 `'卡牌-结算前'`（使用者份，与全局份同名）⇒ **`'卡牌-来源-结算前'`**：`UseCard` / `UseCardToCard` 的 `self.user:fire(…)`、`env-meta` 的 Player 声明与 `SkillDef.event` 候选、【集智】、`core.effect.play` 的用例同步；验证：全量 964 / 0
- [x] 5.2 文档：`architecture.md` 的「早期同名两份」名单去掉它 + `useCardToCard` 行的两份名字写清；`sanguosha-rules` §9.21 示例块改成 `event` 形状（顺带清掉迁移前的 `confirm`/`cast` 旧写法）
- [x] 5.3 迁移前旧形状的示例块清理（同日）：`sanguosha-rules` 里 **4 处**（刚烈 / 铁骑 / 救援 / 裸衣）改成 `event` 形状（【马术】保留 `'被动'`）；顺带修 §9.14 / §9.15 的「技能下一批」「挂载还没接」两处过期表述

## 6. 牌侧同名能力 + 装备迁移（2026-10-09，用户「提交，然后改卡牌」）

- [x] 6.1 `server/core/game.lua`：`CardDef` 加 `event` / `globalEvent` + `getEventList()` / `getGlobalEventList()`（快照）+ `CardDef.EventDecl`（与 `SkillDef.EventDecl` 同形）；验证：`--test core.card` 全绿
- [x] 6.2 `server/core/card.lua`：`Card:applyPassive()` 在跑完 `'被动'`、挂完 viewAs 之后照声明挂 —— `event` 订主人（`owner` 不存在就跳过）、`globalEvent` 订局；`Card:makeEventCallback` 第一参补牌、载荷与返回值原样转
- [x] 6.3 类型面：`env-meta` 的 `CardDef` 块（内核六条 + `'效果-来源-被抵消'` / `'效果-目标-能否生效'` + `string` 兜底）；`package/@基础/meta.lua` 补 `CardDef` 块（与 `SkillDef` 块一致：伤害 / 治疗 16 条当事人份 + 判定 2 条 + 兜底）
- [x] 6.4 迁移装备 7 处订阅：青釭剑 / 雌雄双股剑 / 方天画戟 / 贯石斧 / 麒麟弓 / 青龙偃月刀 / 仁王盾（回调要主人就自己 `assert(card:getZone())` + `assert(zone.owner)` —— 类型窄化，见 design D7）；**保留 3 处 `'被动'`**：`武器牌` / `坐骑牌` / 【诸葛连弩】
- [x] 6.5 用例：`core.card` +3（订主人那份（局上收不到 / 停用收不到 / 重新启用又收得到 / 回调拿到的是这张牌）/ `globalEvent` 订局那份 / **牌没主人时不订也不报错**）
- [x] 6.6 验收：全量 967 / 0；装备既有用例（`rule.equip`）一行未改、全绿（逐字等价）；问题面板 0
- [x] 6.7 文档：`architecture.md` 的 `Card:on(事件, 回调)` 行补两个声明与口径；`sanguosha-rules` §9.11 的 7 处装备写法改成 `event`、§9.15 补「三样东西同形（牌 / 状态 / 技能）」；`progress.md` §1 + 基线
