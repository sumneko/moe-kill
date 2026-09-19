# Tasks

## 1. 类模块改返回门面

- [x] 1.1 `server/core/` 下的类模块（`card` / `zone` / `orderedZone` / `random` / `attribute` / `event` / `desk` / `player` / `game` / `useCard` / `damage`）：工厂从类上搬到 `---@class X.API` + `local API = {}` + `function API.create(...)`，`return API`（工厂原有校验原样搬过去）。验证：`--test` 全绿（调用点全是 `moe.X.create(...)`，不用改）
- [x] 1.2 `server/core/effect.lua`：API 表为空（基类没有工厂）
- [x] 1.3 `server/moe-kill.lua`：`moe` 的字段类型改成对应 API 类型（`card Card.API` / `desk Desk.API` / …）。验证：问题面板 information 及以上为 0
- [x] 1.4 实测门面生效：`moe.player.` / `moe.desk.` 的补全**只列出 `create`**；`moe.desk.create(3)` 的值类型仍是 `Desk`

## 2. 顺带修类型注解

- [x] 2.1 `server/core/loader/env-util.lua`：`---@field` 从内联泛型（LuaLS 推不出）改成非泛型。验证：`util.` 补全列出三个函数，`util.filter({1}, 1, 2)` 报参数过多

## 3. 文档与验收

- [x] 3.1 `code-style.md`：「内核对象模块直接返回类表」改成「返回门面表，只放工厂」（含类型命名与 `Effect` 的特例、装载器不适用）；`architecture.md` §1 补一句门面口径、§12 机制表把 `moe.effect` 那行改成类（门面无工厂）
- [x] 3.2 全量 `server\bin\moe-kill.exe --test` 0 失败（273 个用例）；问题面板 information 及以上为 0
- [ ] 3.3 `openspec validate --all --strict` 全通过；勾完任务 → 提交推送 → 归档 → 再提交推送
