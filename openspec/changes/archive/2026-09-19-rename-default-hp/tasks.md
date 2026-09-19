# Tasks

## 1. 规则包

- [x] 1.1 `package/@基础/配置.lua`：`体力上限 = 4` → `默认体力 = 5`；验证：读到的键与值正确
- [x] 1.2 `package/@基础/体力.lua`：读 `默认体力`（局部变量改叫 `defaultHp`），同时写进玩家的 `体力上限` 与 `体力`；验证：行为不变

## 2. 测试

- [x] 2.1 `server/test/rule/base.lua`：键名与期望值改成 5（含快照与覆盖用例里的探针写法）；验证：该套件全绿
- [x] 2.2 `server/test/rule/identity.lua`：主公 6 / 其他人 5；验证：该套件全绿
- [x] 2.3 `server/test/rule/setup.lua`：8 人开局的期望值（主公 6 / 其他人 5）；验证：该套件全绿
- [x] 2.4 全量回归；验证：`--test` 全绿退出码 0

## 3. 文档

- [x] 3.1 `sanguosha-rules` §1 的已实现口径：把「无武将时的默认上限」改成「无武将时的开局体力初值（`默认体力` = 5）」；§9.1 示例同步
- [x] 3.2 `architecture.md` 第 9.7 节的规则数值示例同步
- [x] 3.3 问题面板与校验；验证：information 及以上为 0、`openspec validate --all --strict` 全通过
