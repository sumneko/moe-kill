# Proposal

## Why

规则集要能挂到**时机**上才有意义（「游戏开始」时分身份、改体力上限，回合各阶段触发技能……）。现在 `moe.rule` 只有「定义条目」（`rule.card`）这一种登记方式，规则文件**没有任何挂载点**，身份场这类"模式规则"就没法实现 —— 底层只管记录，具体怎么分身份、怎么改数值，全靠规则文件在恰当时机出手。

## What Changes

- 新增**事件（时机）机制**：按**时机名**分发，内核提供机制（薄封装项目已有的 `moe.sevent`），实例由规则门面持有。
- 规则集侧新增**加载期注册**：`rule:on('游戏开始', function (ctx) ... end)` —— 与 `rule.card` 一样只在加载过程中可用，**按注册顺序**执行，返回 disposer。
- 新增**触发**接口 `rule:fire('游戏开始', ctx)`：供装配/流程代码与无头测试使用；规则集文件里只拿到 `rule`，时机名**不预设**（字符串由规则集自由使用）。
- **覆盖靠注册顺序**：后注册的回调后执行，它写下的状态（如身份标签、属性）自然覆盖先前的 —— 因此**不需要**"回调函数当参数/返回值改载荷"那套机制。
- **清空重载时事件注册一并清空**（与规则表同生命周期）；回调继承统一错误报告（`xpcall(cb, log.error, ...)`，一个回调报错不打断其余回调）。

## Capabilities

### New Capabilities

- `game-events`: 时机注册（加载期、按注册顺序、返回 disposer、随清空重载清空）、时机触发（按名触发 + 上下文、错误隔离）。

### Modified Capabilities

- 无（本变更不改既有能力的要求；`rule-loading` 的定义入口语义不变）。

## Impact

- 新增 `server/core/event.lua`（`Core.Event`，机制）、`server/core/init.lua` 挂 `moe.core.event`。
- `server/rule/init.lua`（门面）：持有事件实例、新增 `rule:on` / `rule:fire`、`load` 时重置事件注册。
- 测试：`server/test/core/event.lua`（机制）与 `server/test/rule/event.lua`（规则集侧注册 + 清空重载）。
- 文档：`moe-kill-dev/references/architecture.md` 新增「时机与事件」一节（并写清依赖方向：**实例由规则门面持有、机制在内核**，内核不反向依赖规则）；`sanguosha-rules` 的规则集侧写法补注册示例、时机系统那一节指向落地机制。
- 后续：`add-base-rules`（内核 `Desk` / `Player` 最小形状、`package/基础`、`package/身份场`、`package/标准` 牌表、开局装配）在它之上做；互斥 / 预解析 / 包元信息仍作为那批的前置项。
