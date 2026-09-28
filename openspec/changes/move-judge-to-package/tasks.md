# Tasks

> 已实施（2026-09-28）：8/8 完成。验收基线 565 → **561 用例 / 0 失败**（删内核判定套件 5 条、`rule.judge` 补 1 条），问题面板 0。

## 1. 注入 New（内容侧能造实例）

- [x] 1.1 `server/core/loader/init.lua` 的注入项加 `New`（与内核全局 `New` 同一个 `class.new`；与 `Card` / `Depends` / `Class` 同批、纳入「每个文件加载前刷回」），验证：内容侧 `Class('X', 'Effect')` + `New 'X' (...)` 能造出实例
- [x] 1.2 用例断言 `Extends` / `Delete` / `Type` / `Presize` 在内容侧仍够不着，验证：该用例通过
- [x] 1.3 `architecture.md` §9.6 的注入清单从四项改成五项（`game` / `Card` / `Depends` / `Class` / `New`），并把「内容侧能声明 `Effect` 子类并造实例」（含 `New` 的两步写法与「第二个参数别传东西」）写进那一节，验证：逐条对照代码确认无出入

## 2. 判定搬进 @基础（与删内核那份同一批）

- [x] 2.1 `package/@基础/判定.lua` 写新版：`Class('判定', 'Effect')` + 重写 `getTempZone()` 为自建 + `replace()`/`replaced` 账 + 窗口守卫（`replacing` + `__close` 守卫）+ 阶段顺序（三次 `game:fire`）+ `Game:judge` 入口（`Class 'Game'` 装上）+ 原有的「翻牌」钩子，验证：`server/bin/moe-kill.exe --test rule.judge` 与 `rule.game-over` 全通过
- [x] 2.2 删内核那份：`server/core/effect/judge.lua`、`server/core/effect/init.lua` 里那行 `include`、`server/core/game.lua` 的 `M:judge`、`server/core/loader/env-meta.lua` 的三条 `'判定-*'` 声明，验证：`--test` 全量 0 失败、全仓不再有 `Judge` / `moe.judge` 的引用
- [x] 2.3 `package/@基础/meta.lua` 收窄三个判定时机的 `Game:on` / `Game:fire` 重载，验证：内容侧 `game:on('判定-前', function (judge) … end)` 能按名收窄、问题面板 information 及以上 0

## 3. 用例与文档

- [x] 3.1 删 `server/test/core/effect/judge.lua` 与 `server/test.lua` 里的套件行；内核套件里值得留的断言（`kind` / `replaced` 顺序 / 窗口守卫）补进 `rule.judge`，验证：`--test` 全量 0 失败、覆盖不倒退
- [x] 3.2 文档：`architecture.md` §12 的效果族落点表里去掉 `judge`（并说明「效果子类可以由内容侧声明」）、`progress.md` 记基线变化，验证：逐条对照代码确认无出入
