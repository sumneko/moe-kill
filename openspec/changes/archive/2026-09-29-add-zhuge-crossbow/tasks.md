# 任务

## 1 内核

- [x] 1.1 `server/core/game.lua`：`checkCardItself` 限额加 Σ `'卡牌-次数修正'`
- [x] 1.2 `server/core/loader/env-meta.lua`：`Game.Event.卡牌次数修正` + `Game.on` 收窄

## 2 内容

- [x] 2.1 `package/标准/卡牌/诸葛连弩.lua`：『被动』订阅 `'卡牌-次数修正'`（装备主用【杀】 ⇒ +1000）

## 3 用例

- [x] 3.1 `server/test/core/can-use.lua`：修正 Σ 正负参与限额
- [x] 3.2 `server/test/rule/equip.lua`：连出两张 / 只帮装备主 / 拆下恢复
- [x] 3.3 全量回归 + 问题面板清零

## 4 收尾

- [x] 4.1 文档（`architecture.md` 的 canUse 与 collect 条目、`sanguosha-rules` §9.11、`progress.md`）
- [x] 4.2 `openspec validate add-zhuge-crossbow --strict` + 归档

