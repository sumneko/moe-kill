# Tasks

## 1. 内核：门面在模块里建

- [x] 1.1 `server/core/` 下 13 个模块（`card` / `zone` / `ordered-zone` / `random` / `attribute` / `event` / `desk` / `player` / `game` / `ask-card` / `move-card` / `use-card` / `damage`）：`---@class X.API` + `local API = {}` + `function API.create(…)` + `return API` → `---@class X.API` + `moe.X = {}` + `function moe.X.create(…)`，去掉 `return`；验证：调用点（全是 `moe.X.create`）一个都没改，全量用例 0 失败
- [x] 1.2 `server/core/loader/init.lua`：`local M = {}` + `return M` → `moe.loader = {}`（`M.DEFAULT_SOURCES` / `M.install` / `M.declareDepends` 与内部互调一并改），去掉 `return M`
- [x] 1.3 `server/core/init.lua`：`moe.X = include 'core.X'` 全部改成 `include 'core.X'`，去掉没人用的 `return moe`
- [x] 1.4 没有工厂的类不建门面：取消 `moe.effect`（`core/effect.lua` 没有 API 表，原来赋的是 `nil`）；`core/init.lua` 保留 `include 'core.effect'` 只为登记重载

## 2. 会话：同形状

- [x] 2.1 `server/session/init.lua`：`---@class Server` + `local M = {}` + `return M` → `---@class Server` + `moe.server = {}`（`Phase` / `started` / `start` / `stop` / `isStarted` / `getSession` / `hasSession` / `createSession` / `destroySession` 全部改到 `moe.server.*`）
- [x] 2.2 `server/moe-kill.lua`：`moe.server = require 'session'` → `require 'session'`

## 3. 类型：只写一处

- [x] 3.1 `server/moe-kill.lua` 的 `MoeKill` 删掉 `card` / `zone` / `orderedZone` / `random` / `attribute` / `event` / `loader` / `desk` / `player` / `game` / `askCard` / `moveCard` / `useCard` / `damage` 字段（赋值处的 `---@class` 已经定了类型），只留 `inspect`
- [x] 3.2 验证（hover）：`moe.card.create` → `Card.API.create(label?: any) -> Card`；`moe.loader` → `Loader { DEFAULT_SOURCES: string[], declareDepends, install }`；`moe.server` → `Server { … }`；全局 `moe` 的类型里带 `card: Card.API` / `askCard: AskCard.API` 等

## 4. 规格与文档

- [x] 4.1 `openspec/specs/kernel-facade/spec.md`：门面清单补 `moe.askCard` / `moe.moveCard`、去掉 `moe.effect`；新增「门面 SHALL 由模块自己建」；「`Effect` API 表为空表」改成「MUST NOT 建门面」；装载器改成「同样 `moe.loader = {}`」；场景同步（新增「门面在模块里建，不在 init 里拼」，重写「没有工厂的类不建门面」）
- [x] 4.2 `moe-kill-dev/references/code-style.md` §5：模块骨架示例与「内核对象模块」那条改成新形状（含 `session` 同形状、`core/loader` 内部子模块是例外）；§6 的 `any` 例子换成 `moe.inspect`
- [x] 4.3 `moe-kill-dev/references/architecture.md` §1 / §8.4 / §9：门面口径与「不许挂模块门面」的理由同步（门面由模块自己建 ⇒ 重载即换新表）

## 5. 验收

- [x] 5.1 `openspec validate --all` 通过（25 项）
- [x] 5.2 问题面板 information 及以上 = 0
- [x] 5.3 `server/bin/moe-kill.exe --test`：303 用例 0 失败
