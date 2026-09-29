# Tasks

## 1. 内核：牌的被动机制

- [x] 1.1 `server/core/card.lua` 加被动机制：实例状态（压制计数出厂 1、本次应用的撤销函数记录）＋ `enablePassive()` / `disablePassive()`（减到 0 时同步跑『被动』回调并收集返回的撤销函数；加回 1 时先取出清空、再逆序调用；两个入口返回 disposer；先改计数、后执行动作）—— 以 4.1 的用例（`--test core.card`）验证
- [x] 1.2 跑全量用例确认内核改动未影响其他模块：`server/bin/moe-kill.exe --test` 0 失败（此步装备尚未迁移，行为应与之前完全一致）

## 2. 契约：钩子声明

- [x] 2.1 `server/core/loader/env-meta.lua` 的 `CardDef` 重载里加第 7 条 `'被动'`（载荷 `card` + 所在牌区，返回撤销函数）并留一行说明 —— 问题面板（information 及以上）无新问题

## 3. 内容侧：装备迁移

- [x] 3.1 `package/@基础/卡牌/装备牌.lua` 加启停：`'进入区域'` / `'离开区域'` 里 `slot and card:isKind(slot)` ⇒ `enablePassive()` / `disablePassive()` —— `--test rule.equip` 既有用例保持全绿
- [x] 3.2 `package/@基础/卡牌/武器牌.lua`：效果从 `'进入区域'` 迁到 `'被动'`（`return zone.owner:addAttr('攻击范围', range - 1)`），去掉 `withZone` —— `--test rule.equip` 全绿
- [x] 3.3 `package/@基础/卡牌/坐骑牌.lua`：同上迁移；修正属性名按分类判定、去掉「槽位名 → 属性名」映射表与 `withZone` —— `--test rule.equip` 全绿（重点：离开装备区后修正回到原值、不变负）

## 4. 用例

- [x] 4.1 `server/test/core/card.lua` 加被动机制用例：出厂不生效 / 启用时应用（同步、记下撤销函数）/ 停用时按记录撤销 / 计数叠加与逐层恢复 / 重复压制不重复撤销 / 回调不返回撤销函数 —— `--test core.card` 全绿
- [x] 4.2 `server/test/rule/equip.lua` 加装备启停用例：装上生效 / 拆下撤销 / 进错槽位不启用 / 压制后恢复（重新应用）—— `--test rule.equip` 全绿
- [x] 4.3 全量回归：`server/bin/moe-kill.exe --test` 0 失败（记录新的验收基线）

## 5. 收尾

- [x] 5.1 问题面板把 information 及以上清到 0（`card.lua` / `env-meta.lua` / 装备模板 / 用例文件）
- [x] 5.2 文档：`moe-kill-dev` 的 `references/architecture.md`（钩子清单加『被动』；写「撤销函数要在应用时捕获上下文」）与 `references/progress.md`（本批记录）—— 评审通过
- [x] 5.3 `openspec validate add-card-passive --strict` 通过；勾选全部 tasks 后 `openspec archive add-card-passive --yes`
