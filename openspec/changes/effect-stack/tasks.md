# Tasks

## 1. 内核：效果基类与结算栈

- [x] 1.1 新增 `server/core/effect.lua`：`Effect` 类（持 `game` + 种类标识 `kind` 默认值）+ `Effect:apply()`（`local pop <close> = self.game:pushEffect(self)` → `self:settle()`）+ 基类 `settle()` 报「子类必须实现」。验证：问题面板 0
- [x] 1.2 `server/core/game.lua`：新增结算栈（私有字段 + `pushEffect` 返回撤销函数（不在栈顶时报错、重复调用安全、**超过 `MAX_EFFECT_DEPTH = 100` 时报错**）+ `getCurrentEffect()` + `getEffects()` 快照），`__init` 里初始化且**不参与清空重装**。验证：`--test core.effect` 用例通过
- [x] 1.3 新增 `server/test/core/effect.lua`（套件 `core.effect`）：结算期间在栈上 / 结束后退栈、嵌套结算回到外层、抛错也退栈、空栈查不到当前效果、快照不受后续影响、栈底 → 栈顶顺序、撤销函数精确弹出、乱序退栈被拒绝、重复撤销安全、**超过 100 层被拒绝且已有栈帧不受影响**；`server/test.lua` 注册

## 2. 内核：用牌改成效果

- [x] 2.1 新增 `server/core/use-card.lua`：`UseCard : Effect`（`require 'core.effect'` + `Extends('UseCard', 'Effect')`，`kind` = `useCard`），字段 `user` / `card` / `targets`；`settle()` = 取内容定义（查不到报错）→ 校验目标合法性（失败报错）→ 在 `user` 名下牌区定位并取出牌 → 按声明顺序跑「使用」回调（上下文 = 本实例）→ 触发 `'卡牌-结算后'`。把 `Game` 里的 `findHeldZone` 一起搬过来
- [x] 2.2 `server/core/game.lua`：`game:play(...)` 改成便利入口（`moe.useCard.create { game = self, user = user, card = card, targets = targets }:apply()`）
- [x] 2.3 `server/core/loader/env-meta.lua`：牌回调与 `'卡牌-结算后'` 的上下文改成 `UseCard`（撤掉 `Game.EventCtx.卡牌`）；`server/moe-kill.lua` 注解补 `moe.effect` / `moe.useCard`
- [x] 2.4 `server/test/core/play.lua` 补用例：上下文是 `UseCard` 实例（含 `ctx.user` / `ctx.card` / `ctx.targets`）、失败或抛错后栈恢复原状。验证：`--test core.play` 全绿
- [x] 2.5 既有 `--test rule.slash` 一行不改仍通过；`--test core.damage` 补「伤害结算期间在栈上」用例

## 3. 门面与加载顺序

- [x] 3.1 `server/core/init.lua`：挂 `moe.effect` / `moe.useCard`（顺序在 `core.damage` 之前，因为 `Damage` 继承 `Effect`）；`Damage` 补种类标识。验证：全量 `--test` 0 失败

## 4. 文档与验收

- [x] 4.1 文档同步：`moe-kill-dev` 的 `architecture.md` 第 12 节（机制表 + 结算栈语义、深度上限与恢复保证）、`moe-kill-dev/SKILL.md` 目录表（`effect.lua` / `use-card.lua`）、`sanguosha-rules/SKILL.md` §7（结算栈已实现到哪一步、还差什么）
- [x] 4.2 全量测试 0 失败、问题面板 information 及以上为 0、`openspec validate --all --strict` 全通过
- [x] 4.3 勾完任务 → 提交推送 → 归档 → 再提交推送
