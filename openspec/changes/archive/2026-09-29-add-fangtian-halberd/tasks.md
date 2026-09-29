# Tasks

## 1. 实现

- [x] 1.1 `package/标准/卡牌/方天画戟.lua`：『被动』订阅 `'卡牌-目标数修正'`（使用者 = 装备主 + 牌名【杀】 + 最后手牌 ⇒ `+2`；反注册函数交被动撤回）—— 以 2.1 / 2.2 验证

## 2. 用例（含目标数量违规）

- [x] 2.1 `server/test/rule/equip.lua` 方天画戟一组：最后手牌 + 装备 ⇒ 两名成立且区间 1..2；三名超合法数被拒、不给目标被拒、含自己被拒；两名目标依次结算（从 `rule/slash` 迁移的机制用例：一个目标的响应不影响另一个）—— `--test rule.equip` 全绿
- [x] 2.2 条件不满足一组：不是最后手牌 / 没装备 / 拆下后 / 别的牌名（决斗）/ 别人用的【杀】 ⇒ 两名被拒 —— `--test rule.equip` 全绿
- [x] 2.3 全量回归：`server/bin/moe-kill.exe --test` 0 失败（记录新基线）

## 3. 收尾

- [x] 3.1 问题面板：information 及以上清到 0（牌定义 / 用例）
- [x] 3.2 文档：`sanguosha-rules` §9.11（方天画戟移出「还没做」）；`progress.md`（本批记录与基线）
- [x] 3.3 `openspec validate add-fangtian-halberd --strict` 通过；勾选全部 tasks 后 `openspec archive add-fangtian-halberd --yes`
