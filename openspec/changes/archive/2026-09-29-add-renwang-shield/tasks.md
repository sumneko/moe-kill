# Tasks

## 1. 实现

- [x] 1.1 `package/标准/卡牌/仁王盾.lua`：『被动』订阅 `'效果-能否生效'`（对装备主的【杀】 + 黑色 ⇒ 返回原因）—— 以 2.1 验证

## 2. 用例

- [x] 2.1 `server/test/rule/equip.lua` 仁王盾一组：黑杀无效（不掉血、连【闪】都不问）/ 红杀照常（要闪、没闪掉 1）/ 拆下恢复 / 打没盾的人不受影响 —— `--test rule.equip` 全绿
- [x] 2.2 全量回归：`server/bin/moe-kill.exe --test` 0 失败（记录新基线）

## 3. 收尾

- [x] 3.1 问题面板：information 及以上清到 0（牌定义 / 用例）
- [x] 3.2 文档：`sanguosha-rules` §9.11（仁王盾移出「还没做」）；`progress.md`（本批记录与基线）
- [x] 3.3 `openspec validate add-renwang-shield --strict` 通过；勾选全部 tasks 后 `openspec archive add-renwang-shield --yes`
