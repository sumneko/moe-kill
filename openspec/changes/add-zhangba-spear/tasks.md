# Tasks

## 1. 内核：询问条件加牌面筛选

- [x] 1.1 `server/core/effect/ask-card.lua`：`AskCard.Condition` 加 `suit` / `point` / `color`；`AskCard.NormalizedCondition` 加 `suits` / `points` / `colors`；`normalizeCondition` 一起归一
- [x] 1.2 筛选收口成共用的 `matches(card, condition)`（`names` / `suits` / `points` / `colors`）；把「按条件收集候选牌」抽成 `collectCandidates(to, condition)`，`collectOptions` 改用它
- [x] 1.3 两个辅助挂到 `moe.askCard` 门面（`normalizeCondition` / `collectCandidates`）供 `ViewAs` 用

## 2. 内核：声明带素材条件

- [x] 2.1 `server/core/view-as.lua`：`__init` 多一个 `condition`（建时归一化）；`canGatherMaterials()`（同步判够不够）；`tryProduce` 改成「够 ⇒ 表态（钩子省略 = 默认成立）⇒ `produce()`」；`produce()` = 按条件 `askCard` 收素材 → `createVirtualCard(name, 素材)`
- [x] 2.2 `server/core/player.lua`：`addViewAs(name, condition?)`
- [x] 2.3 `server/core/effect/ask-play-card.lua`：`beforeAsk` 不变形（`tryProduce` 内部已扩展）；`onAnswered` 去掉虚拟牌特判

## 3. 内核：虚拟牌的子牌随牌搬

- [x] 3.1 `server/core/zone.lua`：`accept` 收到虚拟牌 ⇒ `Delete` 它、把它的 `subcards` 收进来（子牌为空 = 什么都不进）

## 4. 内容侧

- [x] 4.1 `package/标准/卡牌/丈八蛇矛.lua`：【丈八蛇矛】—— `'被动'` 里 `host:bindGC(owner:addViewAs('杀', { zone = '手牌', min = 2, max = 2 }))`

## 5. 测试

- [x] 5.1 `server/test/core/effect/ask-card.lua`：筛选项（花色 / 点数 / 颜色 / 混合 / 与 `name` 叠加）
- [x] 5.2 `server/test/core/view-as.lua`：素材（收齐造牌带子牌 / 不够不试不问 / 不给就不成立 / 钩子省略默认成立 / 花色筛选的素材）+ 既有「没登记钩子 = 没产出」改成「默认成立」
- [x] 5.3 `server/test/core/move.lua`：虚拟牌的子牌随它进区（有子牌 / 空子牌两条）
- [x] 5.4 `server/test/rule/equip.lua`：【丈八蛇矛】端到端（两张手牌打出【杀】/ 只有一张不被问 / 拆下不再发动）

## 6. 验收

- [x] 6.1 `server/bin/moe-kill.exe --test` 全绿
- [x] 6.2 问题面板 information 及以上清到 0
- [x] 6.3 同步文档：`references/architecture.md`、`references/progress.md`（§1 新条目 + §3 待办收尾）、`sanguosha-rules`
