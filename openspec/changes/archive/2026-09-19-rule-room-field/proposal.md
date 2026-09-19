# Proposal

## Why

`rule:getRoom()` 是多余的包装：场地建实例时就把场地写进了实例，规则包要用它直接读 `rule.room` 就行。而且「独立建的实例读场地会报错」这条分支在包的场景里根本不存在 —— 包只会在场地建出来的实例里跑。为一个不存在的调用场景加一个方法（外加一条永不触发的错误分支），与「不要过度防御」的口径相悖。

## What Changes

- **去掉 `rule:getRoom()`**，规则包直接用**字段** `rule.room`（场地建实例时写入）。
- 规则包看到的 `rule` 的类型**收窄成「一定绑着场地」**的那一份（在 `env-meta.lua` 里声明），所以包代码里 `rule.room:createZone(...)` 不会被告警「可能为空」；实现类上该字段仍是可选（独立建的实例没有场地，那不属于包的使用场景）。
- 规格同步：「规则实例」需求里的「读回场地」从方法改成**字段**。

## Capabilities

### New Capabilities

（无）

### Modified Capabilities

- `rule-loading`：「规则实例」—— 读回场地改成读字段 `rule.room`。

## Impact

- 内核：`server/core/rule/init.lua`（删 `getRoom()`）、`server/core/rule/env-meta.lua`（注入的 `rule` 用「已绑场地」的类型）。
- 规则包：`package/@基础/牌堆.lua`、`package/@基础/体力.lua`、`package/身份场/开局.lua`（`rule:getRoom()` → `rule.room`）。
- 测试：`server/test/core/room.lua`（读回场地改成断言字段）。
- 文档：`architecture.md` 第 9 / 10 节、`moe-kill-dev/SKILL.md`、`code-style.md`、`sanguosha-rules`、`AGENTS.md`。
