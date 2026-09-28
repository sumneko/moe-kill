# Proposal

## Why

现在内容包只拿到注入的 `game` / `Card` / `Depends`，**拿不到内核类表**。带来两个后果：

1. **规则侧自己提供的能力写不成对象方法**：`@基础/距离.lua` 只能给一个裸全局 `distance(from, to)`，调用点读起来是 `distance(user, target)`，而不是 `user:distance(target)`（3 个调用点：`杀.lua` / `借刀杀人.lua` / `顺手牵羊.lua`）。
2. **mod 无法整段替换内核行为**：只能在内核**选定的时机接缝**上挂回调（`game:on('伤害-生效', …)`），没法把「伤害这件事」整体换掉。

用户 2026-09-28 定：**解锁「包可以直接修改内核基类」**（`Player` / `Game` / `Card` / `Zone` / `Effect` …），书写方式**与内核同形**。

（本变更只做规划；实施时机由用户另定。一局一个 VM 的隔离见 `add-worker-mode` —— 那条落地后本文的「全局」语义自动变成「按局」，其余不变。）

## What Changes

- **加载环境注入 `Class`**，与内核的全局 `Class` 是**同一个函数**（`server/moe-kill.lua` 里 `Class = class.declare`）。包按内核的写法给类加方法：

  ```lua
  ---@class Player
  local M = Class 'Player'

  --- 距离（谁到谁）
  ---@param to Player
  ---@return integer
  function M:distance(to)
      ...
  end
  ```

  `---@class Player` 就够了，**不用**写 `: Class.Base`；只有要用 `__getter` / `__setter` 时才把基类写全（它们声明在 `Class.Base` 上，写全只是为了让 LuaLS 满意）。

- **只开 `Class` 这一个口子**：`New` / `Delete` / `Extends` / `Type` / `Presize` 都不注入（要再加另说）。
- **没有生命周期管理**（用户 2026-09-28 定）：规则集**加载一次、之后不卸载**，一局一个 VM；所以不记账、不回撤、不检测重装。装上去的方法活到 VM 销毁。
- **护栏从「内核挡」降级为「文档提醒」**：不走收口函数就没有地方挡。只提醒两件事 —— 别用 `__` 开头的名字（框架私有前缀）、别与 `__getter` / `__setter` 同名（那会把派生属性读成函数）。VM 隔离是兜底。
- **保留的语义**：类表在 VM 内一份 ⇒ 该方法对**这个 VM 里的所有局**生效（一局一个 VM 落地后，就是「这一局」）。
- **首个应用**：`@基础/距离.lua` 的裸全局 `distance(from, to)` **去掉**，改成 `Player` 上的 `distance`；三个调用点改读 `user:distance(target)`（用户 2026-09-28 定，含删除那个全局）。

## Capabilities

### New Capabilities

无。本变更属探索期的**架构决策记录**，不写规格增量（`.openspec.yaml` 设 `skip_specs: true`）。

注：这正是「**只有真要长期稳定的对外契约才写规格**」里那类候选（包作者可见的类型契约），但它现在还没稳住 —— 口子形状、护栏、与 VM 隔离的关系都在这次变动里。等它稳住并且用户确认要冻结，再单独开变更写规格。

### Modified Capabilities

无（同上）。`rule-loading` 规格描述的是「清单 / 依赖 / 路由 / 规则数值」，本变更加的是**另一条通道**（类表），不改既有要求；`openspec/specs/` 已冻结，不回头改。

## Impact

- `server/core/loader/init.lua`：注入项除 `game` / `Card` / `Depends` 外再加 `Class`，以及「每个文件加载前刷回注入项」这条既有机制要把它一起刷。
- `server/core/loader/env-meta.lua`：`Class` 的类型签名（包作者的契约面）。
- `package/@基础/距离.lua`：`distance` 改成 `Player` 的方法（顺带好处：用 `self.game:getDistance(self, to)`，不再依赖闭包捕获的注入 `game`）。
- 三个调用点：`package/标准/卡牌/{杀,借刀杀人,顺手牵羊}.lua`。
- 文档：`references/architecture.md` §9.6（内容侧书写环境）补一节「包可以给内核类加方法」；`references/progress.md` 记一条。
- 与 `add-worker-mode` 的关系：那条落地后「全局」自动变「按局」，本变更其余部分不变。
