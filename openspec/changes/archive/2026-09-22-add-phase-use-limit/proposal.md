# Proposal

## Why

出牌阶段的使用限制现在是一段临时写法（`package/@基础/使用限制.lua`）：阶段由内容侧自己 `fire`，「本阶段用过几次」挂在**玩家标签**上（要靠 `'阶段-开始' / '阶段-结束'` 两边手工清），限额是一张按**牌名**查的配置表。

将来会有**大量「出牌阶段限一次」的技能**——次数与限额得是内容定义自己的事（卡牌、技能各写在自己定义上），而「现在是哪个阶段、属于谁」得到内核里成为一个一等对象，否则每个包都要自己造一遍阶段概念。

## What Changes

- **内核：阶段成为一等对象**（`server/core/phase.lua` + `game`）
  - `game:enterPhase(player, name)`（玩家在前）建一个 `Phase` 实例并**返回它**：可当 `<close>` 变量用，作用域结束即离开阶段（`__close` → `Delete`）；`game.phase` 是当前阶段（没进阶段就是空）。
  - 阶段**可嵌套**（栈）：支持将来「额外的一个出牌阶段」；离开按嵌套顺序（LIFO）校验。
  - `'阶段-开始' / '阶段-结束'` 改由**内核**触发，上下文 = 这个阶段实例。**BREAKING**：原先的 `ctx.phase`（阶段名字符串）变成 `ctx.name`，`ctx.player` 不变。
  - 阶段实例带**通用标签袋**（`setTag / getTag / removeTag`，与 `Player` 同形状），并带**两本账**：本阶段某名字**已用几次**、某名字**上限增减**（下面两个接口读写它们）。
- **内核：内容定义带阶段限额接口**：`CardDef:limit(阶段名, 次数)`（链式、可多次调）/ `CardDef:getLimit(阶段名)`（**没为这个阶段声明过就返回 1000**）—— 阶段名是**不透明字符串**（内核只记、不校验取值）。既然内核已经认识「阶段」，限额就给一个专门的接口，不再借通用字段袋（用户 2026-09-22 定）。
- **基础规则**：`@基础/回合.lua` 改用 `game:enterPhase(player, 阶段名)` + `<close>`，不再自己 `fire` 阶段时机；**`@基础/使用限制.lua` 删除**（三件事分别被内核与牌定义接手，用户 2026-09-22 同意）。
- **内核：按次数的限制整套进内核**（用户 2026-09-22 定）
  - `game:canUse` 的**内建条目**多一条：阶段属于使用者时，本阶段该名字用过几次 < 上限 ⇒ 不通过就直接返回原因，**不再问内容侧**（不触发 `'卡牌-能否使用'`）；阶段不属于使用者（别人的回合）或不在任何阶段里 ⇒ 不判。
  - `game:useCard`（`UseCard:settle()`）在校验通过之后**由内核记一次**（同一个条件：只在自己的回合里记）。
  - 上限 = 内容定义声明的限额（`CardDef:getLimit(阶段名)`）**+ 阶段实例上的增减**。
- **阶段实例上两个调整接口**（都以「名字 + 次数变化」为参数，供卡牌 / 技能调用）：改本阶段**已用次数**（「此【杀】不计入次数」= -1）、改本阶段**上限**（「可以多用一次」= +1；「本阶段无限次」= +1000）；另有两个读接口。
- **标准包**：【杀】的限额随牌走：`Card '杀' : limit('出牌', 1)`，基础规则里不再有按牌名写的表。
- **文档**：`moe-kill-dev` 的 `architecture.md` / `progress.md`、`sanguosha-rules` 的阶段与次数口径同步。

## Capabilities

### New Capabilities

无（探索期不写规格：见 `openspec/config.yaml` 与 `AGENTS.md` 的「工作流」，本变更在 `.openspec.yaml` 里设 `skip_specs: true`，契约以用例为准）。

### Modified Capabilities

无（同上）。

## Impact

- 内核：`server/core/phase.lua`（新）、`server/core/game.lua`（`enterPhase` / 阶段栈 / `phase` 字段 / `canUse` 的次数条目 / `CardDef:limit`）、`server/core/effect/use-card.lua`（校验通过后记一次）、`server/core/init.lua`（include 清单）、`server/core/loader/env-meta.lua`（阶段事件 ctx、`Phase` 与 `CardDef:limit` 的类型）。
- 内容侧：`package/@基础/回合.lua`、`package/标准/卡牌/杀.lua`；**删除** `package/@基础/使用限制.lua`（用户 2026-09-22 同意）。
- 用例：`server/test/core/`（阶段的进入 / 离开 / 嵌套 / `<close>`、定义字段）、`server/test/rule/`（阶段时机事件、次数与两种口径）。
- 文档：`moe-kill-dev` 的 `references/architecture.md`（§10 时机清单、§12 接口表）、`references/progress.md`、`sanguosha-rules/SKILL.md`（§3 回合流程、§9.2）。
