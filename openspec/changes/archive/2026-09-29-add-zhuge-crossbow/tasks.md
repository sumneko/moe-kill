# 任务

## 1 内核

- [x] 1.1 `server/core/phase.lua`：`addLimit` 返回撤销函数（精确、幂等）

## 2 内容

- [x] 2.1 `package/标准/卡牌/诸葛连弩.lua`：『被动』三段（阶段开始加 / 装上补记 / 卸下撤）

## 3 用例

- [x] 3.1 `server/test/core/phase.lua`：撤销精确、幂等
- [x] 3.2 `server/test/rule/equip.lua`：连出两张 / 只帮装备主 / 拆下恢复 / 中途装上立即生效
- [x] 3.3 全量回归 + 问题面板清零

## 4 收尾

- [x] 4.1 文档（`architecture.md` 的 Phase 行、`sanguosha-rules` §9.11、`progress.md`）
- [x] 4.2 `openspec validate add-zhuge-crossbow --strict` + 归档

（评审记录：首版走「卡牌-次数修正」事件 + `checkCardItself` 收集，用户否决后整套撤掉、改回阶段账 —— 见 design 的 Decision Log。）

