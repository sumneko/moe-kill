# Tasks

> 本批 = **郭嘉【遗计】**（用户 2026-10-09 给形状：「把牌堆顶 2 张移动到临时区，然后用 `askCardToPlayer { min = 1, zone = tempZone }` 反复询问，取消了就给自己，直到临时区耗尽」+ 纠一处「`max` 得是剩余牌的数量」）。**纯内容侧，内核一行不改。**

## 1. 内容

- [x] 1.1 `package/标准/武将/郭嘉.lua`：`skills` 补成 `{ '天妒', '遗计' }`；加【遗计】（`auto(true)` + `event('伤害-目标-生效后')` + `for _ = 1, damage.amount` 里一轮一次 `tryCast`）
- [x] 1.2 每轮 body：`game:drawCards(owner, 2, cast:getTempZone())` ⇒ `while 区里有牌` 反复 `game:askCardWithTarget(owner, '遗计', { zone = 该区, min = 1, max = 区里张数 })`；答复为空 ⇒ 剩下的全给自己 + `break`
- [x] 1.3 观看的可见性（甲）：那块临时区 `setVisible(owner)` ⇒ 只有郭嘉看得见
- [x] 1.4 `Zone:setVisible` 改成名单语义（`boolean|Player|Player[]`，`owner` 不再参与可见性）+ `@基础/牌堆.lua` 的 `手牌` 改成 `setVisible(各自的持有者)` + `Zone:bindOwner` 说明回到「记下这个区属于谁」

## 2. 用例（`server/test/rule/hero-skill.lua`）

- [x] 2.1 给出的一张给对方、取消时剩下的归自己（两轮：第一轮给出、第二轮取消）
- [x] 2.2 **一次把两张都给同一人**（覆盖用户纠的 `max = 剩余数`：一轮就分完）
- [x] 2.3 受 2 点伤害发动两轮（两轮都不分配 ⇒ 四张全归自己）
- [x] 2.4 不发动（`auto` 关掉 + 答否）⇒ 什么也不做（牌堆顶没动、谁的手牌都没多）
- [x] 2.5 观看用的区**对郭嘉可见、对别人不可见**（在询问回调里断言 `shown:isVisibleTo(郭嘉)` / 别人）
- [x] 2.6 `core.zone` 可见性组改写（默认全员 / 给一名 / 给一批 / `false` 谁都看不见 / `true` 恢复 / 与归属无关）+ `core.player` 那条跟着改
- [x] 2.7 全量 `server/bin/moe-kill.exe --test` 0 失败（报出基线数：971 → 975）
- [x] 2.8 「反复询问」的循环从 `while` 改成带上限的 `for _ = 1, 1000 do`（遗计 + **濒死求桃圈**；`回合.lua` 的整局主循环保持 `while`）；约定写进 `code-style.md` §14

## 3. 验收与文档

- [x] 3.1 `sanguosha-rules` §9.24：标题收成「郭嘉【天妒】【遗计】」+ 补【遗计】代码与要点（复用现成询问 / 取消语义 / 可见性待协议层）
- [x] 3.2 `moe-kill-dev/references/architecture.md`：`askCardWithTarget` 行补「首个『结算中的分配』消费者 = 【遗计】」+ 结论（不必新开询问类）
- [x] 3.3 `moe-kill-dev/references/progress.md`：§1 记账 + 基线 975；§2 郭嘉行改成「两个都落地」、缺口表「置回牌堆顶」那条只剩观星
- [x] 3.4 收尾清单过一遍：问题面板 information 及以上 0、硬约束自查（命名 / 注释 / 键的落点）、停在待确认状态
