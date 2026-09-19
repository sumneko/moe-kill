# 代码风格

**基准**：LuaLS `lua-language-server` 仓库的 **`4.0.0` 分支**（不是 `master`，master 是 2022 年的老架构）。
风格来源：该分支的 `AGENTS.md` 与 `.github/skills/luals-server-dev/references/workflow-and-style.md`。

## 1. 排版

- Lua 文件 **4 空格**缩进。
- 行宽尽量接近 **120**。
- 多条件 `if` 的 `and` / `or` **顶格对齐**，这是有意设计的格式：

```lua
if  condA
and condB
and condC then
end
```

- 保持赋值、参数列表、`if` 分支的既有对齐风格；**不要做大范围纯格式化改动**。

## 2. 语法糖（由 `sumneko/utility` 提供，启动时 `enable*`）

| 写法 | 说明 |
| --- | --- |
| `'{} = {}' % { var, value }` | 位置参数 `{}`；命名参数 `{name}`；带格式 `{name%q}`、`{%d}` |
| `[[多行\n{}]]` % { x } | 多行模板直接用长字符串 |
| `root / 'main.lua'` | 字符串作为路径拼接（`enableDividStringAsPath`） |
| `<close>` / `m.defer(fn)` | 作用域退出时执行清理（`enableCloseFunction`） |

- **禁止**用 `('%s = %s'):format(a, b)` 或 `string.format(...)`。

## 3. 注释

- **禁止写任何注释**。
- 确有必要时，**必须先问用户并得到同意**；即便同意，只写意图、保持简练，不暴露内部实现细节。
- 例外：类型注解 `---@param` / `---@return` / `---@class` / `---@async` 是必须写的，不属于「注释」。

## 4. 语法陷阱

- **语句不要以 `(` 开头**：Lua 的 newline-call 规则会把「上一行以函数调用结尾 + 下一行以 `(` 开头」连成链式调用。必要时在上一行末尾加 `;` 断句。测试用例同样遵守。
- **可选链**：本工程支持 `?.` `?:` `?[` `?(`。该支持来自 bee.lua 的构建期补丁（**已在 bee.lua `master` 上**），由 `luamake -optchain` / `lm.optchain = true` 启用 —— 启用是项目默认构建的一部分，否则写了 `?.` 会直接解析失败。
  - 不要写 `a and a.b and a.b.c`，写 `a?.b?.c`。
  - `?.` 之后的类型收窄不可靠，因此**链上每一级都带 `?`**。
  - `Obj?:getManyResults()` 会保留方法的多返回值（区别于链式取值只取第一个返回值）。
- 例外目录：若某目录要保持语法兼容性（LuaLS 里是 `script/tools/`），该目录内不使用可选链。

## 5. 模块骨架

```lua
---@class Foo.Bar
local M = Class 'Foo.Bar'

function M:__init(name)
    self.name = name
end

function M:doSomething(value)
end

return {
    create = function (name)
        return New 'Foo.Bar' (name)
    end
}
```

- 非类模块用 `local m = {}` + `return m`（工具函数的写法）。
- 全局：`Class` / `New` / `Delete` / `Type` / `IsValid` / `Extends` / `Presize` 由引导文件挂到全局；项目自己的命名空间也挂在全局（LuaLS 用 `ls`，本工程用 `moe`，只在 `script/moe-kill.lua` 里赋值一次）。
- 命名：局部变量与函数 camelCase，常量全大写，类型名 PascalCase。
- 热点路径可在文件顶部冻结局部引用（`local tableSort = table.sort`）；这是可选优化，不是强制约定。**不要**照搬 `_ENV = nil`（LuaLS 4.0.0 里只有 3 个文件这么写）。

## 6. 类型与诊断

- 新增或修改 API 必须同步补齐类型注解。
- **改完 Lua 必须检查问题面板，把 information 及以上等级的问题清到 0**；hint 级不管（与上游 LuaLS 一致），不主动清理以免制造无关改动。
- 确实改不动的**来问用户**，不要留着不管。
- 一次性改动大量文件后，语言服务器可能延迟甚至卡住（面板迟迟不刷新）：执行命令 `lua.startServer` 重启它，再重新检查。
- **异步回调的标注**：把闭包当异步回调用时，光有参数类型 `async fun()` 不足以让 LuaLS 认定异步上下文，必须在**调用语句前**加一行 `---@async`（上游 `ls.await.call(function () ... end)` 就是这么写的），否则会报 `await-in-sync`。
- 访问动态键（如命令行参数表）时，用 `---@type table<string, T>` 显式标注该局部变量来表达"这里故意访问未知键"，不要用 disable 注释。
- 跨模块传递的结构体在 `---@class` 里声明全部字段，而不是只写 usage。

## 7. 语言与编辑器配置

- Lua **5.5**。
- `.luarc.json` 要点（照搬 4.0.0 的形态）：

```jsonc
{
    "runtime": {
        "version": "Lua 5.5",
        "path": ["script/?.lua", "script/?/init.lua", "?.lua", "?/init.lua"],
        "pathStrict": true,
        "nonstandardSymbol": ["?.", "?:", "?(", "?["]
    },
    "workspace": { "library": ["3rd/bee.lua/meta"] }
}
```

- 调试时把 `script/class.lua` 放进 `skipFiles`（类系统内部实现会污染单步）。
- **换行符：仓库内存 LF，工作区用平台本地换行符**。实现方式是 `.gitattributes` 只写 `* text=auto`（**不要写 `eol=lf`**，那会强制工作区也用 LF）、`.editorconfig` 用 `end_of_line = unset`、本地 `core.autocrlf=true`。
  - 效果：工作区是 LF 还是 CRLF，git 都不会视为修改；**不要**为了"统一"去批量转换行尾。
  - 注意：改动 `.gitattributes` 后如出现一批"被修改"的文件，跑一次 `git add --renormalize .` 即可消除。
- PowerShell 写文件务必指定 `-Encoding UTF8`，否则 UTF-8 源码会乱码（项目源码统一 UTF-8 无 BOM）。
