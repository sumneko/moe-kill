# Design

## Context

仓库当前只有 OpenSpec 骨架，没有任何代码与构建配置（见 `proposal.md` 的 Why）。

约束（来自用户决策，不要重开）：

- 后端单进程、直接跑 Lua；前端只播表现、采集输入；所有游戏逻辑在后端。
- 运行时 `actboy168/bee.lua`；Lua 5.5；调试用 `actboy168.lua-debug`；构建用 `luamake`。
- 重连走专门方法全量同步状态；前端本变更不实现。
- 基础设施与代码风格**照搬** `LuaLS/lua-language-server` 的 `4.0.0` 分支（多出的部分后续剪裁）。
- 无前端也能跑完整对局测试。

参考实现（LuaLS 4.0.0）的既有事实，本设计沿用：

> 2026-09-19 追加：下文里 `script/` 已改名 `server/`，`script/engine/` 的规划已拆成 **`server/core`（内核，与规则无关）+ 项目根 `game/`（规则集）**；原表述保留以便对照，实际口径以 `add-core` 的设计为准。

- 发布形态是「**exe + `bin/main.lua` 引导 + `script/` 脚本树**」；引导脚本负责设置 `package.path` 与整理 `arg`。
- 主线程跑单线程事件循环，`await` 用协程实现；**阻塞 IO（stdio、文件）交给 worker 线程 + `bee.channel`**，4.0.0 全程不使用 `bee.async`。
- 测试走 `--test` 参数，`main.lua` 里 `require 'test'` 进入测试模式。
- 调试由目标进程主动连接调试器（`require 'debugger'` + `dbg:start(addr:port)`）。

关于可选链：它由 bee.lua `master` 上的 `3rd/lua-patch/optchain/` 提供，通过**构建期 `git apply` 补丁**实现，门控完全在构建层（`compile/common.lua` 的 `lua_patches` 注册表）；不打补丁时编译的是纯官方 Lua，行为零影响。启用方式为 `luamake -optchain`，或在 `make.lua` 里写 `lm.optchain = true`。

## Goals / Non-Goals

**Goals:**

- 建立「可构建、可启动、可调试、可无头测试」的最小后端骨架，跑通冒烟测试。
- 一次性定好命名空间、目录划分与命令入口，后续变更不需要返工。
- 让基础设施层与未来的游戏引擎解耦：引擎不依赖 IO 与协议。

**Non-Goals:**

- JSON-RPC 协议规范与 transport 实现（下一个变更）。
- 任何游戏规则、卡牌、武将、AI、牌堆。
- 前端（含浏览器前端）。
- 对复制来的工具集做剪裁 —— 先照搬，后续变更再裁剪。

## Decisions

### D1 运行时：bee.lua（submodule）+ Lua 5.5，构建期启用可选链

`3rd/bee.lua` 以 submodule 形式固定在本仓库，`make.lua` 里 `lm:import "3rd/bee.lua/make.lua"` 并设 `lm.lua = "55"`、`lm.optchain = true`。

- 理由：这是参考实现的做法，且 bee.lua 自带调试器所需的 error/resume/yield 钩子补丁与 Windows UTF-8 等补丁。
- 备选与取舍：系统 Lua + 自建绑定（跨平台 IO 层要自己写，成本高，否决）；不启用可选链（风格退化，作为可降级方案保留）。

### D2 发布形态：exe + `bin/main.lua` + `script/` 脚本树

构建产出可执行程序与脚本树两部分，引导脚本负责把脚本根加入模块搜索路径并整理 `arg`。

- 理由：改脚本无需重编译；运行时的错误堆栈文件名与磁盘源码一一对应，调试映射（`sourceMaps`）不需要额外处理。
- 备选与取舍：单文件打包（改一行脚本就要重编、调试映射复杂，否决）；分发裸 `lua` 解释器 + 脚本（目标机需预装 Lua，违反 `backend-build` 规格，否决）。

### D3 目录划分与全局命名空间

- 引导文件 `script/moe-kill.lua`：建立全局命名空间 `moe`，挂载工具集与 `Class` / `New` / `Delete` / `Type` / `IsValid` / `Extends`。
- `script/master.lua`：主进程初始化（线程名、日志、定时状态上报）。
- `script/tools/`：基础设施（照搬 4.0.0 的工具集）。
- `server/core/`（原 `script/engine/`）：内核——通用对象与容器（牌 / 牌区 / 属性 / 随机源），**与规则无关**；游戏规则集另放项目根 `game/`。
- `main.lua`：进程入口，按参数决定进服务模式还是测试模式。
- `test/`：测试；`make/`：构建辅助（引导脚本、模块注册）。

理由：与 4.0.0 的形态一一对应，照搬时不需要重新理解结构；`moe` 与 `ls` 一样是短根名。

### D4 主循环与挂起模型：单线程事件循环 + 协程 await

主线程只跑事件循环；需要「等玩家输入」或「等 IO」时，让出当前协程，条件满足后恢复。

- 理由：后续引擎的决策点天然是「挂起 → 恢复」，用协程表达最直接；单线程下游戏状态只有一个写者，无锁、易复现。
- 备选与取舍：显式状态机 + 续体（表达力差、易错，否决）；每对局一线程（跨线程只能传可序列化 plain data，状态会被撕碎，否决）。
- 配套：真正阻塞的操作（终端读写、文件读写）放进 worker 线程，通过 `bee.channel` 回传，避免阻塞主循环。

### D5 命令行参数与入口

支持 `--key=value`、`--key value`、裸开关 `--flag` 三种形式；键名统一大写化后暴露。

- `--test [target]`：进入测试模式，`target` 为可选的测试过滤目标。
- `--develop` / `--dbgaddress` / `--dbgport` / `--dbgwait`：调试接入。
- `--loglevel` / `--logpath`：日志。

理由：照搬参考实现的参数命名与解析行为，减少后续认知成本。

### D6 基础设施来源：照搬 LuaLS 4.0.0，通用工具取 `sumneko/utility`

从 4.0.0 复制基础设施文件（事件循环、await、定时器、日志、JSON、inspect、uri、GC、简单事件、优先队列等）与类系统；通用工具（`class`、`utility`、`fs-utility`、各种 table 结构）以 `sumneko/utility` 为上游。

- 理由：用户明确要求照搬；这些机制（尤其 await 与事件循环）正是引擎决策点的核心，重写风险高。
- 副作用与处理：复制进来后它们成为本仓库自有代码，按本项目需要独立演进；这与 `.agents/skills/` 的通用能力同步机制是两回事，不要混淆。

### D7 测试框架：照搬 4.0.0 的 `--test` 入口

`test.lua` 负责过滤器解析、按模块路径加载测试、断言框架、失败输出与退出码；本变更附带冒烟测试覆盖「启动 → 参数解析 → 日志落盘 → 事件循环可停止 → 协程可挂起与恢复」。

- 理由：这套入口就是本项目的验收通道，也是「无前端跑完整对局」的落点，越早定型越好。

### D8 调试接入

调试器按需加载：参数开启时 `require 'debugger'` 并连接指定地址；未开启时不加载；缺失时只警告不终止。VS Code 侧同时提供 `attach` 与 `launch` 两套配置，并把类系统文件加入 `skipFiles`。

- 理由：目标进程主动连接是参考实现的成熟做法，且能覆盖「调试 exe 启动的进程」与「调试已运行进程」两种场景。

## Risks / Trade-offs

- **[构建开关漏配导致解析失败]** → 可选链的开关在构建层，未启用时编译的是纯官方 Lua，源码里的 `?.` 会直接解析失败。缓解：把 `lm.optchain = true` 写死在根 `make.lua`（不依赖命令行记忆），并在冒烟测试里覆盖一段使用可选链的代码。
- **[submodule 版本漂移]** → submodule 固定到 bee.lua `master` 的具体 commit（不跟随分支移动），来源与 commit 记入 `references/infrastructure.md`；升级时显式调整并重跑全量测试。
- **[照搬会带入当前用不到的工具]** → 用户已决定先照搬；在后续变更里按实际使用剪裁，不阻塞本次。
- **[全局命名空间削弱静态分析]** → 在 `.luarc.json` 里声明 `diagnostics.globals`，全局只在引导文件一处赋值，不在业务代码里动态写全局。
- **[exe + 脚本树对路径敏感（空格 / 非 ASCII）]** → 引导脚本统一用 `package.config` 判断分隔符；冒烟测试覆盖含空格与中文的路径。
- **[Lua 5.5 生态较新]** → 调试器已声明支持 5.1–5.5；若遇到工具不兼容，回退 5.4 的主要成本在补丁与语言特性，风险可控。
- **[复制来的类系统内部实现干扰单步调试]** → 调试配置里 `skipFiles` 排除类系统文件。
- **[复制代码的后续维护漂移]** → 记录来源分支与 commit（写进 `moe-kill-dev` 技能的 `infrastructure.md`），后续升级参考实现时按需 diff。

## Migration Plan

本变更为纯新增：无既有代码需要迁移，无数据迁移。回滚方式为删除新增的构建配置、`script/`、`test/` 与 `3rd/bee.lua` submodule 引用。

## Open Questions

- 日志目录的默认位置（脚本树同级 `log/` vs 用户目录）—— 后续按部署习惯调整即可，不影响规格与任务拆分。
