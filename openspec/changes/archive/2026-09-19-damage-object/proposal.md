# Proposal

## Why

伤害现在是一次**方法调用**加一个**匿名表上下文**（`game:damage(来源, 目标, 点数)`，时机里收到 `{ from, to, amount }`）。这套形状撑不住接下来的功能：改伤害值、防止伤害、属性伤害（火 / 雷）、伤害来源追溯 —— 它们都需要「这次伤害」是一个**能传递、能携带行为**的对象，而不是一次性散落的三个值。

用户 2026-09-19 要求：伤害分装成一个类，造成伤害的时候得有个实例。

## What Changes

- **新增内核类 `Damage`**（`server/core/damage.lua`，门面 `moe.damage`）：每次造成伤害产生一个实例，携带 **来源 / 目标 / 点数**（可读字段）与**它所属的局**；工厂是 `moe.damage.create { game, from, to, amount }`，结算入口是 `:apply()`。
- **`game:damage(来源, 目标, 点数)` 降级为便利入口**：内部等价于「建一个伤害实例并立刻结算」—— 规则包与现有调用方的写法不变。
- **伤害时机的上下文就是这次伤害的实例**（不再是匿名表 `{ from, to, amount }`）：`ctx.from` / `ctx.to` / `ctx.amount` 的读法不变，但 `ctx` 现在是一个有类型、有方法的对象；`Game.EventCtx.伤害` 这个纯类型撤掉，直接用 `Damage`。
- **本批仍不做**：伤害值修改、伤害防止、属性伤害（它们将来作为 `Damage` 上的接口与字段补，本批只把对象立起来）。

## Capabilities

### Modified Capabilities

- `core-damage`: 「造成伤害」改成「伤害对象 + 结算入口（并保留便利入口）」，「伤害的时机」的上下文改成这次伤害的实例
- `kernel-facade`: 门面清单增加 `moe.damage`

## Impact

- **内核**：新增 `server/core/damage.lua`；`server/core/game.lua` 的 `damage` 改成便利入口；`server/core/init.lua` 挂 `moe.damage`；`server/core/loader/env-meta.lua` 的伤害时机上下文改用 `Damage`；`server/moe-kill.lua` 的类型注解补 `moe.damage`。
- **规则包**：`package/标准/卡牌/杀.lua` 不用改（仍调 `game:damage(...)`）。
- **测试**：`server/test/core/damage.lua` 补「实例」相关用例（建实例不结算不扣血、`:apply()` 之后才扣、时机上下文是同一个实例、便利入口与手写两步等价）。
- **文档**：`moe-kill-dev` 的 `architecture.md` 第 12 节、`sanguosha-rules/SKILL.md` §7。
