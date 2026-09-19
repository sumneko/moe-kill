# Tasks

## 1. 门面（`server/rule/init.lua`）

- [x] 1.1 `createAttributeSystem()` → `getAttributeSystem()`：`M.__attributeSystem` 按需创建（门面表 + `__` 前缀，符合跨重载存活约定）；验证：规则集里能拿到并 `define`，`--test rule` 全绿
- [x] 1.2 `clear()` 里把它置空 ⇒ 清空重载后是一个全新的属性系统；验证：`--test rule.base` 的「属性系统随清空重载重建」用例通过

## 2. 内核（`server/core/player.lua`）

- [x] 2.1 属性读写代理 `setAttr` / `getAttr` / `addAttr`（转发给属性实例）；验证：`--test core.player` 的新用例通过

## 3. 规则包

- [x] 3.1 `package/@基础/体力.lua`：采用用户给的版本 —— `rule:getAttributeSystem()`；`体力` 定义 `min = -999999` / `max = '体力上限'`、`体力上限` 定义 `0..999999`；开局用 `player:setAttr` 把两者设成 `默认体力`
- [x] 3.2 `package/身份场/开局.lua`：主公加成改用 `lord:addAttr('体力上限', bonus)` / `lord:addAttr('体力', bonus)`；验证：`--test rule.identity` 全绿

## 4. 测试

- [x] 4.1 `server/test/rule/support.lua` 读 `rule:getAttributeSystem()`；`server/test/rule/init.lua` 的探针改名字；验证：规则侧套件全绿
- [x] 4.2 `server/test/rule/base.lua` 补「体力可以降到负数、写值钳到上限、抬上限不动体力」「属性系统随清空重载重建」；验证：该套件全绿
- [x] 4.3 全量回归；验证：`--test` 全绿退出码 0

## 5. 工具与文档

- [x] 5.1 `server/tools/attribute.lua` 与上游 `sumeneko/utility` 的 `3f347e4` 同步（逐字节一致）；`infrastructure.md` 的 `tools/` 改动清单记下这次同步**以及 `compileSimple` 的同类坑仍在上游**（`simple = true` + 字符串 `max` 调 `getMax` 会报错，写入钳制不受影响）
- [x] 5.2 `architecture.md` 第 9 节书写环境：工厂面改成「属性系统由门面持有、清空重载重置」；`moe-kill-dev/SKILL.md` 目录表同步
- [x] 5.3 `sanguosha-rules`：§1 的体力口径（可负 / 钳到上限 / 抬上限不动体力）与 §9.1 示例（`rule:getAttributeSystem()` + `player:setAttr`）；补一条「属性定义必须在加载期」
- [x] 5.4 验收：问题面板 information 及以上为 0、`openspec validate --all --strict` 全通过
