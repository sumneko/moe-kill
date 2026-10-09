# Proposal

## Why

标准包余下 8 将里，**貂蝉是「缺的机制最小」的一个**：【闭月】零新机制，【离间】只差一条 —— 官方文本里那句「**不能被【无懈可击】**」。

核查后确认：`UseOptions` 里没有这条（只有 `unrespondable` = 不能**响应**，【铁骑】那族的口径，与「不能被无懈」不是一回事）。

## What Changes

- **内容侧新增一个使用选项字段 `unnullifiable`**（用户 2026-10-09 定：「这个字段要在『无懈可击』这个内容包里注入和使用」）：
  - **类型面**由 `package/标准/meta.lua` **注入**（`---@class Game.UseOptions` / `Game.UseOptionsInput` 各加 `unnullifiable? boolean`）；
  - **消费**在 `package/标准/卡牌/无懈可击.lua`：`nullify()` 开头读 `effect.useCard?.useOptions?.unnullifiable` ⇒ **连问都不问**（候选自然也不呈现，`cardTargets` 一行不用改）。
  - **内核 `server/core/game.lua` 一行不改** —— 与「内核不预设时机名 / 区域名 / 属性名」同一条口径（**选项名同理**：内核只列它自己要读的 `ignoreDistance` / `ignoreUseLimit` / `notCounted` / `unrespondable` / `extraTargets`）。
- **貂蝉（新武将，整将）** `package/标准/武将/貂蝉.lua`：
  - **【闭月】** = `auto(true)` + `event('阶段-开始')`（结束阶段）+ `tryCast` 里 `owner:draw(1)` —— 零新机制。
  - **【离间】** = `limit('出牌', 1)` + `cards { zone = rule.ownZones, min = 1, max = 1 }` + `targets { min = 2, max = 2, filter = 其他男性 }`；`'使用'` 里弃牌 ⇒ 造虚拟【决斗】⇒ `game:useCard(后选者, 决斗, 先选者, { unnullifiable = true })`。
  - ⚠️ **首次把「目标的点选顺序」当语义**（官方「**后**选择的角色视为对**先**选择的角色使用」）⇒ `cast.use.targets[1]` 挨打、`[2]` 视为使用者。

## Capabilities

### New Capabilities

无。本变更属探索期的**决策记录**，不写规格增量（`.openspec.yaml` 设 `skip_specs: true`）—— 理由见 `AGENTS.md`「工作流」。

### Modified Capabilities

无。`openspec/specs/` 已冻结、不回头改。（⚠️「内容侧可以自己定选项字段名」是一条**对外约定**：协议层将来要认这些字段 —— 已写进 `architecture.md` 的 `Game.UseOptions` 行与 `sanguosha-rules` §9.10。）

## Impact

- **内容侧**：`package/标准/meta.lua`（注入字段）、`package/标准/卡牌/无懈可击.lua`（消费）、`package/标准/武将/貂蝉.lua`（新）。
- **内核**：**不动**。
- **用例**：`server/test/rule/trick.lua`（+1）、`server/test/rule/hero-skill.lua`（+4）。
- **文档**：`sanguosha-rules`（§9.10 无懈条目补 `unnullifiable`、新增 §9.26 貂蝉）、`moe-kill-dev/references/architecture.md`（`Game.UseOptions` 行：内容侧可自定义字段名）、`progress.md`。
