# Tasks

## 1. 前置与仓库基础配置

- [x] 1.1 确认构建前置可用：`luamake` 在 PATH（本机为 `D:\Github\luamake\luamake.exe`，自带 ninja）、MSVC 可被 luamake 定位；把结论记入 `moe-kill-dev` 技能的 `references/infrastructure.md`
- [x] 1.2 添加 `.editorconfig`（UTF-8 无 BOM、LF、4 空格、Lua 缩进）
- [x] 1.3 添加 `.gitignore`（忽略 `bin/`、`build/`、`obj/`、`tmp/`、`log/` 等构建与运行时产物，但保留需要入库的脚本）
- [x] 1.4 添加 `.luarc.json`：Lua 5.5、模块搜索路径、非标准符号（可选链）、`workspace.library` 指向 `3rd/bee.lua/meta`、`diagnostics.globals` 声明项目根命名空间
- [x] 1.5 以 submodule 引入 `3rd/bee.lua`，**固定到 `master` 上的具体 commit**（先 `git fetch origin --prune` 拿最新引用，不跟随分支移动），并在 `references/infrastructure.md` 记录来源与 commit

## 2. 构建骨架（exe + 引导脚本）

- [x] 2.1 编写根 `make.lua`：`lm.lua = "55"`、`lm.optchain = true`、`lm:import "3rd/bee.lua/make.lua"`、`lm:executable` 依赖 `source_bee` / `source_lua` / `source_bootstrap`
- [x] 2.2 编写 `make/bootstrap.lua`（引导脚本）：设置 `package.path`（脚本根、`script/?.lua`、`script/?/init.lua`、`script/tools/?.lua`、`script/tools/?/init.lua`）、用 `package.config` 处理路径分隔符、整理 `arg`（去掉脚本名本身）
- [x] 2.3 添加 `make/modules.cpp` 最小占位（本项目暂无自有 C 模块，保持可编译）
- [x] 2.4 添加「复制引导脚本到 `bin/main.lua`」的构建步骤，产物目录为 `bin/`
- [x] 2.5 执行 `luamake -notest` 构建，确认 `bin/` 下同时存在可执行程序与 `main.lua`
- [x] 2.6 在未设置任何 Lua 环境变量的终端里直接运行 `bin/<exe>`，确认能进入启动流程（此时业务模块可仅打印占位日志）
- [x] 2.7 验证可选链补丁已生效：运行一段使用 `?.` / `?:` / `?(` / `?[` 的脚本能正确短路（开关未生效时会直接解析失败）

## 3. 运行时基础

- [x] 3.1 从 `origin/4.0.0` 复制基础设施文件到 `script/tools/`（至少：事件循环、await、timer、log、json、inspect、uri、gc、simple-event、priority-queue），路径写法注意本地工作区是老的 `master`，必须用 `git show origin/4.0.0:<path>`
- [x] 3.2 引入类系统（`Class` / `New` / `Delete` / `Type` / `IsValid` / `Extends`）与通用工具（`utility`、`fs-utility` 等），来源以 `sumneko/utility` 为主
- [x] 3.3 编写 `script/moe-kill.lua`：建立全局命名空间 `moe`、开启语法糖（`'{}' % {}`、字符串作路径拼接、`<close>`）、挂载工具集、把类系统挂到全局；每个全局只在此处赋值一次
- [x] 3.4 编写 `script/master.lua`：设置线程名、初始化日志（写日志文件 + 错误同时进 stderr）、注册事件循环的定时状态上报任务
- [x] 3.5 编写 `main.lua`：设置 GC 参数 → 加载 `moe-kill` 与 `master` → 解析命令行参数 → 分支到测试模式或服务模式（服务模式本变更只需空转事件循环 + 退出）
- [x] 3.6 实现参数解析：支持 `--key=value`、`--key value`、`--flag`，键名大写化暴露；未识别参数保留不报错
- [x] 3.7 接通调试参数（`--develop` / `--dbgaddress` / `--dbgport` / `--dbgwait`）：开启时在指定地址建立**调试接入点（监听，供调试器接入）**，未开启不加载，调试器缺失只警告不终止
- [x] 3.8 建立 `script/engine/` 目录与占位约定文件（只写目录职责说明，不写规则逻辑）

## 4. 无头测试通道

- [x] 4.1 编写 `test.lua`：解析 `--test` 的过滤目标（支持 `a.b.c` 子路径逐层收窄）、按匹配加载测试模块、跑完输出摘要并以正确退出码结束
- [x] 4.2 为 `test.lua` 加入失败时输出用例名 / 错误 / 堆栈的能力
- [x] 4.3 实现「过滤器无匹配即报错退出」的行为
- [x] 4.4 编写冒烟测试：命令行参数三种形式解析正确
- [x] 4.5 编写冒烟测试：日志落盘且包含启动日志行
- [x] 4.6 编写冒烟测试：事件循环可注册任务、可被停止且停止后返回控制权
- [x] 4.7 编写冒烟测试：协程可挂起并在恢复时收到返回值；未捕获错误进入统一错误处理器
- [x] 4.8 编写冒烟测试：类系统可声明、实例化、查询类型与有效性、销毁
- [x] 4.10 编写冒烟测试：可选链四种形式可正确短路（对应 2.7 的常态化验证，替代一次性脚本）

## 5. 调试接入

- [x] 5.1 添加 `.vscode/launch.json`：`launch` 配置（`luaexe` 指向 `bin/<exe>`、`program` 为 `main.lua`、`luaVersion: lua55`）与 `attach` 配置（地址与调试参数一致、`sourceMaps`）
- [x] 5.2 两套配置都加入 `skipFiles`（排除类系统文件）；调试接入点监听已实测（`--develop --dbgport=11418` 端口处于监听；`--test` 无任何监听）
- [x] 5.3 添加 `.vscode/tasks.json`（构建任务）与 `.vscode/settings.json`（默认启动参数）

## 6. 验收与文档收尾

- [x] 6.1 全量验收：`luamake -notest` 编译通过，`bin/<exe> --test` 全部通过且退出码为 0
- [x] 6.2 验收硬约束：确认测试模式不建立任何对外监听、不依赖前端即可跑完（可在断网 / 无客户端环境复验）
- [x] 6.3 验收路径鲁棒性：把产物放到含空格与中文的路径下再跑一次 `--test`
- [x] 6.4 更新 `moe-kill-dev` 技能的 `references/infrastructure.md`：记录实际构建命令、产物路径、bee.lua 固定 commit、调试参数与实测结论
- [x] 6.5 清理 `tmp/` 下的临时产物，确认没有调试残留
