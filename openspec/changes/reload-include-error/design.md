# Design

## Context

- `M.include` 内部用 `xpcall(originRequire, <handler>, modname)` 加载；`log.error` 作为 handler 时会**记日志（带堆栈）并返回「消息 + 堆栈」字符串**。
- 原先失败路径是 `return false, tostring(result)`；`server/core/init.lua` 为了把 `false` 变成硬失败又包了 `includeCore`（并且因为 `log.error` 已经记过一次，日志里同一个错误出现两次）。
- `M:fire()` 里逐个 `M.include(name)` 重新加载模块。

## Decisions

### D1 失败就抛，但抛的是**原始错误**

```lua
---@param err any
---@return any
local function onLoadError(err)
    log.error(err)
    return err
end
...
local suc, result, loaderdata = xpcall(originRequire, onLoadError, modname)
if not suc then
    error(result, 0)
end
```

**为什么不直接用 `log.error` 当 handler 再重抛它的返回值**：`log.error` 返回的是**已经嵌了堆栈**的字符串，`error(它, 0)` 之后外层（`master.lua` 的 `xpcall(..., log.error)`）还会再补一次堆栈 ⇒ 日志里出现两份堆栈，读起来很乱。自定义 handler「先记日志、再原样返回原始错误」把两件事拆开：**日志一份堆栈**、**异常里只有原始消息**（带 Lua 自己加的位置），重抛时用 `level 0` 避免再加一层位置。

### D2 `fire()` 里 `pcall` 隔离单个模块

重载是开发期动作、目的是"改完代码立刻生效"。某个模块这次装不回去（写错了），不该让**其余模块也停在旧代码上** —— 那会让人误以为改动没生效。失败本身已经有日志，所以这里静默 `pcall` 是安全的：

```lua
for _, name in ipairs(needReload) do
    pcall(M.include, name)
end
```

**备选**：让失败直接冒出去（重载中途断掉、后面模块不更新）；或在 `fire()` 里再记一条"模块 X 重载失败"（与 `include` 里那条重复，不做）。

### D3 顺手删掉 `includeCore`

它存在的唯一理由就是"`include` 不抛、直接赋值会把 `false` 静默赋进门面"。现在 `include` 自己会抛，中间层没用了；删掉之后 `server/core/init.lua` 就是 13 行 `moe.X = include 'core.X'`，日志也不再重复。

### D4 用例要把失败探针从重载名单里摘掉

`include` 是**先登记再加载**的（失败也留着登记），所以测试里加载一个"故意报错"的探针模块之后，之后每一轮 `reload()` 都会重试它并记一条错误日志 —— 套件输出会被污染。用例里用 `<close>` 把探针从 `moe.reload.includedNames` / `includedNameMap` 里摘掉即可（登记在测试进程内、不影响产品行为）。

## Risks / Trade-offs

- [偏离上游（y3-lualib）的 `include` 契约] → 这是**有意**的改写，已写进 `infrastructure.md` 那条照搬记录；将来从上游同步时要保留本改动。
- [重载时模块失败不再有明显信号（只有日志）] → `fire()` 会打出「reload modules: <名单>」，失败那条错误日志紧跟在对应模块之后；真需要更醒目的信号时再让 `fire()` 返回失败名单（本批不做）。
- [`error(result, 0)` 丢掉位置信息] → 交给外层 fatal handler 的堆栈；`include` 的调用点就在堆栈里，够定位。
