# Proposal

## Why

一局的"场地"还没有归属：牌与牌区原本挂在规则门面上（`rule:createCard` / `rule:createOrderedZone`），抽牌堆塞在规则数值里（`rule:setValue('牌堆', deck)`）—— 规则集写起来像在用手工零件凑一局。用户给出了场地的形状：`ctx.room:createZone('抽牌堆', true)`、`ctx.room:createCard(name)`、`牌区:shuffle()`，本批就按它落地。

## What Changes

- 内核新增 **`Core.Room`（场地）**：持一张桌子与一个随机源；**按名字**建与取牌区（`createZone(名字, 有序?)` / `getZone(名字)` / `getZones()`，同名报错）；建牌（`createCard(名字)`，牌名写进不透明标签）。
- 游戏时机的上下文增加 `room`：`rule:fire('游戏-开始', { desk, random, room })`；`desk` / `random` 暂时保留（少改一遍已有的包与测试）。
- **有序牌区可以绑定随机源**（`core.orderedZone.create(random?)`）⇒ `牌区:shuffle()` 可以省略参数；既没绑定又没传参时以明确失败暴露。
- `package/@基础/牌堆.lua` 改为在场地里建抽牌堆（不再写 `rule:setValue('牌堆', ...)`）。
- 规则门面**去掉** `createCard` / `createZone` / `createOrderedZone`（牌与牌区是运行期的场地资源）；`createAttributeSystem` **保留** —— 属性系统在**加载期**就要定义好，那时还没有场地。
- 明确**不做**：场地不接管开局装配、会话、挂起与事件流（按需再来）；不做牌区移除接口。

## Capabilities

### New Capabilities

- `core-room`: 场地（桌子 / 随机源 / 按名字登记的牌区 / 建牌）。

### Modified Capabilities

- `core-zones`: 「有序取牌与可复现洗牌」—— 洗牌的随机源可由创建时绑定或调用时传入，`shuffle()` 因此可以省略参数。
- `base-rules`: 「牌堆构建与洗牌」—— 抽牌堆改为在**场地上**按名字建（不再放进规则数值），洗牌用场地提供的随机源。

## Impact

- 内核：新增 `server/core/room.lua`；`server/core/ordered-zone.lua`（绑定随机源 + `shuffle(random?)`，顺带去掉 `Type(random)` 的运行时判定）；`server/core/zone.lua`（基类的 `shuffle` 参数改成可选，它本来就直接报错）；`core/init.lua` 挂载。
- 门面：`server/rule/init.lua` 去掉三个工厂；`server/rule/env-meta.lua` 给 `Rule.EventCtx.游戏开始` 加 `room` 字段。
- 规则包：`package/@基础/牌堆.lua`。
- 测试：新增 `server/test/core/room.lua`；`server/test/rule/support.lua` 建场地并注入 ctx；`server/test/rule/{base,setup}.lua` 改从场地取抽牌堆；`server/test/rule/init.lua` 的工厂探针改成只验属性系统。
