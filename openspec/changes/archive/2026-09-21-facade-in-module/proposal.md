# Proposal

## Why

`server/core/` 的模块一直是「类 + 另起 `local API = {}` + `return API`」的形状，门面在 `server/core/init.lua` 里靠 `moe.card = include 'core.card'` 拼起来。这套形状有三个具体麻烦：

1. **门面的持有者与创建者不是同一个文件**：`server/core/init.lua` 是被 `server/moe-kill.lua` `require` 进来的，**不参与热重载**；于是重载 `core/card.lua` 时模块吐出的新表没人接，`moe.card` 还是**旧表**。
2. **类型写两遍**：`---@class Card.API` 在模块里、`---@field card Card.API` 在 `server/moe-kill.lua` 的 `MoeKill` 上，同一件事写两处，删一处就断类型。
3. **没有工厂的类硬凑一张表**：`Effect` 没有工厂，旧方案却要求 `moe.effect` 是一张空表；而 `core/effect.lua` 里根本没有 API 表 —— `moe.effect = include 'core.effect'` 一直在往门面上挂 `nil`（读不出来、也没人读）。

## What Changes

- **门面由模块自己建**（用户 2026-09-21 定）：`server/core/` 下的模块各写 `---@class X.API` + `moe.X = {}`，工厂直接挂在这个字段上，**不再 `return` API 表**。涉及 `card` / `zone` / `orderedZone` / `random` / `attribute` / `event` / `desk` / `player` / `game` / `askCard` / `moveCard` / `useCard` / `damage` 与装载器。
- **`server/core/init.lua` 退化成 `include` 清单**：不再 `moe.X = include 'core.X'`。
- **没有工厂的类不建门面**：`moe.effect` 取消；`Effect` 只作为基类留在类注册表里（`Extends('UseCard', 'Effect')` 照旧）。
- **`server/session/init.lua` 同形状**：`moe.server = {}`，`server/moe-kill.lua` 里只 `require 'session'`。
- **`MoeKill` 上不再重复声明字段**：`moe.X` 的类型由赋值处的 `---@class` 定下；`server/moe-kill.lua` 里只留 `inspect`（`tools/inspect.lua` 没注解，它的类型赋值推不出来）。
- **本批不做**：`server/tools/` 的模块形状（照搬上游，不动）；`core/loader/` 的内部子模块（`vfs` / `preparse` / `env-util`）保持 `local M` + `return M` —— 它们是「别人 `require` 它、要拿返回值」的模块，形状本就该是返回一张表。

## Capabilities

### New Capabilities

（无 —— 既有能力的实现形状演进，对外调用面不变。）

### Modified Capabilities

- `kernel-facade`: 门面 SHALL 由模块自己建（模块 MUST NOT `return` API 表）、`core/init.lua` SHALL 只 `include`、`MoeKill` 上 MUST NOT 重复声明门面字段；`moe.effect` 从门面清单里去掉，**没有工厂的类 MUST NOT 建门面**；装载器同样写 `moe.loader = {}`。

## Impact

- 内核：`server/core/` 下 13 个模块 + `server/core/loader/init.lua` + `server/core/init.lua`；`server/session/init.lua`；`server/moe-kill.lua`。
- 规格：`openspec/specs/kernel-facade/spec.md`（本轮实现时已直接更新，delta 与主规格内容一致）。
- 文档：`moe-kill-dev/references/code-style.md` §5 / §6、`architecture.md` §1 / §8.4 / §9。
- 兼容性：**调用面不变**（仍是 `moe.card.create(…)` 这类，全量用例证明调用点一个都没改）；唯一消失的名字是 `moe.effect`（它本来就是 `nil`，全仓只有 `core/init.lua` 的赋值用到它）。
