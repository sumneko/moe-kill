# Proposal

## Why

`util`（收窄的纯函数工具集）一直挂在**内核**里（`server/core/loader/env-util.lua`），由装载器注入 —— 可它**与游戏规则无关**（用户 2026-09-21 定），内核不该认识「内容侧需要什么工具」。

上一批（`share-content-env`）刚把装载环境改成**整轮共用一份** ⇒ 现在包之间可以靠全局变量共享东西，`util` 正好可以改由**包自己提供**。

## What Changes

- **新增默认包 `package/@tools`**（不跟中文命名走：它**不是规则内容**，与 `meta` 同理）：
  - `package/@tools/工具.lua`：内容侧写法实现 `filter` / `map` / `contains`，在共享环境里写下全局 `util = { ... }`。
    （原来是 `filter` 自己实现、`map` / `contains` 直接借 `moe.util` —— 包拿不到 `moe`，所以**三个都用内容侧写法重写**。）
  - `package/@tools/meta.lua`：声明类型 —— `---@class 工具.工具集` + `---@type 工具.工具集` 的全局 `util`（`meta` 机制正好用上）。
- **内核不再注入 `util`**：`loader/init.lua` 去掉 `envUtil`（真跑与试跑两处）、删掉 `server/core/loader/env-util.lua`、`env-meta.lua` 里那条 `---@type Loader.EnvUtil` 声明也删掉（类型搬到 `@tools/meta.lua`）。
- **用例**：那两条用 `util` 的规则集用例改成把**项目自己的 `package` 目录**也当来源（`util` 现在由 `@tools` 提供，纯探针来源的局没有它）——顺带从「测注入的工具集」变成「测真的 `@tools`」。
- **文档**：`architecture.md`（注入面那条 + `util` 那条 + 类型面那两处 + 「常用动作的形状」）、`sanguosha-rules` §9.1 三条、`code-style.md`（loader 内部子模块清单）、`SKILL.md` 的 `package/` 行。

**明确不做**：不给 `util` 加新函数（要加先过「纯函数」这条线）。

## Capabilities

### New Capabilities

- （无）

### Modified Capabilities

- （无）

> 探索期不写规格（`.openspec.yaml` 设 `skip_specs: true`）：契约由用例承担 —— `--test rule`（那两条工具集用例改成走真 `@tools`）。

## Impact

- 新增：`package/@tools/工具.lua`、`package/@tools/meta.lua`
- 删除：`server/core/loader/env-util.lua`
- 改动：`server/core/loader/init.lua`（不再注入 `util`）、`server/core/loader/env-meta.lua`（删 `util` 声明）、`server/test/rule/init.lua`（两条用例 + `loadWithContent` 辅助）
- 文档：`architecture.md`、`sanguosha-rules`、`code-style.md`、`moe-kill-dev/SKILL.md`
- **行为变化**：没装 `@tools` 的局（`Depends { '!tools' }` 或来源里没它）**没有 `util`**；正常来源下 `@tools` 是默认包、按逻辑名排在默认包最前 ⇒ 规则包加载时它已就位
