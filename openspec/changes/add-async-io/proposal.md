# Proposal

## Why

事件循环目前在"刚启动的一秒内把事情办完"和"积压时"会**完全不休眠地空转**（`getIdleTime() < 1` 就不 sleep）。这套忙等启发式是从 LuaLS 4.0.0 照搬来的，动机是「阻塞 IO 丢在工作线程、用 channel 回传，忙等好让回传被尽快处理」。

但本工程**没有任何工作线程与 channel**，文件读写也全是同步 `io.open`；那个忙等现在纯粹空转：全量测试从 0.07 秒涨到约 1.4 秒、事件循环迭代 61 万次，服务模式空转时也白烧 CPU。

bee.lua 现在自带跨平台异步 I/O（`bee.async`，Windows 走 IOCP、macOS 走 GCD、Linux 走 io_uring/epoll），实测在本工程 exe 上可用：`asfd:wait(timeout)` 能精确阻塞（空等 200ms = 200ms，0 完成事件），异步文件读回数据正确，`submit_poll` 可直接监听 channel 的 fd。也就是说「等待」和「被唤醒」都能交给内核，**忙等可以整体去掉**。

## What Changes

- **去掉忙等**：事件循环空闲时改为**阻塞等待到「下一个定时器到期时间」**；没有任何定时任务时**无限期阻塞**（不再周期唤醒），并删除 `busyTime` / `markBusy` / `getIdleTime` 这套忙等启发式。等待由注入的 waiter 承担，`tools/` 不反向依赖上层模块。
- **即时停止（自唤醒通道）**：循环持有自唤醒通道（线程通道 + 可读事件注册），`stop()` 立即唤醒阻塞中的循环并退出，**不依赖周期唤醒**；该机制同时是「外部事件源唤醒接线」的第一处用例。
- **定时器提供到期时间**：`tools/timer.lua` 增加「下一个到期时间」查询，供循环计算等待时长。
- **异步 I/O 模块**（本工程自有，`script/async-io.lua`）：持有 `bee.async` 实例，提供
  - 异步文件读/写（协程挂起等待完成事件，不阻塞循环）；
  - 完成事件分发（把完成结果按登记关系交回挂起的协程）；
  - 通道 / socket 的唤醒接线：用 `submit_poll(channel:fd())` 监听可读，完成事件到达即唤醒循环（**替代**原来的忙等，为将来的网络层预留通道）。
- **接线**：`script/moe-kill.lua` 挂 `moe.asyncIO`，把基于 `bee.async` 的 waiter 注入事件循环，并把完成事件分发挂成高优先级任务；`test.lua` 去掉「每次睡眠虚拟推进 1000ms」的 sleeper 兜底。
- **测试**：新增 `test/async/` 套件（异步读写往返、通道通知唤醒、**空闲时不增长迭代次数**即不忙等），既有 `test/smoke/eventloop.lua` 里依赖 `getIdleTime` 的用例随之调整。
- **记账**：`tools/` 下这两个文件从此与上游分叉，在 `moe-kill-dev` 技能里新增「本工程对 `tools/` 的改动清单」，逐条写清改了什么、为什么，避免以后从上游同步时被覆盖。

非目标：不引入子线程 / 工作线程；不做网络传输层与 socket 业务（只做唤醒接线）；不改协议与游戏逻辑；异步文件读写只做「整文件读 / 写」，**大文件分批读取的优化优先级降低**，本次不做。

## Capabilities

### New Capabilities

- `async-io`: 进程无事可做时如何等待、以及如何被 I/O 完成事件唤醒 —— 事件循环的空闲等待（不得忙等）、异步 I/O 实例与完成事件分发、异步文件读写、通道/socket 唤醒接线。

### Modified Capabilities

（无。`openspec/specs/` 仍为空：`setup-backend-infra` 尚未归档，其 `backend-runtime` 尚未落盘为主规格，因此本变更以新增能力表达，不写 MODIFIED 增量。）

## Impact

- **新增**：`script/async-io.lua`、`test/async/`（含 `init.lua` 与用例文件）。
- **修改（会与上游 4.0.0 分叉，需记账）**：`script/tools/event-loop.lua`（去忙等、等待改注入）、`script/tools/timer.lua`（新增下一个到期时间查询）。
- **修改**：`script/moe-kill.lua`（挂 `moe.asyncIO`、注入 waiter、挂完成事件分发）、`test.lua`（去掉虚拟时间 sleeper）、`test/smoke/eventloop.lua`（随忙等启发式一起调整用例）、`.agents/skills/moe-kill-dev/`（tools 改动清单 + 基础设施说明）。
- **依赖**：`bee.async`（已随 bee.lua 构建产物提供，实测可用）。不新增第三方依赖。
- **不影响**：外壳 `script/server/`、协议、游戏规则、前端。
