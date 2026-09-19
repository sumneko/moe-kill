# Design

## Context

- 内核类模块现在的形状（`code-style.md` 里曾经明确写过）：`local M = Class 'Random'` … `return M` —— 「模块的返回值就是类表」，所以 `moe.random.create(种子)` 能用，但 `moe.random.nextInt` 之类的实例方法也顺带暴露在全局。
- `Class 'X'` 把类登记在类注册表里，`New 'X' (...)` / `Extends('X', 'Y')` / `---@class X` 都**不依赖模块的返回值**。
- 实测（本次）：`moe.player.` 的补全只列出 `create`；`moe.<模块>.<不存在的东西>` 这种写法 LuaLS 不报（全局链上的字段检查偏松），但**运行期就是 `nil`** —— 误用会当场炸，而不是悄悄当类用。

## Decisions

### D1 API 表在模块里构造，而不是在 `core/init.lua` 里拼

模块自己最清楚自己的公开入口；`core/init.lua` 只做「挂到 `moe` 上」。于是改一个模块的工厂不会漏改别处，API 类型（`X.API`）也与模块同文件、一眼能看到。工厂里的校验（桌子座位数、玩家属性实例、建局参数）跟着工厂一起搬到 `API.create`。

### D2 API 表的类型叫「类名.API」

命名规则要求从属类型写「类名.子名」（`kernel-facade`），所以 API 表的类型名顺着写成 `Player.API` / `Desk.API`。它同时是 `moe` 上字段的类型（`server/moe-kill.lua`），于是 `moe.player.create { … }` 的返回类型照样推得出来（实测 `moe.desk.create(3)` 的值是 `Desk`）。

**类上不再放 `create`**（用户 2026-09-19 定）：工厂只存在于 API 表里，`New 'X' (...)` 才是类自己的实例化入口 —— 于是不会有「一份工厂两个入口」的问题。

### D3 `Effect` 的 API 表是空的

`Effect` 是基类、没有工厂，但它仍是 `core/` 下的一个模块（子类 `require 'core.effect'` 来做类登记与 `Extends`）。给它一个**空 API 表**有两个好处：所有内核模块的形状统一（都返回一张 API 表），并且 `moe.effect.*` 上没有任何方法可点（满足「类的方法不从全局可达」）。
**备选**：让 `effect.lua` 继续 `return M`（那就破了这条规则）、或把 `moe.effect` 从门面清单里删掉（少一个锚点，将来想暴露 `Effect` 自己的工具函数时还得加回来）。

### D4 顺带修 `util` 的类型注解写法

`---@class Loader.EnvUtil` 原本用内联泛型 `---@field filter fun<V>(list: V[], …): V[]`。**LuaLS 不支持这种写法**（用户 2026-09-19 实测：推不出元素类型），所以改成非泛型：

```lua
---@field filter fun(list: any[], predicate: fun(value: any): boolean): any[]
```

实测代价与收益：补全里 `util.` 只列出 `filter` / `map` / `contains` ✓，参数个数与参数类型仍然检查（`util.filter({1}, 1, 2)` 报参数过多、传非函数报类型不符）✓，**元素类型不再传递**（`filter(Player[])` 得到 `any[]`）。等 LuaLS 支持 `@field` 上的泛型（或换成 `---@overload` 组合）再补精确类型。

## Risks / Trade-offs

- [门面的方法调用只能拿运行期错，编辑期不一定报] → 这是「不存在」比「存在但用错」更安全的一面：`moe.player.getAttr` 是 `nil`，一调就炸；编辑器里补全也只给 `create`，不太可能写歪。
- [多了一层薄表（每个模块一个小表）] → 只建一次、不放热路径，代价可忽略。
- [`moe.effect` 变成空表后，`IsValid(moe.effect)` 之类的旧写法] → 仓库里没有这种用法（全量测试是证据）。

## Open Questions

- 将来 `Effect` 若要暴露类级工具（例如「按 `kind` 建效果」的注册表），是加进这个空门面，还是另立一个模块？等真有需求再定。
