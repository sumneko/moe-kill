# Tasks

## 1. 内核：候选者自己能否决

- [x] 1.1 `server/core/game.lua`：`collectLegalTargets` 里逐候选过完 `filter` 之后，再 `player:fire('卡牌-目标-能否指定', plan)` —— 非空即剔出候选

## 2. 类型面

- [x] 2.1 `server/core/loader/env-meta.lua`：`SkillDef:event` 补 `'卡牌-目标-能否指定'`（载荷 `CardDef.TargetPlan`）
- [x] 2.2 同文件 `Player:on` / `Player:fire` 补同名条目

## 3. 内容：陆逊

- [x] 3.1 `package/标准/武将/陆逊.lua`（新）：吴 · 男 · 体力上限 3
- [x] 3.2 【谦逊】= `tags '锁定技'` + `event('卡牌-目标-能否指定')`：牌名是【顺手牵羊】或【乐不思蜀】⇒ 返回 `'谦逊'`
- [x] 3.3 【连营】= `auto(true)` + `event('卡牌-离开区域')`：只认「离开的是手牌」+「此刻手牌为空」⇒ `tryCast` 里 `owner:draw(1)`

## 4. 用例

- [x] 4.1 `server/test/core/can-use.lua`：候选者自己能否决（被剔出候选；直接指定他 ⇒ 拒，原因「不能以这个角色为目标」）
- [x] 4.2 `server/test/rule/hero-skill.lua`：【谦逊】3 条（挡【顺手牵羊】（两边都要有牌）/ 挡【乐不思蜀】/ 他自己牵别人照旧）
- [x] 4.3 `server/test/rule/hero-skill.lua`：【连营】4 条（失去最后一张 ⇒ 摸一张且默认不问 / 手里还有 ⇒ 不摸 / **一次失去两张也只摸一张** / 关掉自动同意会问且答否不摸）
- [x] 4.4 反向验证：拆掉内核 gate ⇒ 红 3 条；拆掉【连营】的「手牌还有就不摸」⇒ 红 2 条；两处改回后全绿

## 5. 文档

- [x] 5.1 `sanguosha-rules`：§9.2 目标口径补「候选者自己也能否决」；新增 §9.29 陆逊（含与三段式的分工判据、不另开批量时机、假绿教训）
- [x] 5.2 `moe-kill-dev/references/architecture.md`：`game:canUse` 行补这条时机与「筛候选 vs 不生效」的分工
- [x] 5.3 `moe-kill-dev/references/progress.md`：基线 1013、22 将、成本表陆逊行、缺口表划掉「不能被选为目标」一行、§1 本批条目

## 6. 收尾

- [x] 6.1 `server/bin/moe-kill.exe --test` 全绿（1013 用例 0 失败）
- [x] 6.2 问题面板 information 及以上 0
