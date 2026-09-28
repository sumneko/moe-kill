# Proposal

## Why

游戏功能会持续长大（武将技能、装备自带技能、延时锦囊…），而**内核类表、加载器登记、事件表、日志与自唤醒通道在一局之间共享**。于是单 VM 下「改规则只影响这一局」只能靠**纪律**维持（不许往类表上挂东西、不许留模块级状态），而且一局的极端情况（效果嵌套 ~225 层已实测会把进程直接弄没）会带走**所有**局。

要在「mod 可以自由覆盖基础规则」与「多局长跑互不干扰」之间取平衡，需要把**一局**放进自己的 VM。同时，这条边界**现在就摆进开发与测试**，比等 game 功能做完再搬要便宜得多。

此外，**一局一个 VM 让「规则集重装」整块变得多余**：清理手段从「清单式回撤」变成「销毁 VM」—— 一局结束 `lua_close` 全清，不需要 `resetContent()` 那套簿记，也没有「删方法不生效」「老实例不重跑 `__init`」这些重载遗留限制。用户 2026-09-28 定：**卸载 / 重装整块不要了**。

（本变更先只记录决策，不实施；**实施时机：等 `package/标准` 的工作全部做完之后**，用户 2026-09-28 定。）

## What Changes

- 引入 **worker**：跑**一整局**的一方 —— 内核 + 内容包 + 会话外壳 + 自己的事件循环。一局的 VM 里只有它。
- 引入 **单局模式**：只起一个 worker，不需要 master。**开发与测试一律以这个身份进行**（用例直接驱动 worker，不经过任何服务器）。
- **master 后置**：等 game 功能（武将、装备技能、延时锦囊…）做完，再加 master —— 它负责 lobby 之类的大厅功能，并调度 worker 开单局。两种模式共存：单局模式（只开 worker）/ 服务器模式（master + worker）。
- **规则集不再有「卸载 / 重装」**（用户 2026-09-28 定）：`game:resetContent()` 与 `moe.loader.install` 的清空重装路径**不要了** —— 一套规则 = 一个 VM 的生命周期，加载一次、随 VM 一起消失。
- **包清单在 VM 启动时就定死**：服务器模式由 master 传入；单局模式自己做一个**简单的用户交互**来选择；无头测试直接用参数（用户 2026-09-28 定）。
- **worker ↔ master 的边界复用现有 JSON-RPC**：协议本来就只有三种形状（请求 / 反向请求 / 通知），正好是这条边界需要的三种；跨边界只能传 plain data 这条硬约束与协议层天然吻合。master **只做转发与调度**，不认识牌 / 阶段 / 胜负。
- **多 VM 前提加固**（进程级单例改 per-VM 安全）：
  - 自唤醒通道名不再固定，**直接拼 `thread.id`**（现有 `'moe-kill:event-loop'` 是进程级唯一名字，同进程第二个 VM 一启动就报 duplicate —— 探针实证）。
  - 日志文件、根目录推导、引导入口从「进程一份」改成「每个 VM 一份」。
- **线程生命周期口径**（`bee.thread` 无强杀）：
  - 退出只能靠**入口自己返回**（协议里一条「结束」消息），主线程无法强制；
  - 线程结束时整个 VM 由 `lua_close` 释放，不需要手动清理；
  - 错误要**按局上报**（`bee.thread.errlog()` 是进程级共享队列、不带线程 id）；
  - 关停顺序：请线程退出 → `asyncfd:cancel` 取消 watch → `channel.destroy`。
- 明确一条**打折的边界**（写进 design，避免以后误以为已隔离）：同进程线程挡不住 C 栈打爆 / OOM / 原生崩溃，这些仍会带走整个进程。thread 方案挡的是「规则 / 内容写错」，不是「恶意或极端」。

## Capabilities

### New Capabilities

无。本变更属探索期的**架构决策记录**，不写规格增量（`.openspec.yaml` 设 `skip_specs: true`）。理由见 `AGENTS.md`「工作流」：探索期只留决策记录，可执行契约由用例承担。

将来如果 worker / master 的边界成为**冻结的对外契约**（第三方 mod 与前端都要依赖它的形状），再单独开一个变更写规格。

### Modified Capabilities

无。现有 `headless-server` / `async-io` / `backend-runtime` / `hot-reload` / `headless-test` 等规格描述的行为**不变**（会话外壳仍是容器、仍不接管事件循环），本变更只在它外面加一层「谁持有这一局」；`openspec/specs/` 已冻结，不回头改。

## Impact

- 引导与模式选择：`server/main.lua`、`server/moe-kill.lua`、`server/master.lua`（将来拆出 master 侧与 worker 侧两个入口）。
- **删掉卸载 / 重装**：`server/core/game.lua` 的 `resetContent`、`server/core/loader/init.lua` 里对它的调用与「清空重装」那段、以及依赖重装的用例（`server/test/core/game.lua`、`server/test/core/phase.lua`、`server/test/rule/flow.lua`、`server/test/rule/init.lua`）。
- 基础设施的进程级单例：自唤醒通道名（现住 `server/loop-waiter.lua`）、`log` 的落地文件、`moe.env` 的根目录推导。
- 会话外壳：`server/session/` 要从「唯一的服务层」改成「**worker 侧**一局一份」（挂起的是局内的 Task）。
- 测试：`server/test.lua` 与 `server/test/**` 的组织 —— 内核 / 内容包用例照旧在单进程同步跑，只有「会话 / 协议」那层需要跨 VM 验证。
- 线程与通道接线：`bee.thread` / `bee.channel`（`thread.create` 的入口是**代码字符串**，子 VM 的引导方式要单独定）。
- 文档：`references/architecture.md` §9.8（「重装语义」要改写成「一套规则 = 一个 VM」）、§9.1 / §9.3 / §9.6、§8.4 与第 10 节里提「重装」的段落；`references/infrastructure.md` 新增线程与通道一节；`AGENTS.md` 的目录职责表反映新分层。
