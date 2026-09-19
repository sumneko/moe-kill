# Proposal

## Why

内核类型名现在一律带 `Moe.` 命名空间前缀（`Moe.Game` / `Moe.Loader.Context` …）。这个前缀是历史遗留：它源自「内核 vs 规则」那套分层（`Core.*` → `Moe.*`），但自从门面拍平、装载器并进内核之后，整个工程只有 `moe` 一个命名空间，前缀只剩噪音 —— 它没有区分任何东西，却让每条注解都长一截。

用户在 2026-09-19 明确要求去掉它。

## What Changes

- **内核类名与类型注解去掉 `Moe.` 前缀**（**BREAKING**，面向类型面）：`Moe.Card` → `Card`、`Moe.Zone` → `Zone`、`Moe.OrderedZone` → `OrderedZone`、`Moe.Random` → `Random`、`Moe.AttributeSystem` → `AttributeSystem`、`Moe.Attributes` → `Attributes`、`Moe.Desk` → `Desk`、`Moe.Player` → `Player`、`Moe.Game` → `Game`、`Moe.CardDef` → `CardDef`、`Moe.Event` → `Event`、`Moe.Loader` → `Loader`。
- **从属类型保留「类名.子名」结构**：`Moe.Loader.Context` → `Loader.Context`、`Moe.Loader.PackageMeta` → `Loader.PackageMeta`、`Moe.Game.EventCtx.卡牌` → `Game.EventCtx.卡牌`、`Moe.Player.CreateOptions` → `Player.CreateOptions`。
- **运行时类名跟着走**：`Class 'Moe.Game'` / `New 'Moe.Player'` / `Extends 'Moe.Zone'` 里的字符串同步改成 `'Game'` / `'Player'` / `'Zone'`（注解与运行时类名必须同名）。
- **明令禁止加前缀**：`Moe.` / `Core.` / `Rule.` 这类命名空间前缀一律不再使用；不引入别的替代前缀（如 `MK.`）。
- **不动的东西**：运行时门面 `moe.*`（`moe.game` / `moe.loader` …）不变；会话与测试自己的类型命名空间（`Server.*` / `Test.*`）不在本次范围内。

## Capabilities

### Modified Capabilities

- `kernel-facade`: 类型名规则从「统一用 `Moe.` 前缀」改成「类名与注解直接用类名本身、从属类型用 `类名.子名`」，并明确禁止命名空间前缀
- `core-game`: 「局对象」需求里对类型的称呼跟随改名（`Moe.Game` / `Moe.Desk` / `Moe.Random` → `Game` / `Desk` / `Random`）
- `core-player`: 「玩家对象」需求里对属性实例类型的称呼跟随改名（`Moe.Attributes` → `Attributes`）

## Impact

- **代码**：`server/core/**`、`server/*.lua`、`server/test/**`（约 350 处，纯改名，不改行为）；`server/tools/`（照搬的上游文件）与 `package/` 规则包不受影响（它们不写类型注解）。
- **类型面**：`server/core/loader/env-meta.lua` 里注入环境与各时机上下文的类型名同步改名 —— 第三方包作者写的注解会跟着变（**BREAKING**，但当前没有第三方）。
- **规格与文档**：`kernel-facade` / `core-game` / `core-player` 三条需求的措辞，`core-game` 的 Purpose；`.agents/skills/**` 里的类型引用。
- **风险**：`Card` 这个名字在规则包里同时是**加载期环境函数**（`Card '杀'`）。类型名与全局函数名分属两个命名空间，LuaLS 能区分，但要在实现后用问题面板确认（`game` / `Card` / `Depends` 的调用点与 `Card` / `CardDef` 的类型位置都不报错）。
