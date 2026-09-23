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
- **换行的链式调用**：续行写成 `: 方法(...)`（**冒号后留一个空格**），与参考项目一致（LuaLS 4.0.0 的换行链式调用基本都是这个形状）；同一行内的 `obj:method()` **不留**空格。

```lua
Card '杀'
    : on('获取目标', function (ctx)
    end)
    : on('使用', function (ctx)
    end)
```

## 2. 语法糖（由 `sumneko/utility` 提供，启动时 `enable*`）

| 写法 | 说明 |
| --- | --- |
| `'{} = {}' % { var, value }` | 位置参数 `{}`；命名参数 `{name}`；带格式 `{name%q}`、`{%d}` |
| `[[多行\n{}]]` % { x } | 多行模板直接用长字符串 |
| `root / 'main.lua'` | 字符串作为路径拼接（`enableDividStringAsPath`） |
| `<close>` / `m.defer(fn)` | 作用域退出时执行清理（`enableCloseFunction`） |

- **禁止**用 `('%s = %s'):format(a, b)` 或 `string.format(...)`。

## 3. 注释

- **尽量不写注释**（用户 2026-09-19 定）：代码自己该说清楚的事不要用注释说（说不清就先改名 / 拆函数）；确有必要时**必须先问用户**，即便同意也只写意图、保持简练。
- **注释的位置：单独占一行，放在它说明的那段代码之前**（用户 2026-09-23 定）：**不写行尾注释**（`x = y  -- 说明`、`function f() ... end  -- 说明` 这类上游写法都不要照抄；`server/tools/` 的照搬件保持上游原样属例外）。存量行尾注释**顺手清**：与文件顶部说明 / 接口 `#` 说明重复的直接删，确有信息量的挪到**单独一行**。**但很短的就别动**（几个字，如 `-- 重复调` / `-- 内奸`，用户 2026-09-23 补：短的就留着，不必为了挪而挪）。
- **例外一 = 接口的一行说明**：**入口**（公开/内核的函数、方法、字段、模块门面）保留**一行极短的中文说明**，几个字即可 —— 如 `---@field title string # 获取标题`、`---@return Card # 新牌`；贴在类型注解的 `#` 后面，**不另起 `--` 注释行**。
- **例外二 = 内容侧定义文件顶部的官方描述**（用户 2026-09-20 定）：`package/` 里的**卡牌 / 技能**定义文件在**文件顶部**用 `--` 写该卡牌 / 技能的**官方描述**（名字 + 规则文字，注明口径来源）—— 将来技能同样适用。只写官方描述本身，实现边界与说明不写在这儿。见 `sanguosha-rules` 的 §9.3。
- **例外三 = 装配目录各文件顶部的一行功能说明**（用户 2026-09-23 定）：`package/` 里的**装配目录**（`@基础` / `身份场` 这类「把内核机制接成一套规则」的目录）里的每个文件都在**顶部**用 `--` 写一行（至多两三行）「这个文件做了哪些功能」—— 这些文件名短（`使用.lua` / `胜负.lua`），光看名字与正文看不出它**订阅了哪些时机、建了哪些东西**，例如 `-- 效果收尾：把临时处理区里剩下的牌送进弃牌堆`。
- **例外二与例外三的分工**：例外二写**内容定义**（卡牌 / 技能 / 牌表）的官方描述，例外三写**装配文件**的职责摘要。**纯类型声明文件（`meta.lua`）不写**。
- 类型注解 `---@param` / `---@return` / `---@class` / `---@field` / `---@async` **是必须写的**，不属于「注释」。

## 4. 语法陷阱

- **语句不要以 `(` 开头**：Lua 的 newline-call 规则会把「上一行以函数调用结尾 + 下一行以 `(` 开头」连成链式调用。必要时在上一行末尾加 `;` 断句。测试用例同样遵守。
- **`_` 作 for 循环变量是常量**：Lua 5.5 里 `for _ = 1, n do ... end` 合法，但**循环体内给 `_` 赋值是编译期错误**（`attempt to assign to const variable '_'`）；报错发生在 `load` 阶段，`pcall` 抓不住。需要赋值时改用具名循环变量。
- **中文只能出现在字符串里**：Lua 标识符只允许 ASCII 字母 / 数字 / 下划线。用中文做表键要写 `{ ['可见'] = true }`，写成 `{ 可见 = true }` 会报 `unexpected symbol near '<\229>'`。
- **可选链**：本工程支持 `?.` `?:` `?[` `?(`。该支持来自 bee.lua 的构建期补丁（**已在 bee.lua `master` 上**），由 `luamake -optchain` / `lm.optchain = true` 启用 —— 启用是项目默认构建的一部分，否则写了 `?.` 会直接解析失败。
  - 不要写 `a and a.b and a.b.c`，写 `a?.b?.c`。
  - `?.` 之后的类型收窄不可靠，因此**链上每一级都带 `?`**。
  - `Obj?:getManyResults()` 会保留方法的多返回值（区别于链式取值只取第一个返回值）。
- 例外目录：若某目录要保持语法兼容性（LuaLS 里是 `script/tools/`，本工程对应 `server/tools/`），该目录内不使用可选链。

## 5. 模块骨架

```lua
---@class Foo.Bar
local M = Class 'Foo.Bar'

function M:__init(name)
    self.name = name
end

function M:doSomething(value)
end

---@class Foo.Bar.API
moe.fooBar = {}

---@param name string
---@return Foo.Bar
function moe.fooBar.create(name)
    return New 'Foo.Bar' (name)
end
```

- 模块的表变量**统一用大写 `M`**：声明了类的模块写 `---@class X` + `local M = Class 'X'`；`tools/` 与 `core/loader/` 的**内部子模块**（别人 `require` 它、要拿返回值那种）写 `local M = {}` + `return M`。**不要**写 `local m`。
- **内核对象模块的门面直接建在 `moe` 上，只放工厂**（用户 2026-09-21 定，取代原来的「`local API = {}` + `return API`」）：`local M = Class 'Random'` 里只写类与实例方法（**类上不放 `create`**），末尾 —— `---@class Random.API` + `moe.random = {}` + `function moe.random.create(种子) return New 'Random' (种子) end`，**不 `return`**。于是 `moe.random.create(种子)` 与 `New 'Random' (种子)` 两种写法都可用，而**类的方法不会从全局可达**（`moe.random:nextInt(...)` 这样的写法根本不存在，拼错/误用会当场 nil）。
  - 好处：`server/core/init.lua` 只剩一串 `include`（不再 `moe.X = include 'core.X'`），门面由**可重载的模块自己**重建；`---@class X.API` 就标在这次赋值上，`moe.X` 的类型当场定下来 —— **`server/moe-kill.lua` 的 `MoeKill` 上不用再写这些字段**（实测跨文件也认：`moe.card` 显示为 `Card.API`）。
  - 类型名写成「类名.API」（`Player.API` / `Desk.API`）；类上其余的静态成员（如 `Effect.deep`）仍留在类上、不进 API 表。
  - 没有工厂的模块（`Effect`）**不建门面** —— `moe.effect` 干脆不存在；基类靠 `Extends` 声明继承，类名仍在类注册表里可用。
  - `server/core/loader/init.lua` 同样写 `moe.loader = {}`；它内部 `require` 的 `vfs` / `preparse` 是内部子模块，照旧 `local M` + `return M`。
  - `server/session/init.lua` 也走这条：`---@class Server` + `moe.server = {}`，`server/moe-kill.lua` 里只 `require 'session'`（不再 `moe.server = require 'session'`）。
- **可叠加的操作必须返回 disposer**：任何“添加/附加”类操作（加属性修正、加标记、订阅事件…）一律返回一个撤销函数，形状统一为 `local undo = obj:addXxx(...)` → `undo()` 只撤销那一次添加（重复 `undo()` 安全）。订阅类接口（如 `attrs:onChange(name, cb)`）同样返回 disposer；需要多个可撤销项时就叠加调用各自的 disposer。
  - **但不必每次注册都去撤销它**：热重载下，可重载模块里“跟着模块走”的注册会**自动注销**，此时不要写 disposer；disposer 只用于两类情况——注册发生在不可重载的模块里，或资源必须重建/显式释放（详见 `references/architecture.md` 第 8.5 节）。
- **模块不许持模块级可变状态**（热重载要求）：`local` 只放不可变常量与纯函数；必须跨重载存活的状态挂到**跨重载仍是同一份的载体**上 —— **属于某一局的就挂局实例**（`game` 上的字段，如号源 `game:nextId()`）；**内核级、跨局的**才挂**门面表 `moe`**（在 `moe-kill.lua` 里建立），后者写成「有则复用」（`moe._x = moe._x or <初值>`），用 **`_` 前缀**标明是内核内部状态，并在赋值处标 **`---@package`**（LuaLS 据此强制「只有这个文件能访问」，见 `references/architecture.md` 第 8.4 节）。**不要挂类表**（`Extends` 会把父类字段复制给子类、重载 `reset` 又会清掉），也不要挂模块门面（`moe.card` 由模块自己建，重载重跑模块就换成新表）。重载语义与边界见 `references/architecture.md` 第 8 节。
- **等待由任务承担**（`Effect:suspend` 与「让出理由分派 / 逐层原样转发」已删除，用户 2026-09-20 定）：每个效果跑在自己任务的协程里（`Task:execute`），所以**结算体与时机回调里可以直接 `await`**（`moe.await.sleep` / `moe.await.yield`，应答方就是这么让出的）；要等别的东西结完用 `效果:await()`。注意 `moe.await.*` 的恢复绑在**调用它的那个协程**上 —— 用它们的地方必须真的跑在协程里（整个游戏都在协程里跑，见 `references/architecture.md` §12 的「前提」）。
- **运行时不做类型判定**（用户 2026-09-19 定，先试过 `kind` 断言后修正）：
  - “是牌还是牌区”这类**同一家族内部**的区分由**类型注解**保证（`---@param card Card`），不要写 `Type` / `isInstanceOf`，也不要为了断言再加一道 `kind` 判定。
  - `kind` **只用来区分子类**：基类在自己的 `__init` 里给个默认值（`Zone` → `'zone'`），子类在自己的 `__init` 里覆盖成自己的名字（`OrderedZone` → `'orderedZone'`；规则层子类可设 `'手牌'` 之类），调用方按需读它判断（`zone.kind == '手牌'`）。因为许可值开放，字段类型声明写 `string`，内核不维护 kinds 清单。
- **`server/tools/` 是照搬来的基础设施，不要随便改**：这些文件保持上游原样（风格与本工程不一致也照旧），确需改动先问用户。
  - 从 4.0.0 的 `script/` 根搬进来的通用库也在里面：`tools/class.lua`（类系统）、`tools/utility.lua`（工具库）、`tools/attribute.lua`（属性库，来自 `sumneko/utility` 上游）。上游这些文件位于 `script/` 根，**从上游更新时注意路径差异**。
- 全局：`Class` / `New` / `Delete` / `Type` / `IsValid` / `Extends` / `Presize` 由引导文件挂到全局；项目自己的命名空间也挂在全局（LuaLS 用 `ls`，本工程用 `moe`，只在 `server/moe-kill.lua` 里赋值一次）。
- 命名：局部变量与函数 camelCase，常量全大写，类型名 PascalCase。
- 热点路径可在文件顶部冻结局部引用（`local tableSort = table.sort`）；这是可选优化，不是强制约定。**不要**照搬 `_ENV = nil`（LuaLS 4.0.0 里只有 3 个文件这么写）。

## 6. 类型与诊断

- 新增或修改 API 必须同步补齐类型注解。
- **改完 Lua 必须检查问题面板，把 information 及以上等级的问题清到 0**；hint 级不管（与上游 LuaLS 一致），不主动清理以免制造无关改动。
- 确实改不动的**来问用户**，不要留着不管。
- 一次性改动大量文件后，语言服务器可能延迟甚至卡住（面板迟迟不刷新）：执行命令 `lua.startServer` 重启它，再重新检查。
- **异步回调的标注**：把闭包当异步回调用时，用 `---@async` 标出来（上游 `ls.await.call(function () ... end)` 就是这么写的）。本项目已在 `.luarc.json` 里把 `await` 组整体设成 `None`（`await-in-sync` 在"让出由驱动点收尾"这类写法上会误报，用户 2026-09-19 定），所以这条现在是**说明性**的、不再用作消警告手段。
- **错误报告分两条路**（2026-09-19 定，与 `game-events` 的口径一致）：
  - **内容包代码出错**（时机订阅者 / 牌的 `'生效'` 回调…）：`xpcall(f, log.error, ...)` 隔离 + 记日志，**不让触发本身失败、也不打断其余回调**。`log.error` 自带堆栈并把消息作为返回值交给调用方 —— 不要再写 `xpcall(f, debug.traceback)` 再手写一遍 `log.error(...)`（会重复记录）。上游 `tools/` 就是这个写法（`timer.lua`、`simple-event.lua`）。例外：报告"用例 / 模块失败"的测试入口（`test.lua`、`test/ltest.lua`）仍用 `debug.traceback` —— 那里堆栈本身就是报告内容。
  - **内核契约违反**（校验不通过 / 子类未实现 `settle`）：**记进效果自己的 `.err`** —— 效果由任务驱动，错误由这个任务交给错误处理器（生产环境是 `log.error`、测试里是 `lt.errors` 计数），**不向调用方抛异常**（用户 2026-09-20 定：「出杀时不能因为闪的响应代码里出错就让这次杀无效」）⇒ 调用方读 `.err` 判断成败，**不要写 `pcall`**；`:apply()` / `:await()` 只返回效果自己。
- 访问动态键（如命令行参数表）时，用 `---@type table<string, T>` 显式标注该局部变量来表达"这里故意访问未知键"，不要用 disable 注释。
- 跨模块传递的结构体在 `---@class` 里声明全部字段，而不是只写 usage。
- **字段已经有明确赋值时，不再在 `---@class` 下加 `---@field`**（用户 2026-09-21 定）：`self.x = ...` 本身就是声明，LuaLS 会据此推出字段与类型，再补一条 `---@field x T` 只是重复。**只在赋值表达不出来的时候才写**，常见的三类：
  - **可选与可见性**：`---@field x? T`、`private` / `package` 赋值表达不出来。且 LuaLS 的 `package` 可见性**按文件算** —— 父类标了 `---@package` 的字段，子类要在自己的文件里用就得**再声明一次**（`AskCard` 的 `task` 就是为此保留；删了会报 `invisible`）。
    - **该藏的字段就得藏**（用户 2026-09-21 定）：只在内核内部用、内容包与装配侧不该看见的字段一律标 `---@private`（如 `Game` 的 `events` / `cards` / `packages` / `values` / `flow`）—— “外面现在没人读”不等于“外面可以读”。
    - **用例是白盒，要看内部字段就那一行就地开个口子**：`---@diagnostic disable-next-line: invisible`（诊断名就是 `invisible`）。**产品代码不许用 disable 绕可见性** —— 真需要就从类上开一个正式入口。
  - **赋值给的是 `any` / `unknown`**：`moe.inspect` 的 `fun(root: any): string` 是**收窄** —— `tools/inspect.lua` 没注解，赋值只能推出 `unknown`，所以这条 `---@field` 留着。反过来，`moe.card = {}` 这类赋值带了 `---@class Card.API`，字段类型当场就定下来了（跨文件也认），**不用**再在 `MoeKill` 上写字段。
  - **要放宽或要元素类型**：`Zone` / `Effect` 的 `kind` 声明成 `string`，是为了让子类（含规则层与测试）能换成自己的名字；`game.lua` 的 `self.cards = {}` 空表赋值说不出 `table<string, table<string, CardDef>>` 这种元素类型。
  - 与上一条不冲突：上一条说的是 `XXX.CreateOptions` 这类**没有赋值过程**的入参结构体。
- **可选标记写在「名字」上，不写在类型后面**（用户 2026-09-19 定）：`---@field key? number`、`---@param key? number`、`fun(x: number, y?: number)`。不要写 `---@field key number?` / `---@param key number?` / `fun(x: number, y: number?)`。
  - `server/tools/` 里照搬来的文件保持上游原样，**不按这条改**（也不为了统一去动上游文件）。
  - **跨文件给同一个字段名追加签名必须带兜底**（2026-09-21 实测）：在别的文件里重声明 `---@class X` 并写 `---@field f ...`，**会接管 `f` 这个名字的签名表**（不是叠加）—— 内核那份来自方法定义的签名会被报错掉。所以包里写 `---@field getTag fun(self: Player, key: '身份'): 身份场.身份` 时，**必须再补一条 `key: string` 的兜底**（详见 `architecture.md` 9.6 的「包自带 `meta.lua`」）；重声明类时基类也要写全（`---@class Player: Class.Base`）。
- **字段名撞 LuaDoc 访问修饰符时要显式写修饰符**：`private` / `protected` / `package` / `public` 是 **LuaDoc 的访问修饰符**，字段真叫 `package` 时直接写 `---@field package string` 会被解析成「修饰符 + 名字」而报 `luadoc-miss-type-name`（去掉 `#` 后又报 `undefined-doc-name`）；正确写法是 **`---@field public package string # 所属包名`**。
  - 同理：`---@field` 的描述必须带 `#` 引导（`类型 # 描述`），直接跟中文会被当成第二个类型。

## 7. 语言与编辑器配置

- Lua **5.5**。
- `.luarc.json` 要点（照搬 4.0.0 的形态）：

```jsonc
{
    "runtime": {
        "version": "Lua 5.5",
        "path": ["server/?.lua", "server/?/init.lua", "?.lua", "?/init.lua"],
        "pathStrict": true,
        "nonstandardSymbol": ["?.", "?:", "?(", "?["]
    },
    "workspace": { "library": ["3rd/bee.lua/meta"] }
}
```

- 调试时把 `server/tools/class.lua` 放进 `skipFiles`（类系统内部实现会污染单步）。
- **换行符：仓库内存 LF，工作区用平台本地换行符**。实现方式是 `.gitattributes` 只写 `* text=auto`（**不要写 `eol=lf`**，那会强制工作区也用 LF）、`.editorconfig` 用 `end_of_line = unset`、本地 `core.autocrlf=true`。
  - 效果：工作区是 LF 还是 CRLF，git 都不会视为修改；**不要**为了"统一"去批量转换行尾。
  - 注意：改动 `.gitattributes` 后如出现一批"被修改"的文件，跑一次 `git add --renormalize .` 即可消除。

## 8. 命名与中文标识符

运行时**允许中文标识符**（构建期补丁 + `.luarc.json` 的 `runtime.unicodeName`，见 `infrastructure.md`），但**默认写英文** —— 中文只留给**难以翻译的名字**（用户 2026-09-19 定）：

| 类别 | 用什么 | 例子 |
| ---- | ---- | ---- |
| 字段名、局部变量、函数名、参数名 | **英文** | `{ name = '杀', count = 30 }`、`local deck = ...`、`local function totalCards()` |
| 技能名 / 卡牌名 / 身份名等内容词 | 中文 | `'杀'`、`'闪'`、`'主公'`、`'奸雄'` |
| 数据取值与配置键（规则数值的键、属性名、时机名、标签键） | 中文 | `game:setValue('体力上限', 4)`、`attrs:get('体力')`、`'游戏-开始'`、`setTag('身份', '主公')` |
| 包名与包内文件名 | 中文 | `package/标准/牌表.lua`、`package/身份包/开局.lua` |

- 理由：中文名是**给写规则的人看的**（读起来像规则），字段与变量是**代码**（给写引擎的人看）；两者混在一起会让「这是标识符还是字符串」变得难分。
- 测试用例里的**断言说明文本**用中文（它是给人读的消息），但**变量名用英文**；探针字符串里的代码同样遵守本表。
- PowerShell 写文件务必指定 `-Encoding UTF8`，否则 UTF-8 源码会乱码（项目源码统一 UTF-8 无 BOM）。
- 包目录名可以带一个 `@` 前缀（表示该包默认加载，见 `architecture.md` 第 9 节），包内文件名不带。
- **注入环境给的「函数」用 PascalCase，给的「对象 / 命名空间」小写**（用户 2026-09-19 定）：`Card` / `Depends` 是框架入口（与既有的 `Class` / `New` / `Extends` 同类），`game`（与 `moe` 同类）是环境给的对象。理由：包文件里 `local card = game:createCard('杀')` 这类局部变量很自然，小写入口一遮就没了；大写既躲开遮蔽，又能一眼区分「加载期 DSL」与「普通 API」。
  - **给标准库加助手就用库名本身**（用户 2026-09-21 定）：`table.filter` / 将来的 `string.trim`，**不要**另起 `Table` / `util` 这类全局 —— 名字自己说明了「这是对标准库的扩充」（做法与边界见 `architecture.md` 9.6）。

## 9. 防御性检查的边界

**正常流程下不会出现的情况，不写防御**（用户 2026-09-19 定）。判断标准是「**这一步真的会缺吗**」，而不是「万一呢」。

| 要不要检查 | 例子 |
| ---- | ---- |
| **不检查**：调用约定 / 类型契约已经保证的 | 环境给的 `game`（就是这一局）、自己模块内互相调用的参数、自己创建的对象 |
| **不检查**：防自己人篡改 | 不校验「我们自己定义的函数 / 对象会不会被使用者替换」—— 那不是本工程要支持的用法；我们相信 `game` 拿到的是我们自己定义的局 |
| **要检查**：运行期真的会缺的 | 清单里可能没有内容包 ⇒ 牌表缺失（`package/基础/牌堆.lua` 里报错且不建空牌堆）、人数不在身份配置表里（`package/身份场/开局.lua`） |
| **要检查**：来自外部的输入 | 协议 / 前端传来的数据、磁盘上别人的包与文件 |

- 与 §6 的「运行时不做类型判定」同一条思路：能靠**类型注解**在编辑期 / 编译期暴露的，就不在运行期再写一遍。
- 结论：**少写 `if not x then error(...)`** —— 它让正常路径变长，还把「不可能发生」伪装成「可能发生」，读者会分不清哪些才是真要处理的情况。

## 10. `error` 的语义

**`error` 只有一个语义：报错；禁止用 `error` 做跳出**（用户 2026-09-20 定）。

- 不要用 `error` 做控制流（「取消这次生效」「提前结束这次结算」这类）：错误处理器（`moe.task.setErrorHandler` 接的日志）与测试的错误日志计数都会把它当故障，调用方也分不清"失败"与"正常结束"。
- 需要**中断**当前执行体时：让出（`coroutine.yield()`）暂停自己，由持有者（`Task`）收尾并关闭执行体 —— `Effect:remove()` 取消一次生效就是这么做的（`task:reject(CANCELED)` + 让出；`Task:execute` 发现「任务已结完但执行体还挂着」就 `coroutine.close` 收掉它 —— 于是它再也跑不下去）。
- 需要表达"这次任务因为什么结束"时用 `task:reject(原因)`（如 `Task.TIMEOUT`、内核的取消信号），不要抛错让上层去猜。
- 于是**只有真故障**才会走到 `Task` 的错误处理器。

## 11. 读取接口：不需要参数的用字段，别写 `getXxx()`

**不用传参数的读取，尽量不做成 `getXxx()` 方法**（用户 2026-09-23 定）：直接用**字段**；算出来的值用 **`__getter`** 伪装成同一种读法。`getXxx(参数)` 照旧 —— 它要传参数，本来就是方法。

| 读法 | 用在哪 | 例子 |
| ---- | ---- | ---- |
| **字段** | 存下来的数据 | `card.suit` / `card.point`、`game.desk`、`player.game` |
| **`__getter`** | 算出来的（每次现算，不缓存） | `desk.players`、`desk.alivePlayers`、`player.acting` |
| **`getXxx(参数)`** | 要传参的读取 | `player:getAttr('体力')`、`game:getZone('抽牌')`、`attrs:get(name)` |

- 理由：`player:getAttr('体力')` 与方法（会做事的东西）一眼可分；而 `card:getLabel()` 这种**没有参数**的方法，读起来像「可能要做点什么」，实际只是取个字段 —— 调用方平白多一层，也让人误以为背后有逻辑。**算出来的值**用 `__getter` 的好处是：调用方不必知道「这是存的还是算的」（`desk.players` 与 `desk.alivePlayers` 读法一致），将来把字段改成派生（或反过来）**调用点一行不改**。
- **不缓存派生值**：`__getter` 每次现算（`desk.alivePlayers` 就是这么做的，理由见 `architecture.md` 第 12 节 —— 局的事件表每次装载都清空，挂在它上面的内核缓存会静默失效）。
- **存量不动**：已经有的一批无参 `getXxx()`（`Card:getLabel` / `getId`、`Game:getResult` / `getEffects` / `getZones`、`Player:getZones` …）**不主动清理**（改它们是纯噪音改动、还会碰到别人的代码）；顺手遇到相关代码时再单独提。
- 边界：**这不是「字段都公开」**—— 需要封装的（如 `Zone` 内部的 `cards`、`Game` 内部的 `events`）照样用 `private` + 方法；本节的只是「**只读、无参**」这类接口的形状选择。
