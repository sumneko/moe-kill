# Proposal

## Why

「判定」现在的分工是**倒过来的**：

| 位置 | 量 | 干什么 |
| --- | --- | --- |
| 内核 `server/core/effect/judge.lua` | 74 行 | `Judge : Effect`：`getTempZone()` 重写为自建、`replace()` + `replaced` 账 + 窗口守卫、`settle()` 依次 fire `'判定-亮牌'` → `'判定-前'` → `'判定-后'`、`moe.judge.create` 工厂 |
| 内核 `server/core/game.lua` | 8 行 | `game:judge(player, reason)` 入口 |
| 内核 `server/core/loader/env-meta.lua` | 6 行 | 三条 `判定-*` 时机的载荷类型 |
| 内容 `package/@基础/判定.lua` | **8 行** | 只有「翻哪张牌」：`'判定-亮牌'` 里 `game:drawCards(judge.player, 1, judge:getTempZone())` |

内核那 74 行里**真正算规则的只有两处** —— 「判定分几个阶段」与「改判只能在亮牌之后、结果之前」；其余是机制（`Effect` 驱动、临时区、工厂、入口）。⇒ 判定该整体搬到内容侧。

卡点是：**内容侧造不出「一次结算」**。判定是一个 `Effect` 实例（临时区、收尾统一送弃牌、`parent`、记牌器都挂在它上面）；上次只注入 `Class`，内容侧能**声明** `Effect` 子类（`Class('判定', 'Effect')` —— 第二个参数就是 super，不需要 `Extends`）却**造不出实例**（实例化走全局 `New`，没注入；类表上的 `mt.__call` 要求类有 `__alloc`，而全仓没有一个类定义过它）。

用户 2026-09-28 定：走「乙」—— **补 `New`，让内容侧能自定义「一次结算」，判定整体搬进 `@基础`**。

## What Changes

- **加载环境注入 `New`**（与内核同一个 `class.new`），与 `Class` 配对：内容侧从此能声明 `Effect` 子类**并造实例**。`Extends` / `Delete` / `Type` / `Presize` 仍然不给（继承用 `Class` 的第二个参数就够）。
- **判定整体搬到 `package/@基础/判定.lua`**：`Class('判定', 'Effect')` + 自己写阶段顺序（三次 `game:fire`）、改判窗口守卫 + `replaced` 账、`replace()`、以及 `Game:judge` 入口（用 `Class 'Game'` 装上）。
- **内核删掉**：`server/core/effect/judge.lua`（`Judge` 类 + `moe.judge` 工厂）、`game:judge`、`env-meta.lua` 里三条 `'判定-*'` 声明。
- **时机名不变**（仍是 `'判定-亮牌'` / `'判定-前'` / `'判定-后'`），但**由内容侧 fire**：契约从「内核发射的接缝」变成「`@基础` 发射、依赖它的包订阅」—— 想要类型收窄就把重载写进 `package/@基础/meta.lua`（配方见 `architecture.md` §9.6）。
- **结算语义不变**：判定仍是「一次结算」⇒ 临时区照样自建、收尾照样由 `Effect` 基类把剩下的牌送弃牌、`parent` 与记牌器照旧。

## Capabilities

### New Capabilities

无。本变更属探索期的**架构决策记录**，不写规格增量（`.openspec.yaml` 设 `skip_specs: true`）。

### Modified Capabilities

无（同上）。

## Impact

- 加载环境：`server/core/loader/init.lua`（注入项加 `New`）。
- 内核：删 `server/core/effect/judge.lua`、`server/core/effect/init.lua` 里那行 `include`、`server/core/game.lua` 的 `M:judge`、`server/core/loader/env-meta.lua` 的三行。
- 内容：`package/@基础/判定.lua`（从 8 行长到 ~50 行）、`package/@基础/meta.lua`（若要做事件类型收窄）。
- 用例：`server/test/core/effect/judge.lua`（内核套件，随内核类一起删或缩成基类的事）、`server/test.lua` 的套件清单、`server/test/rule/judge.lua` 与 `rule/game-over.lua`（保留，它们测的正是内容侧行为）。
- 文档：`references/architecture.md` §9.6（注入清单从四项变五项）、§12（效果族的落点表里去掉 `judge`）、`references/progress.md`。
- 基线（2026-09-28）：565 用例 / 0 失败。
