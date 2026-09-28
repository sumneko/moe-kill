# Tasks

> 已实施（2026-09-28）：8/8 完成；全量用例 564 → **565**（+1 条「拿到 Class / 拿不到 New、Extends」的用例）、0 失败、问题面板 0。

## 1. 注入 Class

- [x] 1.1 `server/core/loader/init.lua` 的注入项加 `Class`（与内核全局 `Class` 同一个 `class.declare`；只在加载期可用，与 `Card` / `Depends` 同批，并纳入「每个文件加载前刷回」），验证：临时包用例用 `local M = Class 'Player'` 装一个方法，实例上调用成功
- [x] 1.2 ~~`server/core/loader/env-meta.lua` 给 `Class` 补类型签名~~ —— **实测不需要**：`moe-kill.lua` 里 `Class = class.declare` 这个全局赋值已经把（带 `---@generic T: string` 的）签名给了 `Class`，内容侧 `Class 'Player'` 直接解析成 `Player` 类，所以 `env-meta.lua` 不重复声明。验证：规则包调用点问题面板 information 及以上 0
- [x] 1.3 用例断言 `New` / `Delete` / `Extends` / `Type` / `Presize` 在内容侧仍够不着（只开了 `Class`），验证：该用例通过

## 2. 文档

- [x] 2.1 `references/architecture.md` §9.6 补一节「包可以给内核类加方法」：形状（与内核同形）、无护栏与三条提醒（`__` 前缀 / 与 getter setter 同名 / 实例字段遮蔽）、`Extends` 连带效应、类型面写法（含三条实测结论：可不写 `: Class.Base`；派生字段必须用 `---@type` 声明；函数写了 doc 就要把 `@return` 写全）、与 VM 隔离的关系，验证：逐条对照代码确认无出入
- [x] 2.2 `references/progress.md` 记一条（能力已解锁 + 与 `add-worker-mode` 的时序关系），验证：只读 `progress.md` 就能找到本变更

## 3. 首个应用：distance 上 Player

- [x] 3.1 `package/@基础/距离.lua` 改成 `---@class Player` + `local M = Class 'Player'` + `function M:distance(to)`（用 `self.game.desk` 取桌子，不再依赖闭包捕获的注入 `game`；签名标 `---@param to Player` / `---@return integer`），并**去掉裸全局 `distance`**，验证：`server/bin/moe-kill.exe --test rule.equip` 通过、问题面板 information 及以上 0
- [x] 3.2 三个调用点改读 `user:distance(target)`（`package/标准/卡牌/{杀,借刀杀人,顺手牵羊}.lua`），验证：`server/bin/moe-kill.exe --test` 全量 0 失败
- [x] 3.3 全仓确认没有残留的裸全局 `distance(` 调用、`lowercase-global` 诊断已消失，验证：`grep` 无结果 + 问题面板 information 及以上 0
