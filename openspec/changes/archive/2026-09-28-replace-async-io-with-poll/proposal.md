# Proposal

## Why

`server/async-io.lua` 写得糟糕，而且它提供的东西大半**没有消费者**：

| 能力 | 真实消费者 |
| --- | --- |
| 事件循环空闲时「等到下个定时任务到期、或被打断」 | `server/moe-kill.lua` 的 `eventLoopOptions()`（唯一必需的一项） |
| 异步读写整个文件 | **只有 `server/test/async/file.lua`** —— 加载器读包文件早就是 `bee.filesystem` 同步接口 |
| 注册外部事件源（`watch`） | **只有 `server/test/async/wake.lua`** —— transport 还没做 |

糟糕之处（读代码得出）：`associate` 是 **Windows/IOCP 专属**且必须与 `submit_poll` 成对；每次完成事件还要**重新 arm**（`dispatch` 里再调一次 `arm(watch)`）；`Register` 一张表**兼职两种语义**（"等待方 `resolve`" 与 "事件源 `watch`"），靠有没有 `reg.watch` 分支；文件 IO 与事件源混在一个模块，`M.watch`（公开）与内部 `arm` 两套入口。

`bee.epoll` 提供同样的能力，API 只有 `event_add` / `event_mod` / `event_del` / `wait(timeout)`，干净一个数量级。**实测（2026-09-28 探针，已删）**：在 Windows 上 `event_add(channel:fd(), EPOLLIN)` 返回 true；另一个线程 200ms 后 `push`，`wait(3000)` **在 201ms 就返回**；无消息时 150ms 超时也准（153ms）。

删掉它同时去掉全仓**唯一的 `bee.async` 依赖**。

## What Changes

- **删掉 `server/async-io.lua`**，换成极小的**事件循环等待器**（新文件在 `server/` 根，与它同层；名字 `loop-waiter.lua`、门面 `moe.loopWaiter`，**名字待确认**）：持有本 VM **唯一一个 `bee.epoll` 实例** + 自唤醒通道，对外 `wait(seconds)` / `poll()` / `wake()` / `watch(fd, onReadable)`。
- **`wait` / `wake` 语义不变**（`wake` 仍是**瞬时**信号）；实现从 `bee.async` 的完成事件换成 `epoll:wait(ms)`。
- **文件 IO 一律同步**（`io.open`）：删 `readFile` / `writeFile`，连同 `server/test/async/file.lua`。
- **`watch` 换成 `epoll:event_add`**：仍是「本 VM 里注册外部 fd」的唯一入口，将来 transport / worker 的消息通道往它上面注册。
- 去掉 `bee.async` 依赖（全仓唯一处）。
- 冻结规格 `openspec/specs/async-io`（5 条 requirements）**不回头改**，成为历史快照。

## Capabilities

### New Capabilities

无。本变更属探索期的**架构决策记录**，不写规格增量（`.openspec.yaml` 设 `skip_specs: true`）。

注：`async-io` 这个能力名在**已冻结**的 `openspec/specs/async-io` 里存在，本变更让那一层退役 —— 按探索期口径不改主规格，等规则口径稳定后做一次性回顾性对齐。

### Modified Capabilities

无（同上）。

## Impact

- `server/async-io.lua`（删）、新文件 `server/loop-waiter.lua`、`server/moe-kill.lua`（`moe.asyncIO` 接线与 `eventLoopOptions`）。
- `server/test/async/file.lua`（删）、`server/test/async/wake.lua`（改写成针对新等待器的用例）、`server/test.lua`（套件清单）。
- 文档：`references/infrastructure.md` 第 6 节（等待与异步 I/O 接线）、`references/architecture.md` §2（「等待 / 唤醒由 `bee.async` 承担」那句）。
- **基线（2026-09-28 记录）**：`server/bin/moe-kill.exe --test` = **566 用例 / 0 失败 / 事件循环迭代 14 次**。替换后要求：0 失败，用例数按删改相应变化，**迭代次数与总耗时不变差**。
