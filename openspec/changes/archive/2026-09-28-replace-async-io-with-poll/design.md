# Design

## Context

现状与约束（读代码 + 探针实测得出，动机见 `proposal.md`）：

- `server/async-io.lua` 是本工程**自有**的接线层（与 `server/` 根下的 `master.lua` / `main.lua` 同层；`server/tools/` 是照搬件，不动）。它对外是 `wait` / `poll` / `wake` / `watch` / `readFile` / `writeFile`。
- 事件循环的契约在 `server/tools/event-loop.lua`：`start(options, errorHandler)`，options 注入 `waiter(seconds)` / `deadline()` / `waker()`；空闲时等待到「下一个定时任务到期」（见 `references/infrastructure.md` 第 6 节）。
- 历史上删过一次忙等：上游的忙等是为「worker 线程 + channel 回传」设计的，本工程当时没有线程 ⇒ 忙等只剩空转（**全量测试 0.07 秒 → 1.4 秒、事件循环迭代 61 万次**）。这条决定了本次替换的验收口径。
- `bee.epoll`：跨平台 epoll 风格 API；Windows 上走 `bee/net/bpoll_win.cpp` → `bee/win/afd/`（**AFD/IOCP**），能等管道。
- `bee.select` **不行**：`binding/lua_select.cpp` 用 winsock `select()` + `SOCKET` fd_set，**只能等 socket**；而 channel 的 event 是**匿名管道**（`bee/net/event.h`：`fd_t pipe[2]`）。
- **实测（2026-09-28，探针已删）**：`epoll.create(16)` + `event_add(channel:fd(), epoll.EPOLLIN, tag)` → `true`；另一线程 200ms 后 `push` ⇒ `wait(3000)` 在 **201ms** 返回（`tag` / `1` 都拿得到）；无消息时 `wait(150)` 在 **153ms** 返回。

## Goals / Non-Goals

**Goals:**

- 去掉 `bee.async` 与 `async-io.lua` 那套抽象（`associate` / re-arm / 兼职两种语义的 `Register`）。
- 保住**唯一必需**的能力：等到下个 deadline、或被打断；并把「注册外部 fd」这个**位置**留给 transport / worker。
- 全量用例 0 失败，**事件循环迭代次数与耗时不变差**。

**Non-Goals:**

- 不做 transport（socket 接线那一层）。
- 不引入线程 / worker（那是 `add-worker-mode`）。
- 不改 `tools/event-loop.lua` 的对外契约（`waiter` / `deadline` / `waker` 形状不变）。
- 不做异步文件 IO（改同步）。

## Decisions

### D1. 用 `bee.epoll`，不用 `bee.select`，也不保留 `bee.async`

- `bee.select` 在 Windows 上只能等 socket，等不了 channel 的管道 fd（见 Context 的源码证据）⇒ 不能用。
- 保留 `bee.async` 的代价是留着那套糟糕抽象；而它换来的能力 `bee.epoll` 一样有（同一个 AFD/IOCP 底座），API 却只有四个方法。
- 实测已确认 `bee.epoll` 能等到 channel 的管道 fd。

### D2. 保留「等待器」这一层与它的四个入口

对外仍是 `wait(seconds)` / `poll()` / `wake()` / `watch(fd, onReadable)`，只换实现。

- 理由：`watch` 的**位置**将来一定要有人占（transport 接前端、worker 收 master 消息都要「fd 可读时叫我」）；放在这里正好就是「**本 VM 的 fd 多路复用上下文**」（一个 epoll 实例，所有事件源注册在它上面，由 `wait` 统一驱动）。
- 备选：只保留 `wait` / `wake`（模块更小），`watch` 等 transport 批再谈 —— 但那时还是要建一个 epoll 上下文，反而多一层。
- 顺带好处：`poll()`（非阻塞排空）与 `wait(seconds)` 是同一个 epoll 的两种超时参数，代码上天然收敛。

### D3. 自唤醒通道保留，语义不变

`wake()` 仍是**瞬时**信号（push 一次到自唤醒 channel，`wait` 立刻返回）。自唤醒 channel 注册进 epoll，因此**不再需要** `associate` + re-arm 那套：epoll 是水平触发的「注册一次、每次可读都报」，`onReadable` 里把 channel 排空即可。

### D4. 文件 IO 一律同步

今天没有并发 IO 需求；一局一线程落地后，worker 阻塞只影响自己那一局。真需要异步时再谈（那时也应该是「把 IO 丢给另一个线程」，而不是把完成事件编进本线程的循环）。

### D5. 落点与命名

新文件放 `server/` 根（与 `async-io.lua` 同层，`server/tools/` 是照搬件不动），门面挂在 `moe` 上（`moe.loopWaiter`）。名字待确认（备选：`event-waiter.lua` / `poll.lua`）。

### D6. 验收口径

1. `server/bin/moe-kill.exe --test` **0 失败**；
2. **事件循环迭代次数与总耗时对比基线不变差**（基线：566 用例 / 0 失败 / 迭代 14 次）—— 换等待器最容易在这里翻车（历史上的忙等事故就是这条）；
3. 全仓不再出现 `bee.async`。

## Risks / Trade-offs

- [等待器写成轮询 ⇒ 事件循环空转、迭代暴涨、测试变慢] → `wait(ms)` 必须把超时真交给 `ep:wait(ms)`（`poll()` 才用 `wait(0)`）；验收第 2 条盯死它。
- [AFD 只在本机 Windows + 这个 bee 版本上验过] → 换的是**跨平台** API（Linux 走 epoll 是它的本行）；仓库日常在 Windows，先按 Windows 验收并记下结论。
- [`watch` 的回调在 `wait` 里同步执行，回调里再 `wake()` 的时序] → 沿用「瞬时信号」口径；回调只负责取走数据、不要在里面阻塞。
- [删 `async-io.lua` 动到冻结规格里的能力名] → 探索期口径：不改主规格，记录成历史快照。
- [新文件命名与门面名是拍脑袋定的] → 已列入 Open Questions，落地前确认。

## Migration Plan

1. 新增等待器 + 针对它的用例（等 fd 可读 / 纯超时 / `wake` 打断 / `poll` 非阻塞）。
2. `server/moe-kill.lua` 接线切到新等待器，跑全量用例。
3. 删 `server/async-io.lua` 与 `server/test/async/file.lua`；改写 `server/test/async/wake.lua`；同步 `server/test.lua` 的套件清单。
4. 文档两处（`infrastructure.md` 第 6 节、`architecture.md` §2）。

回滚：第 1~3 步期间**先不删** `async-io.lua`，接线是新旧可切的；确认全量通过后再删（删完仍可 `git` 恢复）。

## Open Questions

- 新文件 / 门面的名字（`loop-waiter.lua` / `moe.loopWaiter`？）。
- `watch` 的注册形状要不要等 transport 批再定（现在只做 `event_add` 的薄封装，够不够）。
