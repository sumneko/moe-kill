# Design

## Context

现状与约束（动机见 `proposal.md`）：

- 单进程单 VM：`server/moe-kill.lua` 建门面与工具 → `require 'core'`（内核，`include` 可重载）→ `require 'session'`（会话外壳）；规则集由 `moe.loader` 读文件执行。**类表、加载器登记、事件表、日志、自唤醒通道都是进程一份**。
- 已验证的 `bee` 事实（2026-09-28：读 `3rd/bee.lua/binding/{lua_thread,lua_channel}.cpp` + 探针实测）：
  - `bee.thread.create(source, ...)` = 新线程 + 新 `lua_State`（独立 VM），入口是**代码字符串**，参数走序列化；线程内可用 `bee.*`。
  - 子 VM 载整个内核 ≈20ms（15ms CPU）、建局 + 4 玩家 + 开局 ≈13ms、VM 内存 ≈1.4MB、「起线程 → 能开局」≈33ms；`bee.channel` 往返 ≈2µs。
  - `bee.thread` **只有** `create / errlog / sleep / wait / setname / preload_module / id` —— **没有 kill / exit / detach**；入口返回即 `lua_close(自己的 state)`（整个 VM 与其中对象、闭包、channel 引用一起释放）。
  - `errlog()` 是**进程级共享队列**，一次一条，**不带线程 id**。
  - `channel.create(name)` 的名字**进程级唯一**，同名报 duplicate；`channel.destroy` 只是从名字表注销 + 清队列，**已 `query` 出去的 box 副本仍有效**。
  - 现成的进程级单例：自唤醒通道名（原 `server/async-io.lua`、现 `server/loop-waiter.lua` 里那句 `channel.create`，同进程第二个 VM 一启动就报 duplicate —— 探针实证）、日志落地文件、`moe.env` 由 `arg[0]` 推导。
  - 现成能力：`LoopWaiter.watch(fd, onReadable)` 能把任意 fd 挂进事件循环 ⇒ 挂 channel 的 fd 即可在事件循环里收跨 VM 消息。
- 项目既有硬约束：跨线程边界只传 plain data；决策点统一为「请求输入 → 挂起 → 恢复」；无前端也能跑完整对局；后端权威、前端无状态。

## Goals / Non-Goals

**Goals:**

- 一局 = 一个 VM：mod 覆盖内核 / 内容不再互相影响（类表天然各一份），一局的错误与内存随 VM 一起消失。
- **开发与测试以 worker 身份进行**（单局模式），不需要 master 就能开一局。
- master 后加时**不需要改动 worker** —— 边界即协议。
- 崩溃与错误**按局可观测、可上报**。

**Non-Goals:**

- 不做跨局共享（大厅、排行榜、观战）——master 批再做。
- 不做「恶意隔离」：同进程线程挡不住 C 栈打爆 / OOM / 原生崩溃，这条**明确打折**（见 Risks）。
- 不改内容包（`package/`）的书写环境与既有内核 API。
- 不实现 master 侧（本变更只记录决策；实施时机另定）。

## Decisions

### D1. worker 是「角色」，不是「线程」

worker = **跑一整局的那一坨**（内核 + 内容包 + 会话外壳 + 自己的事件循环驱动）。它既能被主线程**内联**跑（单局模式 / 测试），也能被丢进**子线程**跑（服务器模式）。

- 理由：`--test` 现在一把同步跑 566 用例（`game:damage()` 后立刻断言）；若 worker 永远是线程，全部用例要变异步并各付 33ms，收益为零。而「一局一个 VM」只在服务器模式才真的需要。
- 备选：worker 永远是线程 —— 测试代价大、收益无；**不采纳**。
- 与「每局一个 VM」的关系：单局模式下，那一局的 VM 就是**主 VM**（一个进程 = 一局，天然满足「每局重建」）；只有服务器模式才每局真的起一个线程。
- 代价：worker 侧不许依赖「我在哪个线程」（见 D7 的一致性约束）。

### D2. 边界即协议（worker ↔ master 说 JSON-RPC）

跨 VM / 跨线程只能传 plain data，而现有协议**本来就只有三种形状**：请求（前端 → 后端）、反向请求（后端 → 前端）、通知。这正好是 master 与 worker 之间需要的三种。

- 因此 master 只做**转发与调度**，不认识牌 / 阶段 / 胜负；worker 完全不知道前端长什么样（协议本来就是「一个后端对接多种前端」）；前端看见的是「master 转发过来的同一个协议」，重连全量同步也还是同一条链路。
- 备选：自造一层线程消息结构 —— 等于维护两套协议，且要重复解决「请求 / 响应 / 通知」这三件事；**不采纳**。
- 附带好处：**宿主可换**。将来真需要进程级隔离时，把 worker 丢进子进程即可（`bee.subprocess.spawn`，边界已经是协议，worker 代码不动）。

### D3. 通道命名拼 `thread.id`，且**不复用名字**

每个 VM 的自唤醒通道与跨 VM 消息通道都用 `名字 .. '#' .. thread.id`（主线程 `id` = 0，`bee` 保证每线程唯一）。

- 理由：`channel.create` 名字进程级唯一（同名 duplicate 直接报错）；`destroy` 之后名字**可以**复用，但如果旧持有者还攥着旧 box，就会与新 channel **同名不同对象** ⇒ 消息静默错乱。用唯一名字把整类竞态消掉；进程退出时 OS 一并回收，连 `destroy` 都不需要。
- 备选：全局递增计数器（要跨 VM 同步，得走 channel，绕圈）；随机数（可能撞）。

### D4. 线程退出靠「入口自己返回」+ 一条结束消息

- worker 入口跑自己的事件循环与消息循环，收到「结束」就 `return`（`bee` 没有强杀，只能请它自己退）。
- 主线程要知道「它结束了」：worker 在退出前往跨 VM 通道推一条「已结束」，主线程用 `LoopWaiter.watch` 挂那个 fd 在事件循环里收。
- **不用 `thread.wait`** —— 它会阻塞调用方，在主线程上等于卡住事件循环。
- 备选：只在最终关服时 `thread.wait`（可以，但不能作为常规路径）。

### D5. 关停顺序：请退出 → 取消 watch → 销毁通道

`asyncfd:cancel(fd)`（meta 里写明「通常在关闭 socket 前调用」）→ 再 `channel.destroy(名字)`。反序会留下「主线程还在 poll 一个已注销 channel 的 fd」的状态。

### D6. 错误与日志按局归属

`errlog()` 是进程级共享队列且不带线程 id ⇒ **不能**靠它判断错误属于哪一局。worker 自己捕获错误，并**在协议里上报**（错误作为一条消息/事件交给 master）；日志按 VM 分文件（或每行带局标识）。

### D7. worker 侧的「宿主无关」约束

为了让内联（单局 / 测试）与线程（服务器）行为一致，worker 侧代码：

- 不用 `thread.id` 做逻辑判断（它只用于**命名**）；
- 不用 `thread.wait` / `thread.sleep` 做同步（等待一律走事件循环）；
- 与外部的一切交互**只能**走协议消息（不许直接摸 master 的 Lua 对象、不许依赖「我在哪个进程」）。

判据：**同一份 worker 代码，放在主线程里跑与放在子线程里跑，行为必须一样** —— 这条同时是将来换子进程的安全网。

### D8. 去掉「卸载 / 重装」

用户 2026-09-28 定。理由：一局一个 VM 之后，**清理手段从「清单式回撤」变成「销毁 VM」** —— `lua_close` 把整个 VM 连同对象、闭包、订阅一起释放，不需要 `resetContent()` 那套簿记，也没有热重载的两条遗留限制（「删方法不生效」「老实例不重跑 `__init`」）。留着它只会多一套要维护的语义。

删除面（实施时逐条落地）：

- `server/core/game.lua` 的 `M:resetContent()`。
- `server/core/loader/init.lua` 里对它的调用与「清空局上的内容」那段（含 `game.sources` / `game.list` 的「省略即复用上一次」语义）。
- 依赖重装的用例：`server/test/core/game.lua`（三条）、`server/test/core/phase.lua`、`server/test/rule/flow.lua`、`server/test/rule/init.lua`。
- 文档：`references/architecture.md` §9.8「重装语义」整节，以及 §9.1 / §9.3 / §9.6 / §8.4 / 第 10 节里提「重装」的句子。

备选：保留重装、只靠它做「换规则」—— 与「每局新 VM」重复，且保留两套清理路径；**不采纳**。

### D9. 包清单在 VM 启动时就定死

清单是 **VM 的启动参数**，不是运行期可变的状态：服务器模式由 master 传入；单局模式自己做一个**简单的用户交互**来选择；无头测试直接用参数（`moe.game.create { packages = … }` 仍然是那个入口）。

备选：运行期随时换 —— 那就是 D8 删掉的那套；**不采纳**。

### D10. 本变更不实施

用户 2026-09-28 定：先把决策记下来。tasks 按批次写出，但**本变更不进入实施**，实施时机由用户另定。

## Risks / Trade-offs

- [同进程线程挡不住 C 栈打爆 / OOM / 原生崩溃，会带走整个进程] → 接受，这是**有意打折**：thread 方案挡的是「规则 / 内容写错」，不是「恶意或极端」。缓解：D2 的「宿主可换」保证将来上子进程时 worker 代码不动。
- [进程级单例漏改 ⇒ 同进程第二个 VM 启动就炸] → 逐项收口（自唤醒通道名、日志文件、根目录推导、引导入口），并加一条**双 worker 冒烟用例**（同进程起两个 worker，都能开到开局）。
- [每个 VM 一份内核 ⇒ 内存 ×N] → 实测 1.4MB / VM，可接受；一局结束 `lua_close` 全清，不需要 `resetContent` 式的清单维护。
- [删掉重装会动到既有用例与已冻结的 `rule-loading` 规格] → 冻结的规格不回头改（探索期口径）；用例按 D8 的清单删；`--test` 的验收基线会下降（记录新基线）。
- [热重载在多 VM 下语义变化] → 开发期以单局模式为主（内联跑，热重载照旧）；服务器模式改代码 = **重启 worker**（比广播 reload 更彻底）。
- [测试组织被打乱] → 切分：内核 / 内容包用例照旧单进程同步跑；只对「会话 / 协议」层加跨 VM 用例。
- [`thread.create` 的入口是代码字符串 ⇒ 引导方式] → 把 `server/bin/main.lua` 里那段 `package.path` 设置抽成可复用的一小段，worker 入口 = 它 + 「以 worker 身份启动」。
- [两种跑法行为不一致] → D7 的判据 + 用例覆盖两种跑法。

## Migration Plan

批次（实施时机另定）：

1. **per-VM 加固**：自唤醒通道名拼 `thread.id`；日志 / 根目录 / 引导按 VM 收口。**单 VM 下行为不变**，可独立验证。
2. **去掉卸载 / 重装**（D8 / D9）：`resetContent` 与清空重装路径退役，依赖它们的用例与文档跟着收。
3. **worker 身份 + 单局模式**：开发与测试切到 worker 入口；内核 / 内容用例照旧。
4. **（将来另开变更）master**：lobby 与 worker 调度。

回滚：批次 1、2、3 都是「换一层」，出问题回到现在直接 `require 'session'` 的入口与 `install` 的清空重装路径即可（批次 2 的回滚就是把那段代码恢复）。

## Open Questions

- **会话归属**：会话表放在 master、会话实例留在 worker 吗？重连时 master 把「取全量状态」转发给对应 worker —— 形状等 master 那批再定。
- **worker 之间要不要互相说话**（观战、跨局技能）：暂定不需要，只与 master 说。
- **lobby 的功能范围与协议域**：master 批再定。
