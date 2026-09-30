# Tasks

## 1. 内核：声明对象

- [x] 1.1 `server/core/view-as.lua`（新）：`ViewAs` 类 —— 字段 `game` / `owner` / `name`（视为的牌名）+ 私有 `handlers` / `removed`；方法 `on(event, handler)`（链式返回自己）、`getHandlers(event)`（快照）、`tryProduce(ask)`（`@async`：跑 `'发动'`，第一个说成立的就由内核照 `name` 造一张虚拟牌）、`remove()`（幂等：从宿主摘掉）；门面 `moe.viewAs.create(game, owner, name)`
- [x] 1.2 `server/core/player.lua`：加私有字段 `viewAsList`；`addViewAs(name)`（建声明 → 登记 → 返回它）、`removeViewAs(viewAs)`（`ViewAs:remove()` 里调）、`getViewAsList()`（快照）
- [x] 1.3 `server/core/init.lua`：`include 'core.view-as'`（排在 `core.player` 之前）

## 2. 内核：询问侧改成依次尝试

- [x] 2.1 `server/core/effect/ask-play-card.lua`：`beforeAsk()` 改成「按被问者的声明顺序逐个试（牌名对上 `condition.names` 才试；没给名字也试）→ 谁先产出就 `task:resolve { cards = { 那张牌 } }` 并停」
- [x] 2.2 `AskOffsetCard` 继承同一份（不再有单独的替代逻辑）—— 确认它仍然工作

## 3. 删掉旧的替代窗口

- [x] 3.1 `server/core/effect/ask-play-card.lua`：删掉发 `'打出-技能替代'` / `'打出-装备替代'` 的代码
- [x] 3.2 `server/core/loader/env-meta.lua`：删两条时机的 `on` / `fire` 声明；补 `Player.addViewAs` / `ViewAs` 的类型声明

## 4. 内容侧

- [x] 4.1 `package/标准/卡牌/八卦阵.lua`：改成 `owner:addViewAs('闪'):on('发动', …)`（问发动 → 判定 → 红就返回真，牌由内核造），「被动」的撤销函数改成 `viewAs:remove()`；**行为不变**

## 5. 测试

- [x] 5.1 `server/test/core/view-as.lua`（新）：声明 / 撤销（幂等）/ 快照顺序 / `tryProduce` 第一个胜出 / 撤销后不再被试；并在 `server/test/core/init.lua` 注册
- [x] 5.2 `server/test/core/effect/ask-play-card.lua`：替代用例改成声明写法（顶替 / 不再问应答方 / 只试被问者 / 虚拟牌不进牌区 / **按声明顺序依次试、产出了就不试下一个** / 试完再问实体牌）
- [x] 5.3 `server/test/core/effect/ask-offset-card.lua`：替代用例改成声明写法
- [x] 5.4 `server/test/rule/equip.lua` 的八卦阵组：**一行不改**（行为不变的验收）

## 6. 验收

- [x] 6.1 `server/bin/moe-kill.exe --test` 全绿
- [x] 6.2 问题面板 information 及以上清到 0
- [x] 6.3 同步文档：`references/architecture.md`（新增 `ViewAs` / `addViewAs` 行，删替代窗口那段）、`references/progress.md`（§1 新条目 + §3 那条待办收尾）、`sanguosha-rules` §9.11（八卦阵口径）
