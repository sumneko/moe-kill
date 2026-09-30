# Tasks

## 1. 内核：询问支持「声明答复」

- [x] 1.1 `server/core/effect/ask-card.lua`：`AskCard.Option` 加 `viewAs? ViewAs`、`AskCard.Answer` 加 `viewAs? ViewAs`（与 `card` 互斥）
- [x] 1.2 `server/core/effect/ask-card.lua`：`checkAnswer` 认出 `viewAs`（找对应的声明选项、找不到 = 「答复不在可选项里」；跳过张数检查；目标仍走 `checkOption`）
- [x] 1.3 `server/core/effect/ask-card.lua`：新增 `@async` 钩子 `beforeResolve(value)`（基类原样返回），`collectAnswer` 在校验通过之后、定结果之前调它；给空 = 这次作废（原因已 reject 过）
- [x] 1.4 `server/core/effect/ask-card.lua`：`collectOptions` 末尾调 `self:collectExtraOptions(options)`（基类空）—— 给子类追加「不是一张实体牌」的候选

## 2. 内核：使用侧接入

- [x] 2.1 `server/core/effect/ask-use-card.lua`：`collectExtraOptions` —— 按 `names` 筛声明、`canGatherMaterials()` 同步判素材、光板虚拟牌跑 `canUse` 取 `plan`，追加 `{ viewAs = …, plan = … }`
- [x] 2.2 `server/core/effect/ask-use-card.lua`：`beforeResolve` —— `viewAs:tryProduce(self)` 拿牌 ⇒ 换成 `{ card = 牌, targets = 原答复的目标 }`；拿不到 ⇒ 作废
- [x] 2.3 `server/core/game.lua`：`checkCardItself` 对**虚拟牌**跳过「在使用者手上 / 所在区被禁用 / 声明的牌区」三条（虚拟牌不进牌区）—— 实现中发现，不补则声明永远进不了选项

## 3. 内核：声明的关联

- [x] 3.1 `server/core/view-as.lua`：公开字段 `source?`（内核只存不解释）
- [x] 3.2 `server/core/player.lua`：`addViewAs(name, source?, condition?)`（关联排在条件前面）

## 4. 内容侧

- [x] 4.1 `package/标准/卡牌/{丈八蛇矛, 八卦阵}.lua`：`addViewAs(牌名, card, 条件?)`（关联 = 它自己那张装备牌）—— 丈八使用侧因此自动可用（出牌阶段主动用两张手牌当【杀】）

## 5. 测试

- [x] 5.1 `server/test/core/effect/ask-use-card.lua`：声明进选项（素材不够 / 牌名对不上就不进）/ 选中后收素材造牌并当答复 / 素材给不出 ⇒ 作废（`.err` 记原因、不算失败）/ 目标不合法拒收 / 与实体候选并存 / `plan` 用光板牌算得出合法目标
- [x] 5.2 `server/test/core/view-as.lua`：`source` 读得到、不传就是空
- [x] 5.3 `server/test/rule/equip.lua`：丈八蛇矛**使用侧**（出牌阶段主动用两张手牌当【杀】打人 + 素材进弃牌堆 + 手里没两张就不出现在选项里）

## 6. 验收

- [x] 6.1 `server/bin/moe-kill.exe --test` 全绿（770 用例 0 失败）
- [x] 6.2 问题面板 information 及以上清到 0
- [x] 6.3 同步文档：`references/architecture.md`（声明那条 + `askUseCard` 行 + `addViewAs` 行 + `canUse` 行）、`references/progress.md`（§1 新条目 + §3 收尾 + 基线）、`sanguosha-rules`（§9.11 丈八 + §9.13 虚拟牌）
