# `include` 失败改为记日志并抛出

## Why

`include`（可重载加载入口）原先在失败时**返回 `false, 错误信息`**（错误本身已经由内部的 `log.error` 连同堆栈写进日志）。两个问题：

1. **控制流上太软**：`moe.card = include 'core.card'` 会把 `false` **静默**赋进门面 —— 进程带着半套门面继续跑，直到某处 `moe.card.create(...)` 才炸成 `attempt to index a boolean value`（现场离原因很远）。为了堵这个，`server/core/init.lua` 只好再包一层 `includeCore`，把 `false` 变成硬失败、并在日志里**重复**记了一次同一个错误（用户 2026-09-19 指出「内部不是会调用 log.error 吗」）。
2. **重载时又不能这么硬**：重载是开发期动作，某个模块装不回去不该让**其余模块**也跟着不更新。

## What Changes

- **`M.include` 失败时记日志并抛出错误**（不再返回 `false`）：错误依旧由内部的 message handler 用 `log.error` 记进日志（带堆栈），然后**原样重抛**同一个错误对象（自己再加位置信息）。
- **重载过程里隔离单个模块的失败**：`M:fire()` 重新加载每个模块时逐个 `pcall` —— 一个模块失败了，其余模块照常重载（失败已经有日志）。
- **`server/core/init.lua` 去掉 `includeCore`**：`include` 现在自己会抛，门面直接 `moe.card = include 'core.card'`，不再需要中间层，日志里也不再重复。
- 契约跟随：`reload.lua` 里的注释与 `---@return` 注解、`architecture.md` §8 的接口表、`infrastructure.md` 里这份照搬文件的「改写点」。

## Capabilities

### Modified Capabilities

- `hot-reload`: 「加载失败可被区分」原先明确要求**不抛给调用方**，改成**记日志 + 抛出**；并补上「重载过程中单个模块加载失败不中断整轮重载」

## Impact

- **基础设施（照搬文件，本次有意改动）**：`server/tools/reload.lua`（`include` 的失败路径 + `fire()` 的 `pcall` + 注释/注解）。
- **内核**：`server/core/init.lua`（删掉 `includeCore`，13 行直接赋值）。
- **测试**：`server/test/core/reload.lua`（失败用例改成断言抛出；顺手把探针模块从重载名单里摘掉，否则之后每一轮重载都会重试它并记一条错误日志）。
- **文档**：`architecture.md` §8（接口表 + 两处 `includeCore`）、`infrastructure.md`（这条照搬记录的改写点，原来还写着「把错误信息交回调用方」与一个已经不存在的 `reportError`）。
