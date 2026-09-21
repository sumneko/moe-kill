# Design

## Context

- 改动前的形状：类模块 = `---@class X` + `local M = Class 'X'`（类与实例方法）+ `---@class X.API` + `local API = {}` + `function API.create(…)` + `return API`；`server/core/init.lua` 里 `moe.X = include 'core.X'` 把它们拼成门面。
- `include` = `require` + 登记热重载（`server/tools/reload.lua`），它的返回值就是模块 `return` 的那张表。
- `server/core/init.lua` 由 `server/moe-kill.lua` 用 `require 'core'` 载入 ⇒ **不参与热重载**；`core/` 下的各模块才是 `include` 进来的。
- 门面的类型原先写在 `server/moe-kill.lua` 的 `MoeKill` 类上（`---@field card Card.API` …），类型名是「类名.API」。
- `core/effect.lua` 没有 API 表（基类没有工厂），所以 `moe.effect = include 'core.effect'` 赋的是 `nil`。
- 本轮先落地实现并验证（问题面板 0、303 用例 0 失败），本文补记当时的取舍。

## Goals / Non-Goals

- **目标**：门面与模块同生共死（重载即重建）、类型只写一处、没有工厂的类不硬凑表。
- **非目标**：改调用面（`moe.X.create` 保持不变）；改 `tools/` 与 `core/loader/` 内部子模块的模块形状；给 `Effect` 之类「只有类、没有工厂」的模块补门面。

## Decisions

### D1 门面在模块里建：`---@class X.API` + `moe.X = {}`

模块自己最清楚自己的公开入口，也**只有模块自己会被重载**。把 `local API = {}` 换成 `moe.X = {}`、`function API.create(…)` 换成 `function moe.X.create(…)`，模块不再 `return` 任何东西。于是「谁创建门面」与「谁被重载重建门面」是同一个文件 —— 改动前那个「重载后 `moe.card` 指旧表」的隐患自然消失。

否掉的方案：保留 `return API`，只在 `core/init.lua` 里跟着重载（那要把 `core/init.lua` 也纳入 `include`，还得处理重载顺序，比模块自己建更绕）。

### D2 `server/core/init.lua` 只留一串 `include`

门面既然由模块自己建，装配表就只剩「登记哪些模块可重载、按什么顺序执行」这一件事。顺序仍然重要（`core.effect` 要在 `UseCard` / `Damage` 之前，`core.loader` 在 `core.game` 之前），所以清单保持显式；`return moe` 一并去掉（`moe` 是全局，没有调用方读这个返回值）。

### D3 `MoeKill` 上不再声明门面字段

实测（LuaLS）：`---@class Card.API` 紧跟 `moe.card = {}` 会给这次赋值定名，**跨文件也认** —— 在别的文件里 `moe.card.create` 显示为 `Card.API.create(label?: any) -> Card`，全局 `moe` 的类型里带 `card: Card.API`。于是 `MoeKill` 上那 13 条 `---@field` 全部删掉，只留 `inspect`（`tools/inspect.lua` 没有注解，赋值只能推出 `unknown`，声明是在**收窄**）。

这条与 `code-style.md` §6 的规则同源：字段已经有明确赋值（且赋值能表达类型）时不再写 `---@field`。

### D4 没有工厂的类不建门面

`moe.effect` 取消。旧方案（`facade-factories`）给它一张空表，理由是「所有内核模块形状统一」；代价是给一个没人用过的名字挂 `nil`。新口径下形状依然统一：**模块要么建门面（有工厂），要么什么都不建（没工厂）**。`Effect` 仍由子类 `require 'core.effect'` 做类登记与 `Extends`。

### D5 装载器也走同一形状

`core/loader/init.lua` 的 `local M = {}` + `return M` → `moe.loader = {}`（`M.DEFAULT_SOURCES` / `M.install` / `M.declareDepends` 与内部互调一并改）。它内部 `require` 的 `vfs` / `preparse` / `env-util` **不动**：那三个是「被 `require` 拿返回值」的内部子模块，形状就该是返回一张表。

### D6 `server/session/init.lua` 同形状

`moe.server = {}`（用户 2026-09-21 定），`server/moe-kill.lua` 里只 `require 'session'`。会话模块用 `require` 载入（不参与重载），改成模块自己建门面后，「谁持有 `moe.server`」与「谁定义它」也归到同一个文件。

## Risks / Trade-offs

- [类型在编辑期悄悄失效而没人发现] → 本轮用 hover 逐点验证 `moe.card.create` / `moe.loader` / `moe.server` / 全局 `moe` 的推断结果；问题面板 0、303 用例 0 失败。
- [`moe.effect` 消失会不会踩到隐蔽调用] → 全仓 grep 只有 `core/init.lua` 的赋值提到它，没有任何读取点。
- [门面在重载时被换成新表 ⇒ 往上挂的状态会丢] → 与改动前同一口径（`architecture.md` 第 8.4 节：模块门面不许挂跨重载状态），只是现在「门面会被换」这件事变得更明确。

## Migration Plan

- 纯内存态、无数据迁移；调用面不变（用例证明调用点一个都没改）。回滚 = `git revert` 这几笔。
- 之后新增模块照 `code-style.md` §5 写：`---@class X.API` + `moe.X = {}` + `function moe.X.create(…)`，不 `return`。

## Open Questions

（无）
