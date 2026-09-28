# Tasks

> 基线（2026-09-28 实测）：`server/bin/moe-kill.exe --test` = 566 用例 / 0 失败 / 事件循环迭代 14 次。
> 完成后（2026-09-28）：**564 用例 / 0 失败 / 迭代 13 次 / 墙钟 ≈3.35 秒**（用例数差 = 删掉 3 条异步文件用例、新增 1 条 `poll` 用例）。

## 1. 新等待器

- [x] 1.1 新增 `server/loop-waiter.lua`（名字待确认）：持有一个 `bee.epoll` 实例 + 自唤醒 channel，对外 `wait(seconds)` / `poll()` / `wake()` / `watch(fd, onReadable)`，验证：新增用例覆盖「等 fd 可读」「纯超时」「`wake` 打断」「`poll` 非阻塞」四种，全部通过
- [x] 1.2 风格对齐现有约定（门面由模块自己建、一行中文说明、`---@class` 注解、`error` 只用于报错），验证：问题面板 information 及以上 0

## 2. 接线与删除

- [x] 2.1 `server/moe-kill.lua` 把 `moe.asyncIO` 换成新等待器（含 `eventLoopOptions` 的 `waiter` / `waker` 与那个 `poll` 高优先级任务），验证：`server/bin/moe-kill.exe --test` 全量 0 失败
- [x] 2.2 删掉 `server/async-io.lua` 与 `server/test/async/file.lua`；把 `server/test/async/wake.lua` 改写成针对新等待器的用例；同步 `server/test/async/init.lua` 的套件清单，验证：`--test` 全量 0 失败
- [x] 2.3 确认全仓不再 `require 'bee.async'`、不再有 `asyncIO` 的引用，验证：`grep` 两处均无结果

## 3. 验收与文档

- [x] 3.1 与基线对比：用例数、**事件循环迭代次数**、总耗时，验证：0 失败，且迭代次数与耗时不变差（历史上换等待器出过忙等事故：0.07 秒 → 1.4 秒、迭代 61 万次）
- [x] 3.2 文档更新：`references/infrastructure.md` 第 6 节（等待与异步 I/O 接线 → 改成 epoll 等待器，文件 IO 改同步）、`references/architecture.md` §2 里「等待 / 唤醒由 `bee.async` 承担」那句，验证：逐条对照代码确认无出入

