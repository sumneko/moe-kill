# Proposal

## Why

`moe-kill` 目前只有 OpenSpec 规格骨架，没有任何可运行的代码：既没有构建产物，也没有运行时基础设施和测试入口。在写任何游戏规则之前，必须先有一块"能启动、能调试、能无头跑测试"的地基，否则规则实现无法被验证，前端也无法对接。

本变更只搭地基，不碰游戏规则。

## What Changes

- 建立 **exe + Lua 脚本树** 的构建骨架：以 `bee.lua` 为运行时（submodule 放 `3rd/bee.lua`），`luamake` 产出可执行程序，配套 `make/bootstrap.lua` 作为 `bin/main.lua` 引导脚本，自动设置 `package.path` 并转发 `arg`。
- 建立 **启动链路**：`main.lua` 负责加载引导模块与运行时，解析命令行参数（含 `--test`、调试相关参数），按模式决定进入服务模式还是测试模式。
- 建立 **全局命名空间与基础设施**：照搬 LuaLS `4.0.0` 的形态，挂载项目根命名空间、`Class`/`New` 等类工具（来自 `sumneko/utility`）与工具集（`event-loop`、`await`、`timer`、`log`、`json`、`inspect`、`uri`、`gc` 等）。
- 建立 **事件循环 + 协程 await 模型**：为后续「请求玩家输入 → 挂起 → 恢复」的引擎决策点预留统一通道（本变更只提供机制，不实现任何游戏决策）。
- 建立 **无头测试通道**：`--test [suite]` 入口、按模块路径过滤的测试加载器、断言框架（复用 LuaLS 4.0.0 的框架，其中含一部分 ltest），以及若干冒烟测试证明整条链路可用。
- 建立 **调试接入**：支持以启动参数主动连接 `actboy168.lua-debug`，并提供 VS Code 的 attach / launch 配置与任务配置。
- 建立 **编辑器与仓库基础配置**：`.luarc.json`（Lua 5.5、可选链符号、指向 `bee.lua` 类型库）、`.gitignore`、`.editorconfig` 等。

## Capabilities

### New Capabilities
- `backend-build`: 后端可执行程序与脚本树的构建、引导与启动行为（含调试启动参数与命令入口）。
- `backend-runtime`: 运行时基础设施的可观察行为（命令行参数、日志、事件循环与协程 await、工具集与类系统可用性）。
- `headless-test`: 无界面环境下运行完整测试的入口与过滤行为，作为后续所有验收手段的基础。

### Modified Capabilities
（无。`openspec/specs/` 当前为空，本变更首次引入规格。）

## Impact

- **新增**：`make.lua`、`make/`（引导脚本、模块注册）、`3rd/bee.lua`（submodule）、`bin/`（构建产物 + `main.lua`）、`script/`（引导、工具集、基础设施）、`test/`（测试入口与冒烟测试）、`.vscode/`（launch / tasks）、`.luarc.json`、`.editorconfig`、`.gitignore`。
- **依赖**：`luamake`（构建）、`actboy168/bee.lua`（运行时，需以其可选链特性编译）、`sumneko/utility`（工具库）、VS Code 扩展 `actboy168.lua-debug`（调试）。
- **不影响**：前端（尚未存在）、游戏规则（本变更不引入任何规则逻辑）。
- **Non-goals（留给后续变更）**：JSON-RPC 协议规范与 transport 实现、游戏引擎（结算栈 / 时机系统 / 卡牌 / 武将 / AI）、规则口径确定、多人与重连。
