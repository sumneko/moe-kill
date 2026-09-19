# 基础设施（参考仓库 / 构建 / 调试 / 测试）

## 1. 参考仓库（本机克隆，优先本地查阅）

| 仓库 | 本地路径 | 用途 | 注意 |
| --- | --- | --- | --- |
| bee.lua | `D:\Github\bee.lua` | Lua 运行时与系统库 | 可选链**已在 `master` 上**（构建期补丁，`luamake -optchain` 启用） |
| utility | `D:\Github\utility` | 通用 Lua 工具库（风格语法糖、class 系统…） | 是 LuaLS 内副本的上游 |
| lua-language-server | `D:\Github\lua-language-server` | **基础设施与风格的主要参考** | 本地工作区是 2022 年的 `master`；`4.0.0` 已 fetch 为 `origin/4.0.0`，**读它用 `git show origin/4.0.0:<path>`**，不要读工作区文件 |
| lua-debug | `D:\Github\lua-debug` | 调试器（VS Code 扩展 `actboy168.lua-debug`） | 文档见 `docs/DebuggerInit.md`、`docs/luadebug/` |

**查阅任何参考仓库前先 `git fetch origin --prune`**：本地工作副本可能停在旧分支，本地 `origin/*` 引用也可能滞后几周，直接 grep 本地引用会得出错误结论。

## 2. bee.lua 提供的模块

`socket`、`subprocess`、`thread`、`channel`、`async`、`filesystem`、`filewatch`、`epoll`、`select`、`serialization`、`time`、`crash`、`debugging`、`platform`、`sys`、`windows`
（类型注解在 `bee.lua/meta/*.lua`，直接看注解即可掌握 API。）

要点：

- `bee.thread.create(source, ...)` 起线程（**不共享全局变量**），`bee.channel` 做线程间通信，数据会被序列化 → **只能传 plain data**。
- `bee.time.monotonic()` 返回毫秒整数，单调递增，用于计时。
- `bee.socket` 提供 tcp/udp/unix 与 `fd:handle()`；`bee.epoll` / `bee.select` 用于等待；`bee.async` 是**跨平台异步 I/O 层**（Windows/IOCP、macOS/GCD、Linux/io_uring・epoll），提供 `wait(timeout)` 阻塞等待、`submit_read/write/accept/connect`、`submit_file_read/write`、`submit_poll`（监听 fd 可读）。
- LuaLS 4.0.0 的实践是**不用 `bee.async`**，把阻塞 IO（stdio、文件）丢给 worker 线程 + channel，主线程只跑 event-loop；**本工程反过来**：没有线程，等待与唤醒全部交给 `bee.async`（见第 6 节）。
- **可选链**（`?.` `?:` `?[` `?(`）在 `master` 上，由 `3rd/lua-patch/optchain/` 在**构建期** `git apply` 补丁实现，**门控完全在构建层**（`compile/common.lua` 的 `lua_patches` 注册表；不打补丁时是纯官方 Lua，行为零影响）。
  - 启用方式：`luamake -optchain`，或在 `make.lua` 里写 `lm.optchain = true`（luamake 把命令行 flag 暴露为 `lm.<flag>`）。
  - 因此**该开关必须是项目默认构建的一部分**：源码里写了 `?.` 而构建未启用时会直接解析失败。

## 3. 构建（luamake）

形态：**一个 exe + 一棵 Lua 脚本树**。exe 与引导脚本同在 `server/bin/`，exe 负责加载同目录的 `bin/main.lua` 引导脚本，引导脚本设 `package.path`（`server/?.lua`、`server/?/init.lua`、`server/tools/?.lua`、`server/tools/?/init.lua`）并处理 `arg`。

`make.lua` 骨架（照搬 LuaLS 4.0.0）：

```lua
local lm = require 'luamake'

lm.cxx = 'c++17'
lm.lua = "55"
lm.optchain = true -- 启用可选链补丁（等价于命令行 luamake -optchain）

lm:import "3rd/bee.lua/make.lua"

lm:executable "<名字>" {
    deps = { "source_bee", "source_lua", "source_bootstrap" },
    includes = { "3rd/bee.lua", "3rd/bee.lua/3rd/lua55" },
    sources = "make/modules.cpp",
}

lm:copy "copy_bootstrap" {
    inputs = "make/bootstrap.lua",
    outputs = "bin/main.lua",
}
```

- `bee.lua` 以 submodule 放在 `3rd/bee.lua`；`make/modules.cpp` 只做自有 C 模块注册（无自有 C 模块时留空壳）。
- 常用命令：`luamake`（编译 + 测试）、`luamake -notest`（只编译）、`luamake -mode debug`、`luamake test -v`。
- `includes` 里 Lua 目录的写法是 `"3rd/bee.lua/3rd/lua" .. lm.lua`，**不要写成 `"lua5" .. lm.lua`**（会拼成 `lua555`，然后 `lua.hpp` 找不到）。

### 本仓库实测产物与行为（2026-09-19 已验证）

目录布局：

```
<根>/
  make.lua              构建定义
  make/bootstrap.lua    → 构建时复制为 server/bin/main.lua
  make/modules.cpp      C 模块注册占位
  server/               后端根（代码 + 入口 + 测试 + 产物）
    main.lua  test.lua   进程入口与测试入口
    moe-kill.lua  master.lua  args.lua  debugger.lua  async-io.lua
    core/  session/  tools/
    test/                无头测试（test.smoke / test.session / test.core…）
    bin/                 产物（git 忽略）：moe-kill.exe、main.lua、VC 运行库 dll
    log/  tmp/           运行时产物（git 忽略）
  game/                规则集（后续批次创建；与 server/ 平级）
  client/              前端（将来；与 server/ 平级）
  build/                中间产物（luamake 的 $bin/obj 等，git 忽略）
```

exe 的引导链路（**关键，容易踩坑**）：

1. exe 内嵌引导把 `package.cpath` 设为 `<exe目录>/?.dll`，然后 `loadfile(<exe目录>/main.lua)` 并调用它。
2. 此时 `arg[0]` 是**占位字符串 `"!main.lua"`**（由 C 侧 `createargtable` 写入），不是可用路径；用户参数从 `arg[1]` 开始。
3. 所以 `make/bootstrap.lua` 不能靠 `arg[0]` 推根目录：exe 在 `<根>/server/bin/`，于是 **`progdir = <根>/server/bin`，`root = progdir/../..`**（并用「该层是否有 `core/`」做兜底、支持 `MOE_KILL_ROOT` 环境变量覆盖）。
4. 引导脚本随后加载 **`<根>/server/main.lua`**；若发现 `arg[1]` 是以 `.lua` 结尾的非选项参数，就把它当入口脚本并左移参数表，最后把 `arg[0]` 设为真实入口路径 —— 这样「业务代码看不到 `main.lua` 自身」且 `lua-debug` 的 launch（`luaexe` + `program`）也能直接用。
5. 于是 `server/master.lua` 里 `ROOT_PATH = arg[0] 的父目录` = **`<根>/server`**：日志、临时产物、测试入口（`server/test.lua`）都在 `server/` 下自洽；`--root` 可覆盖。

已验证行为：

- `server/bin/moe-kill.exe`（不带参数）→ 自动加载 `server/main.lua`，正常退出码 0。
- `server/bin/moe-kill.exe server/tmp/x.lua --flag=1` → 加载该脚本，参数表里不残留脚本名。
- 可选链四种形式、链式组合、短路无副作用、`?:` 保留多返回值，均实测通过。

### 本机环境实测（Windows，2026-09-19）

- `luamake` 在 PATH：`D:\Github\luamake\luamake.exe`；它**自带 ninja**（`D:\Github\luamake\compile\ninja\ninja.exe`）。
- `ninja` 与 `cl` **不在 PATH 是正常的** —— ninja 由 luamake 自带，MSVC 由 luamake 自行定位（`vswhere`），不需要开 VS 开发者命令提示符。
- 因此构建只需在项目根执行 `luamake -notest`，无需额外准备环境。
- `3rd/bee.lua` 固定提交：`88181ee`（`master`，2026-09-09）。子模块对象库已解耦为自包含（添加时用过 `--reference`，随后 `repack -a -d` 并删除 `alternates`）。

## 4. 调试（lua-debug）

目标进程内按需加载调试器（`server/debugger.lua` 去 VS Code 扩展目录里找最新的 `actboy168.lua-debug-*/script/debugger.lua`，注意扩展自己的 `script/` 与我们无关）：

```lua
if moe.args.DEVELOP then
    local dbg = require 'debugger'
    dbg:start(moe.args.DBGADDRESS .. ':' .. moe.args.DBGPORT)
    if moe.args.DBGWAIT then
        dbg:event 'wait'
    end
end
```

- **`dbg:start(地址)` 默认是"监听"**：扩展脚本里 `cfg.client` 为空时会用 `listen:地址`，即目标进程开端口等调试器接入；只有传 `{ address = ..., client = true }` 才是反向连接（`connect:`）。
- 因此 VS Code 侧与 `request: attach` 配对（`address: 127.0.0.1:<port>` + `sourceMaps`，把运行时的 `server/*` 映射回工作区）。
- `request: launch`（`luaexe` + `program`）依赖扩展注入；我们的引导脚本保留了 `-e <expr>` 处理（照搬 4.0.0）以兼容这条路径。
- 两套配置都建议 `skipFiles: ["server/tools/class.lua"]`（类系统内部实现会污染单步）。
- 调试接入放在 `main.lua` 的**测试分支之前**，所以 `--test --develop` 也能 attach 调试测试。
- 用完及时断开，开新会话前先停掉旧会话。

**实测（2026-09-19）**：`bin/moe-kill.exe --develop --dbgport=11418` 后 127.0.0.1:11418 处于监听；伪造 `USERPROFILE` 使扩展缺失时只记一条警告并继续运行，退出码不受影响。

## 5. 测试

入口与风格照搬 LuaLS 4.0.0，**断言库不照搬**：

- 入口：`bin/moe-kill.exe --test [套件]`；`main.lua` 里 `if moe.args.TEST then dofile '<root>/test.lua' return end`。
- `test.lua` 负责：把过滤目标转成模块路径（`smoke.await` → `test.smoke.await`，支持逐层收窄）、逐模块加载、驱动事件循环、汇总失败并以退出码表示结果（`0` = 全通过）。
- 过滤器没匹配到任何模块/用例时明确报错并以非 0 退出，不静默"全部通过"。
- 断言用 `test/ltest.lua`：`lt.test(name, fn)` 注册用例，`lt.assertEquals` / `lt.assertNotEquals` / `lt.assertError`；`lt.runAll()` 逐个 `xpcall` 并打印失败堆栈。
  - **不要 vendor 4.0.0 的 `test/ltest.lua`** —— 那是 36KB 压缩单文件（含 luac 反汇编与覆盖率机制），本工程用不到；4.0.0 的测试实际只用到 `assertEquals` / `assertNotEquals`。
- **事件循环归入口所有**：`test.lua` 启动并停止它；套件内的用例只注册任务/定时器或 `await`，不要自己调 `eventLoop.start`（会与入口冲突）。
- 内存护栏只在显式传 `--mem-limit` 时启用。
- 临时产物统一写 `tmp/`（已 gitignore）。

**实测（2026-09-19）**：43 个用例约 0.65 秒（事件循环迭代 20 次，与用例里的真实等待时间相当）；`--test` 不建立任何对外监听、无外部客户端即可跑完；产物放到含空格与中文的路径下同样通过。

## 6. 本工程对 `tools/` 的改动清单

`server/tools/` 的基准是 LuaLS `4.0.0`。以下改动是本工程有意为之（用户确认），从上游同步时**逐条比对，不要被覆盖**：

| 文件 | 改动 | 原因 |
| ---- | ---- | ---- |
| `event-loop.lua` | 删掉 `busyTime` / `markBusy` / `getIdleTime` 与「忙就不睡」的分级 sleep；`start(options, errorHandler)` 改为注入 `waiter(seconds)` / `deadline()` / `waker()`；空闲时等待到「下一个定时任务到期」（没有定时任务则无限阻塞）；停止前先请求唤醒 | 上游的忙等是为「worker 线程 + channel 回传」设计的；本工程没有线程，忙等只剩空转：全量测试 0.07 秒 → 1.4 秒、事件循环迭代 61 万次 |
| `timer.lua` | 新增 `M.getNextDeadline()`：距最近一个定时任务到期还有多少秒（没有则返回 `nil`） | 供事件循环计算等待时长，替代空转 |
| `fs-utility.lua` | 未改（仍是同步 `io.open`） | 异步文件读写另开 `server/async-io.lua`，不污染照搬文件 |
| `attribute.lua` | **新增照搬文件**：来源 `sumneko/utility` 上游 HEAD（**LuaLS 4.0.0 里没有它**）；861 行，`System:define(name, simple, min, max)` → `Instance:get/set/add/getMin/getMax/event`，含公式（基础值 + 百分比）、上下限、惰性重算与变更事件 | 内核的“通用属性”直接接它，不自己写一套 |
| `reload.lua` | **新增照搬文件**：来源 `y3-editor/y3-lualib` 的 `tools/reload.lua`（MIT，`Copyright (c) 2023 y3-editor`）—— `sumneko/utility` 与 LuaLS 4.0.0 都**没有**热重载库。改写点：`y3.util.*` → `moe.util.*`；回调注册**返回 disposer**（并因此修掉「回调数组每次重载整体替换、捕获的引用会失效」）；`getIncludeName` 补 `nil` 保护（模块名查不到时不再用 `nil` 键索引）；`include` 失败时把错误信息交回调用方；新增 `reportError`（拿不到 `log` 时退回 stderr） | 内核（以及将来的规则集）需要开发期热重载，见 `architecture.md` 第 8 节 |

等待与唤醒的接线在 `server/async-io.lua`（本工程自有，**不属于 `tools/`**）：持有 `bee.async` 实例，提供阻塞等待、完成事件分发、异步文件读写、外部事件源注册与自唤醒通道。

**初始化顺序（2026-09-19 按用户要求调整，勿改回去）**：`moe.env`（由 `arg[0]` 推出的根目录 / 日志路径）与 `log` 实例**都在 `server/moe-kill.lua` 里创建**，位置在 `moe.util` 的 `enable*` 之后、挂载其它工具与**加载内核之前**；`server/master.lua` 只留线程名、启动日志与内存定时上报。这样任何 `include`（内核模块）执行时日志一定就绪，`tools/reload.lua` 直接用 `xpcall(f, log.error, ...)` 即可。注意两点：日志块里的 `print` 回调用了 `%` 语法糖，所以它必须在 `enableFormatString()` **之后**；`moe.env` 仍由 `arg[0]` 推出，别把它再搬回 `master.lua`。

### `bee.async` 踩坑（本机实测）

- **`submit_poll` 在 Windows 下是零字节 `WSARecv`**：只能用于 socket 类句柄，且**必须先 `asfd:associate(fd)`**；未关联时完成事件永远不来（表现为等待超时，而不是报错）。`bee.channel` 的 fd 在 Windows 上就是 socket，用前同样要 `associate`（上游 `3rd/bee.lua/test/test_async.lua` 的 `test_submit_poll_channel` 就是这么写的）。
- `asfd:wait(timeout)` 的超时单位是**毫秒**，`-1` 表示无限等待；若有已就绪的同步完成事件则立即返回。
- `asfd:associate_file(io.open(...))` 会**就地**把底层句柄换成 overlapped / IOCP 关联句柄；异步路径用完后要 `close`，且不要与同步读写混用同一句柄。
- 完成事件的 `udata` 原样返回，可以直接放登记表项（本工程就是用它把结果交回挂起的协程）。
- `bee.async.create()` 返回 `(fd, err)`；创建失败必须报错，不要静默降级 —— 否则会变成「看起来能用但永远不会被唤醒」。

## 7. 命令速查

```powershell
luamake                          # 编译 + 跑无头测试
luamake -notest                  # 只编译（产出 server/bin/moe-kill.exe + server/bin/main.lua）
server/bin/moe-kill.exe --test          # 无头跑全部测试（退出码 0 = 全通过）
server/bin/moe-kill.exe --test smoke.await    # 只跑一个套件
server/bin/moe-kill.exe --test core.reload    # 热重载套件（机制 + 真改文件端到端）
server/bin/moe-kill.exe --develop --dbgport=11418   # 开启调试监听，供 VS Code attach
server/bin/moe-kill.exe                 # 服务模式（常驻事件循环）

openspec list                     # 进行中的变更
openspec status --change <name>   # 工件完成度
openspec validate --all           # 校验
git show origin/4.0.0:<path>      # 读 LuaLS 4.0.0 的任意文件
```
