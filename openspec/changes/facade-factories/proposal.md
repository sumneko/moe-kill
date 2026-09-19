# 内核门面只暴露工厂（不再直接暴露类表）

## Why

现在 `server/core/` 下的类模块**直接 `return` 类表**（`moe.player` 就是 `Player` 类）。后果是**类的实例方法也从全局可达**：`moe.desk.getDistance(a, b)`、`moe.player:getAttr(…)`、`moe.attribute.define(…)` 这类写法既能写、也不报错，读代码的人分不清「这是模块的公开入口」还是「随手拿类当工具箱」（用户 2026-09-19 提出：不希望从全局访问类的方法）。

## What Changes

- **类模块另起 `API` 表，只放工厂**：`server/core/` 里的类模块（`card` / `zone` / `orderedZone` / `random` / `attribute` / `event` / `desk` / `player` / `game` / `useCard` / `damage`）把工厂从类上搬到另起的表里 —— `---@class Player.API` + `local API = {}` + `function API.create(options) return New 'Player' (…) end` + `return API`，**类自己不再有 `create`**。
  - 于是 `moe.player.create { … }` 照旧可用，而 `moe.player.getAttr` / `moe.desk.getDistance` **根本不存在**（写出来就是 `nil`，拼错会当场失败）；类上其余的静态成员（如 `Card.__counter`）留在类上、不进 API 表。
  - **没有工厂的模块（`Effect`）API 表为空**；基类仍靠 `Extends('UseCard', 'Effect')` 继承，类名仍在类注册表里可用。
  - 纯模块（`moe.loader`）不受影响：它的公开入口本来就是模块自己的字段（`install` / `DEFAULT_SOURCES`）。
- **类型面跟随**：`server/moe-kill.lua` 里 `moe` 的字段类型从类名改成对应的门面类型。
- 顺带修一处**类型注解写法**：`server/core/loader/env-util.lua` 的 `---@field` 从内联泛型（`fun<V>(…)`）改成非泛型 —— **LuaLS 不支持在 `@field` 上写 `fun<V>`**（推不出元素类型，用户 2026-09-19 实测），改成非泛型后至少能拿到名字、参数个数与参数类型的检查。

## Capabilities

### Modified Capabilities

- `kernel-facade`: 类模块 SHALL 只以 `API` 表对外（只放工厂），类的方法 MUST NOT 从全局可达；API 表类型写成「类名.API」

## Impact

- **内核**：`server/core/` 下 12 个模块的返回值（`effect.lua` 为空门面）；`server/moe-kill.lua` 的 `moe` 字段类型。
- **调用点**：**不用改** —— 既有调用全是 `moe.X.create(...)`。
- **文档**：`code-style.md`（「内核对象模块直接返回类表」那条改写）、`architecture.md` §1 与 §12 的机制表。
