# Tasks

## 1. 规则实例与场地

- [x] 1.1 `server/core/rule/init.lua`：`CreateOptions` 增加 `room?`；`__init` 收 `room`；`create` **总是加载**（`packages` 省略视同空清单）；新增 `getRoom()`（没有场地时报错）
- [x] 1.2 `server/core/room.lua`：`create` 改成「先建场地对象 → `moe.rule.create { room = 场地, sources, packages = options.packages or {} }` → 装回场地」；`__init` 不再收规则实例
- [x] 1.3 验证：`--test core.room` 补「规则实例能读回所属场地」（场地建的实例读回同一个场地；独立建的实例读它报错）并通过

## 2. 上下文只留事件参数

- [x] 2.1 `server/core/rule/env-meta.lua`：`Moe.Rule.EventCtx.游戏开始` 变成**空类**（不声明字段）
- [x] 2.2 规则包改用 `rule:getRoom()`：`package/@基础/牌堆.lua`（`createZone` / `createCard`）、`package/@基础/体力.lua`（`getDesk`）、`package/身份场/开局.lua`（`getDesk` / `getRandom`）
- [x] 2.3 测试：`server/test/rule/support.lua` 的触发改成 `rule:fire('游戏-开始', {})`；`server/test/rule/*` 里 `create { packages = {} }` 简化为 `create {}`；全量回归

## 3. 文档

- [x] 3.1 `architecture.md`：第 9 节（`create` 总是加载、场地与实例的绑定）、9.6（一局的资源从 `rule:getRoom()` 取）、第 10 节（上下文只承载事件参数 + 空表示例）
- [x] 3.2 `moe-kill-dev/SKILL.md`（规则加载器那行的 `create` 口径）、`sanguosha-rules`（§8 上下文口径、§9.1 示例改用 `rule:getRoom()`）
- [x] 3.3 验收：问题面板 information 及以上为 0、全量测试 0 失败、`openspec validate --all --strict` 全通过
