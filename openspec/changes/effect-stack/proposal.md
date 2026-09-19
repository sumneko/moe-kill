# Proposal

## Why

现在「使用牌」与「造成伤害」都是**一调就结算完**的方法（`game:play` / `game:damage`），没有一个"正在结算什么"的概念。而接下来要做的功能全都是**可嵌套、可插入**的：闪把杀抵消、无懈可击连锁、技能在任意时机插结算、体力归零插入濒死 —— 没有一个**结算栈**，就没有"处理完插入的结算再回到原处继续"这件事，也无从知道"现在正在结算什么"。

用户 2026-09-19 要求：使用牌也要包在一个对象里、进入局的一个栈、等效果结算完退栈；名字用 `Effect`。

## What Changes

- **新增内核基类 `Effect`**（`server/core/effect.lua`，门面 `moe.effect`）：效果持有它所属的局，并带一个**种类标识**（`kind`；基类有默认值、子类覆盖）；`Effect:apply()` 的顺序是**压入结算栈 → 交给子类结算（`settle`）→ 退栈**；退栈 MUST 在正常结束、结算中抛错、校验失败三种情况下都发生。
- **新增内核类 `UseCard : Effect`**（`server/core/use-card.lua`，门面 `moe.useCard`）：「使用一张牌这次结算」的效果，`kind` = `useCard`，字段 `user` / `card` / `targets`；`settle()` = 校验（牌在使用者手上、有内容定义、目标合法）→ 把牌取出 → 按声明顺序跑该牌的「使用」回调 → 触发 `'卡牌-结算后'`。
- **`Damage` 改成 `Effect` 的子类**（`kind` = `damage`）：`:apply()` 也走结算栈，结算内容（触发「伤害-前」→ 改体力 → 触发「伤害-后」）不变。
- **局上新增结算栈**：`game:pushEffect(效果)` SHALL 返回**撤销函数**（精确弹出那一次压栈、重复调用安全）、`game:getCurrentEffect()`（正在结算的效果，空栈时不存在）、`game:getEffects()`（快照，栈底 → 栈顶）；栈 SHALL 有**深度上限 100 层**，超过时压栈以明确失败暴露（防递归无限展开）。
- **便利入口不变**：`game:play(使用者, 牌, 目标们)` 与 `game:damage(来源, 目标, 点数)` 分别是「造效果 + `:apply()`」，规则包与既有调用方写法不变。
- **牌回调与收尾时机的上下文改成这次 `UseCard` 实例**（`ctx.user` / `ctx.card` / `ctx.targets` 读法不变）—— 与伤害那批的形状统一，撤掉纯类型 `Game.EventCtx.卡牌`。
- **本批不加**入栈 / 退栈时机（沿用 `'卡牌-结算后'`，它在退栈之前触发）；也不做"效果的取消 / 替换"。

## Capabilities

### New Capabilities

- `core-effect`: 效果与结算栈 —— `Effect` 基类、`apply()` 的压栈 / 结算 / 退栈顺序与恢复保证、结算栈的压栈入口（返回撤销函数）、栈的只读查询

### Modified Capabilities

- `core-play`: 用牌改成「造 `UseCard` 效果并结算」，失败或抛错后栈必须恢复；回调与收尾时机的上下文是这次效果实例
- `core-damage`: `Damage` 成为 `Effect` 的子类（`:apply()` 也走结算栈）
- `kernel-facade`: 门面清单增加 `moe.effect` / `moe.useCard`

## Impact

- **内核**：新增 `server/core/effect.lua`、`server/core/use-card.lua`；`server/core/damage.lua`（改成继承 `Effect`）、`server/core/game.lua`（结算栈 + 两个便利入口，`play` 的四步搬进 `UseCard`）、`server/core/init.lua`（挂门面 + 加载顺序）、`server/core/loader/env-meta.lua`（牌上下文 → `UseCard`）、`server/moe-kill.lua`（注解）。
- **规则包**：`package/**` 不用改（`game:play` / `game:damage` 与 `ctx.user` / `ctx.targets` / `ctx.amount` 读法都不变）。
- **测试**：新增 `server/test/core/effect.lua`（栈语义：压 / 退 / 嵌套 / 抛错也退 / 快照 / 撤销函数精确且幂等）；`core.play` 补「效果实例与栈恢复」；`core.damage` 补「伤害结算期间在栈上」。
- **文档**：`moe-kill-dev` 的 `architecture.md` 第 12 节（机制表 + 结算栈）、`moe-kill-dev/SKILL.md` 目录表、`sanguosha-rules/SKILL.md` §7（结算栈已实现到哪一步）。
