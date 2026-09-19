---
name: moe-kill-dev
description: moe-kill 后端工程约定：前后端架构、协议分层、无头测试要求、代码风格、构建与调试方式。改动任何后端 Lua 代码、协议定义、构建脚本或测试前先读本文件与其 references。Use when working on the moe-kill Lua backend, JSON-RPC protocol, build (luamake/bee.lua), tests, or code style.
---

# moe-kill 开发约定

先读本文件，再按需读 `references/`。架构与风格决策的细节在 references 里，本文件只给索引与硬约束。

## 0. 强制流程

1. **先规划、后实现**：重大需求 / 架构调整先在本仓库建 OpenSpec 变更提案（`/openspec-propose`），经确认后再写代码。
   - **但规划粒度按“一个功能点”来**（用户 2026-09-19 定）：**自底向上、按功能点推进** —— 一次只做一个具体功能点（如「杀」），把它相关的功能做完（需要的内核能力按**最小可用形状**就地补），再进下一个功能点，最后才在上层（规则流程 / 会话 / 协议）串起来。**不要**预先设计整套对象模型/完整框架；细节（出牌限制、距离判定、标记语义…）留到实现到那个功能时再定，提前拍的口径多半会返工；早期“随口确认”的接口细节**不构成约束**。
2. 本工程的规则口径、风格约定若与具体实现冲突，**先问用户**，不要自行选定方案。
3. 改代码前读：本文件 → `references/architecture.md` → `references/code-style.md` → 具体子系统的说明。
4. **改完 Lua 必须检查问题面板，把 information 及以上等级的问题清到 0**（hint 级不管）；确实改不动的**来问用户**，不要留着不管。
   - 一次性改动大量文件后，语言服务器可能延迟甚至卡住（面板不刷新）：执行命令 `lua.startServer` 重启它，再重新检查。

## 1. 项目定位（用户已确认，不要再改动）

- 前后端分离，**后端单进程直接跑 Lua**（`actboy168/bee.lua` 运行时）。
- **所有游戏逻辑在后端**；前端只播放表现、采集玩家输入，不做任何规则判断。
- 前后端通过 **JSON-RPC** 通讯，协议是**通用规范**：一个后端可对接多种前端（浏览器是默认前端实现）。
- 先做单机单人（AI 补齐人数），联网多人后续再说。
- 重连由**专门的协议方法全量同步状态**（不靠增量事件重放）。
- 前端暂不实现；**先做无头后端并跑测试**。
- 调试用 VS Code 的 `actboy168.lua-debug` 扩展。
- Lua 版本 **5.5**；测试用 LuaLS 4.0.0 的 `--test` 入口与断言风格（`server/test/ltest.lua` 是本工程的可读精简实现）。

## 2. 目录职责（规划）

| 路径 | 职责 |
| --- | --- |
| `<exe>` + `server/bin/main.lua` | 引导入口（exe 与引导产物同在 `server/bin/`） |
| `server/main.lua` / `server/test.lua` | 进程入口与测试入口 |
| `server/moe-kill.lua` | 建立全局命名空间 `moe`、挂载工具集与语法糖（全局只在此处赋值一次） |
| `server/tools/` | 基础设施（event-loop / await / timer / log / json / inspect / uri…）与通用库（class、utility、attribute），照搬；**不要随便改** |
| `server/session/` | 无头服务器外壳：会话容器、决策挂起/恢复通道、事件收集（不含任何规则）；门面是 `moe.server` |
| `server/async-io.lua` | 等待与异步 I/O 接线：`bee.async` 实例、完成事件分发、异步文件读写、外部事件源注册（详见 `references/infrastructure.md` 第 6 节） |
| `server/core/` | 内核：玩家、桌子、房间、牌区、属性、随机源（**与规则无关**，接口可直接调用、可单测） |
| `server/rule/` | 规则集加载器与规则表（`moe.rule`）；**游戏业务**功能，与开发期热重载无关（详见 `references/architecture.md` 第 9 节） |
| `server/test/` | 无头测试（套件名如 `test.smoke` / `test.session` / `test.core`） |
| `server/bin/` `server/log/` `server/tmp/` | 构建产物与运行时产物（均 git 忽略） |
| `game/`（项目根，与 `server/` 平级） | 规则集：基础规则 / 卡牌包 / 技能（**目录尚未创建**；由 `moe.rule` **读文件执行**加载，不走 `require` / `include`、不参与热重载；依赖 `server/core`，不反向） |
| `server/proto/` | 协议定义（方法名、参数与返回结构），前后端共用的事实来源 |
| `server/transport/` | JSON-RPC 帧与连接层 |
| `client/`（将来） | 前端（TypeScript / Web）；与 `server/` 平级 |

## 3. references

| 文件 | 内容 |
| --- | --- |
| `references/architecture.md` | 分层、数据流、边界、协议设计原则、无头可测要求、热重载（8）、规则集加载（9） |
| `references/code-style.md` | 代码风格（照搬 LuaLS 4.0.0） |
| `references/infrastructure.md` | 参考仓库位置、bee.lua 构建与引导、lua-debug 调试、测试与命令速查 |

## 4. 硬约束速查

- 引擎层不得 `require` 任何网络 / 终端 / jsonrpc 模块；反向依赖只允许**外层调内层**。
- 决策点统一为「请求输入 → 挂起 → 恢复」，无头测试与前端共用同一条路径。
- 随机数可注入 seed，保证整局可复现。
- 跨 worker / 线程边界只传可序列化的 plain data（table / string / number / boolean）。
- 临时调试产物统一放 `server/tmp/`，用完清理，不要留在代码目录里。
- 风格与基础设施以 LuaLS `4.0.0` 分支为准（见 `references/`），不要照搬其 `master`（2022 老架构）。
