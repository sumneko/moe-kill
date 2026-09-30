# Tasks

## 1. 内核

- [x] 1.1 `server/core/card.lua`：`passiveUndo` → `passiveHost`（懒建 `GCHost`）；`applyPassive()` 跑回调时传第三个参数；`removePassive()` 先摘再 `Delete`；**删 `withZone`** 与 `zoneGCHost` 字段（`bindZone` 简化成只记归属）
- [x] 1.2 `server/core/loader/env-meta.lua`：`CardDef.on` 的 `'被动'` 重载改成 `fun(card: Card, zone: Zone, host: GCHost)`
- [x] 1.3 `server/core/view-as.lua`：补 `__del`（`Delete(viewAs)` ⇒ `remove()`）

## 2. 内容侧

- [x] 2.1 `@基础/卡牌/武器牌.lua` / `坐骑牌.lua`：`return X` → `host:bindGC(X)`
- [x] 2.2 `标准/卡牌/`：诸葛连弩 / 方天画戟 / 仁王盾 / 青釭剑 / 麒麟弓 / 雌雄双股剑 / 青龙偃月刀 / 贯石斧 / 八卦阵（八卦阵改成 `host:bindGC(viewAs)`）

## 3. 测试

- [x] 3.1 `server/test/core/card.lua`：被动探针改成 `host:bindGC(...)`；「不返回撤销函数的回调」改成「什么都不挂的回调」；「按记录撤销」相关断言跟着改
- [x] 3.2 `server/test/core/move.lua`：删掉两条 `Card:withZone` 用例
- [x] 3.3 新增/保留：「一个被动挂两份资源 ⇒ 停用时都释放」

## 4. 验收

- [x] 4.1 `server/bin/moe-kill.exe --test` 全绿；问题面板 information 及以上 0
- [x] 4.2 同步文档：`architecture.md`（`'被动'` 行 + 删 `withZone` 行）、`progress.md`（§1）、`sanguosha-rules` §9.11
