# Tasks

## 1. 内核：`Dying` 记脱离 + 负责杀死

- [x] 1.1 `Dying` 加私有字段 `left`（默认假）+ `Dying:leave()`（幂等：置标记 → **当场** `fire('濒死-离开', self)`）；验证：用例覆盖「离开时立刻收到时机」「重复 `leave()` 只发一次」
- [x] 1.2 `Dying:settle()` 改成：`fire('濒死-进入', self)` → **没脱离就 `player:setAlive(false)`**（不再看 `isAlive()` 决定发不发离开）；验证：`server/test/core/effect/dying.lua` 改写后全绿（没人喊 `leave()` ⇒ 玩家死；喊过 ⇒ 不死、且时机在喊的那一刻发）
- [x] 1.3 **一个玩家只有一个濒死状态**：内核按玩家记当前那次 `Dying`（进入时写入、`leave()` 或 `settle()` 收尾时“还是自己”就清）；`enterDying` 发现他正在濒死中 ⇒ 把它的 `damage` 换成这一次（致死伤害）并**直接返回现有实例**（不 `apply()` / 不 `await()`）；已经 `leave()` 的旧实例不算“正在濒死”⇒ 新建；验证：用例覆盖「返回的是同一个实例」「`dying.damage` 变成了后一次」「结算没有重开（'濒死-进入' 只触发过一次）」

## 2. 内核：`game:getDying(player)`

- [x] 2.1 `game` 加私有表 + `game:getDying(player)` → `Dying?`；验证：`enterDying` 进行中查得到、结完 / 离开后查不到；没进濒死的人查到空
- [x] 2.2 `server/core/loader/env-meta.lua` 与 `dying.lua` 的接口注释同步（`'濒死-离开'` 的触发点从「收尾」改成「`leave()` 当场」，类型不变）；验证：问题面板 information 及以上 0

## 3. 内容侧：回血的地方喊脱离，求桃的地方不判死

- [x] 3.1 `package/@基础/回复.lua`：回血后 `game:getDying(to)` 拿到实例且 `体力 > 0` ⇒ `dying:leave()`；验证：规则侧「给一张桃救活」的用例仍然通过，且此时 `'濒死-离开'` 已经触发过（可在用例里挂个计数）
- [x] 3.2 `package/@基础/濒死.lua`：删掉循环末尾的 `setAlive(false)` 与 `'凶手'` 标签的写 / 清（其余不动：绕圈求桃）；验证：`--test rule.dying` 全绿（「没人救 ⇒ 阵亡」改由内核判，结果不变）
- [x] 3.3 `package/身份场/奖惩.lua`：凶手改成读 `game:getDying(死者).damage.from`（不再读 `'凶手'` 标签）；验证：奖惩五条用例全绿（凶手已阵亡 / 自杀 / 先奖惩后胜负的语义不变）

## 4. 用例

- [x] 4.1 `server/test/core/effect/dying.lua`：按新契约重写 —— 进入没脱离 ⇒ 内核杀死他；`leave()` ⇒ 当场发离开、不死；带伤害保留；「嵌套」那条改成「濒死中再受伤 ⇒ 返回同一个 + 致死伤害换掉」；删掉「内核不判死」那条（契约反转）
- [x] 4.2 `server/test/rule/dying.lua`：保留求桃四条；补「救活 ⇒ `'濒死-离开'` 触发过」与「没人救 ⇒ 死 + `'玩家-死亡'` 仍早于 `'伤害-后'`」；凶手断言改成读 `game:getDying`（死亡时机内）
- [x] 4.3 `server/test/rule/game-over.lua` 的奖惩五条回归（顺序依赖不变）；验证：`--test rule` 全绿

## 5. 文档与验收

- [x] 5.1 `moe-kill-dev/references/architecture.md` §12：`dying` 行（`leave()` / 收尾杀人 / 按玩家记账）与新增 `game:getDying(player)` 一行；濒死实现段同步（谁负责杀、谁负责脱离）
- [x] 5.2 `.agents/skills/sanguosha-rules/SKILL.md` §9.4：实现段改成「求桃在规则、判死在内核（看脱离标记）、回正由 `回复.lua` 喊 `leave()`、一个角色同时只有一个濒死状态（再受伤只换致死伤害）」；§9.7 的凶手改成读 `game:getDying`（`'凶手'` 标签已退役）
- [x] 5.3 `moe-kill-dev/references/progress.md`：内核现状（`Dying:leave` / `getDying` / 谁判死）与新用例数
- [x] 5.4 验收：`server/bin/moe-kill.exe --test` 全量 0 失败、问题面板 information 及以上 0；提交（`【AI】` 前缀）
