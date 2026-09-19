# Tasks

## 1. 内核与规则包

- [x] 1.1 `server/core/rule/init.lua` 删掉 `getRoom()`
- [x] 1.2 `server/core/rule/env-meta.lua`：注入的 `rule` 声明成「一定绑着场地」的类型（`room` 收窄为必填）
- [x] 1.3 规则包改用 `rule.room`：`package/@基础/牌堆.lua`、`package/@基础/体力.lua`、`package/身份场/开局.lua`

## 2. 测试与文档

- [x] 2.1 `server/test/core/room.lua` 的「读回所属场地」改成断言字段（场地建的实例带着场地；独立建的实例没有场地）
- [x] 2.2 文档里的 `rule:getRoom()` 全部换成 `rule.room`：`architecture.md` 第 9 / 10 节、`moe-kill-dev/SKILL.md`、`code-style.md`、`sanguosha-rules`、`AGENTS.md`
- [x] 2.3 验收：问题面板 information 及以上为 0、全量测试 0 失败、`openspec validate --all --strict` 全通过
