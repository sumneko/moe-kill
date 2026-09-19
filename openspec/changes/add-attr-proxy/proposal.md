# Proposal

## Why

属性现在有两处别扭：规则包得自己造属性系统再塞进规则数值（`createAttributeSystem` + `rule:setValue('属性系统', ...)`），而玩家对象上读写属性还得先 `getAttributes()` 绕一层。用户给出了形状：`rule:getAttributeSystem()` 与 `player:setAttr(...)`；同时把体力的属性边界写清楚（**可以为负**，且写值会**钳到当前体力上限**）。

## What Changes

- **属性系统改由规则门面持有**：`rule:getAttributeSystem()`（按需创建；**清空重载时重置** —— 属性定义是规则集内容，而且属性库不允许"编译后再新增属性定义"）；撤掉 `createAttributeSystem()` 与 `属性系统` 这条规则数值。
- **`Core.Player` 提供属性读写代理**：`setAttr(名字, 值)` / `getAttr(名字)` / `addAttr(名字, 增减)`，语义与 `getAttributes()` 上的同名操作一致。
- **体力的属性边界**：`体力` 定义为 `min = -999999`、`max = '体力上限'`（字符串引用 ⇒ 写值钳到当前上限）；`体力上限` 为 `0..999999`；开局把两者都设成 `默认体力`。
- 身份场的主公加成改用 `addAttr`（上限与体力各加一次）。
- **修正注入面的说法**：`rule` 上实际只剩 `getAttributeSystem`（牌与牌区归场地，见 `core-room`）。

## Capabilities

### New Capabilities

（无）

### Modified Capabilities

- `core-player`：「玩家对象」—— 增加属性读写代理。
- `base-rules`：「体力属性与初值」—— 明确体力的边界（可负、写值钳到上限）与属性定义时机。
- `rule-loading`：「规则集执行环境的注入面」—— 属性系统由门面持有并随清空重载重建；工厂清单更新。

## Impact

- 门面：`server/rule/init.lua`（`createAttributeSystem` → `getAttributeSystem`，`clear()` 里重置）。
- 内核：`server/core/player.lua`（三个属性代理）。
- 规则包：`package/@基础/体力.lua`（用户给的版本）、`package/身份场/开局.lua`（`addAttr`）。
- 测试：`server/test/core/player.lua`（属性代理）、`server/test/rule/base.lua`（体力可负 / 钳制 / 属性系统随重载重建）、`server/test/rule/support.lua` 与 `init.lua`（读法与 `getAttributeSystem` 探针）。
- 工具：`server/tools/attribute.lua` 与上游 `3f347e4` 同步（修 `getMax` 生成块缺 `local cache`）；**`compileSimple` 的同类坑仍在上游**（`simple = true` + 字符串 `max` 调 `getMax` 会报错，写入钳制不受影响）—— 本批不碰 `getMax`，已记进 `infrastructure.md` 的 `tools/` 改动清单。
