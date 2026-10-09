# Tasks

> 本批 = **张辽【突袭】+ `AskPlayer` 一次选多名**（用户 2026-10-09 定：方案里「改为」用 `-1000`、「askPlayer 得加 min 和 max」）。

## 1. 内核：`AskPlayer` 的个数区间

- [x] 1.1 `server/core/effect/ask-player.lua`：`Condition` 加 `min?` / `max?`（**`min` 省略 = 1、`max` 省略 = `min`**）；候选字段 **`players` → `player` + 四态**（`Player|Player[]|true|fun(Player): boolean`，谓词在存活角色里筛）；`checkAnswer` 复用 `moe.askCard.checkTargets`（答复 `Player|Player[]` 归一成列表）；加 `.players` getter（恒列表）、`.player` = `players[1]`；类声明补 `---@field player? Player` / `---@field players Player[]`（类型面靠 `@field`，`__getter` 不够）；调用点同步（【借刀杀人】）
- [x] 1.2 `server/core/game.lua` 与 `env-meta.lua`：`askPlayer` 的条件 / 返回说明与「一名或几名角色」同步
- [x] 1.3 验证：`--test core.effect.ask-player` 全绿（含既有的「答复不在候选里」那条——文案统一成 `答复的目标不在可选项里`）+ 问题面板 information 及以上 0（改完 **`lua.startServer`** 重启后再看）

## 2. 内容：张辽【突袭】

- [x] 2.1 新建 `package/标准/武将/张辽.lua`：`Hero '张辽'`（魏 / 男 / 4 体力 / `: skills { '突袭' }`）+ 文件顶部照 §9.3 写官方描述
- [x] 2.2 【突袭】= `event('阶段-开始')`（摸牌阶段）：先 `askPlayer(owner, '突袭', { players = victims, min = 0, max = 2 })`，**选到人才 `skill:cast(…)`**（不问「发不发动」）—— cast 里 `phase:bindGC(owner:addAttr('摸牌数', -1000))` + 逐人 `hand:list()[game.random:nextInt(1, hand:count())]` 盲取
- [x] 2.3 候选 = 其他存活且手牌非空者；**候选为空就不问也不发动**

## 3. 用例

- [x] 3.1 `core.effect.ask-player` +7：`min` / `max` 一次选好几名（`.players` / `.player`）、`min = 0` 没答复就是空表且不算失败、超上限与重复都拒收、默认正好一名、**`max` 省略就取 `min`**（`{ min = 0 }` ⇒ 给一名也超）、**`player = true` 不限**、**谓词筛候选**
- [x] 3.2 `rule.hero-skill` +4：发动 ⇒ 放弃摸牌 + 拿两张（两名各少一张）/ 不表态 ⇒ 照常摸两张 / **一个都不选 ⇒ 也不发动、照常摸两张** / 别人都没手牌就不问且照常摸
- [x] 3.3 口径：**不问 `confirm`**（选 0 名 = 不发动）—— 写进 `sanguosha-rules` §9.15；同时记下 `tryCast` 那一问的 `askChoice` 同名坑（第一版踩过）
- [x] 3.4 全量 `server/bin/moe-kill.exe --test` 0 失败（报出基线数：975 → 986）

## 4. 验收与文档

- [x] 4.1 `sanguosha-rules`：新增 **§9.25 张辽【突袭】**（含「改为」= 属性归零、「一次选多名」、盲取随机、「`tryCast` 先问一句 `askChoice`」这个坑）+ §9.15 / §9.16 的询问清单同步
- [x] 4.2 `moe-kill-dev/references/architecture.md`：`game:askPlayer` 行改写（`min` / `max`、`.players`、文案统一、首个多选消费者 = 张辽）
- [x] 4.3 `moe-kill-dev/references/progress.md`：§1 记账 + 基线 983；§2 武将表（张辽落地、「已落地 18 将」）与缺口表
- [x] 4.4 收尾清单过一遍：问题面板 0、硬约束自查（命名 / 注释 / 键的落点）、停在待确认状态
