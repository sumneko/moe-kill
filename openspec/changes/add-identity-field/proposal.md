# Proposal

## Why

身份是身份场里最常被读的玩家信息（开局发放、奖惩、胜负判定、客户端显示），但它至今借的是**通用标签袋**：`player:setTag('身份', …)` / `getTag('身份')`。三个代价：

1. **没有类型** —— `身份场/meta.lua` 得专门写两条按名收窄的 `getTag` / `setTag` 签名，编辑期才认得取值；还得自己补兜底（漏写会把内核签名吃掉）。
2. **拼错静默通过** —— tag 是任意键值袋，`getTag('身份 ')` 只是读到 `nil`。
3. **协议层没有名字** —— 表现层要显示身份时，没有人能保证该读哪个键。

## What Changes

- 新文件 **`package/身份场/身份.lua`**：给 `Player` 加 **`setIdentity(name)`**，写 **`player.identity`** 字段（读法直接读字段 —— 无参不写 `getIdentity()`，照 `player.hero` / `player.sex` 的现状）。
- **`身份场/meta.lua`**：删掉那 4 行按名收窄的 `getTag` / `setTag` 签名，换成 `---@field identity? 身份场.身份`。
- **调用点改造**：`开局.lua`（2 处写）、`奖惩.lua`（2 处读）、`胜负.lua`（2 处读）。
- **tag 机制本身不动**：`Player` / `Effect` / `Phase` 的 `setTag` / `getTag` / `removeTag` 保留（测试与内容侧另有用途）。

## Capabilities

无。本变更属探索期的**决策记录**，不写规格增量（`.openspec.yaml` 设 `skip_specs: true`）。可执行契约由用例承担，见 `AGENTS.md`「工作流」。

## Impact

- 内容侧：新增 `package/身份场/身份.lua`；`package/身份场/{meta,开局,奖惩,胜负}.lua` 跟着换读法。
- 内核：**一行不动**（tag 机制保留）。
- 测试：`rule/{identity,setup,game-over,hero}.lua` 改用字段（`core/player.lua` 那条 tag 用例按用户口径保留不动）。
- 文档：`references/{architecture,code-style,progress,infrastructure}.md` / `sanguosha-rules`（§1 身份口径）。
