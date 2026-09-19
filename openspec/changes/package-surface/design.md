# Design

## Context

动机见 `proposal.md`。与做法相关的现状：

- 装载器用 `makeEnv(extra)` 造执行环境：先按 `ALLOWED_GLOBALS` 白名单从标准库取，再铺上 `extra`（现在是 `game` / `Card` / `Depends`）。白名单是**名字清单**，加东西只需改这一处。
- `moe.util`（`server/tools/utility.lua`，照搬上游）里已有现成的数组工具：`map(t, callback)`（`(值, 下标)` 泛型）与 `arrayHas(array, value)`；**没有 `filter`**。
- `Game` 上已经有多个公开字段（`sources` / `list` / `cards` / `values` …），而 `desk` / `random` 既有字段又有 getter。

## Goals / Non-Goals

**Goals:**

- 内容侧有**够用且安全**的工具：纯函数、名字直白、类型可见（有补全）。
- 内容侧的"环境是什么"继续能一句话说清（`game` + `Card` / `Depends` + `util` + 标准库白名单）。
- `game` 的读取只剩一种写法。

**Non-Goals:**

- 不做"增强标准库"（往注入的 `table` 上挂私货）—— 读包的人会误以为它是 Lua 自带的，将来把包挪到别的引擎也会踩坑。
- 不把工具挂在局上（`game.table.filter`）：`game` 是"这一局"，纯函数挂上去语义不对，且 `table` 这种字段名迟早与局自己的东西撞。
- 不做"按需注入"或"工具集分层"（核心 / 进阶）之类，清单先就三个函数。

## Decisions

### D1 注入一个独立名字 `util`，而不是扩标准库或挂局上

**为什么**：来源清楚（"引擎给的，不是 Lua 自带的"）、不污染 `table` 这个标准库名字、也不给"局"这个状态对象塞无关东西。

**备选**：增强注入的 `table`（`table.filter`）—— 迷惑性大；`game.table.filter`（零规格改动，但语义错位）；整个 `moe.util` 直接注入 —— 里面有 `saveFile` / `defer` 这类副作用，等于给内容侧开了 IO。

### D2 只放纯函数，且先只放三个：`filter` / `map` / `contains`

- `filter(list, predicate)` —— 新写（上游没有）；
- `map(list, transform)` —— 转调 `moe.util.map`（`(值, 下标)`, 泛型）；
- `contains(list, value)` —— 转调 `moe.util.arrayHas`（换个更直白的名字）。

**为什么**：这三个覆盖了"筛目标 / 变换列表 / 判定包含"这三类重复写法（`contains` 尤其常用：判断目标在不在合法列表里）。清单短，才守得住"纯函数"这条线。

**备选**：一次给十几个（很快就会有人往里塞带副作用的东西）；一个都不给（每张牌手写 5 行循环，等重复出现再加）。

### D3 类型面放进 `env-meta.lua`

```lua
---@type Loader.EnvUtil
util = nil
```

`Loader.EnvUtil` 声明三个函数的签名（`filter` / `map` 用 `---@generic` 让"筛 `Player[]` 得到 `Player[]`"能推断出来）。**清单以类型文件为准** —— 与牌的钩子清单同一个口径。

### D4 删 `getDesk` / `getRandom`，统一用字段

**为什么**：一个概念不要两套 API；规格本来就写的是公开字段（`core-game`），getter 是历史遗留（从"场地"时代带过来的）。字段可写的代价由既有约定吸收：不过度防御、`Game` 上本就有别的公开字段。

**备选**：保留 getter 只改包代码（两套继续并存，下次还会有人问"该用哪个"）。

## Risks / Trade-offs

- [工具集会长大，慢慢混进带副作用的东西] → 规格里写死"只含纯函数"，清单以 `env-meta` 为准；每次加都要过一遍这条线。
- [`util.filter` 与 Lua 生态里别的 `filter` 语义（有的返回"被筛掉的那半"）不同] → 名字保持最通用的语义（返回满足条件的元素），文档写一句。
- [删 getter 让"外部代码"看到的 API 变了] → 现在没有外部消费者（只有本仓库的包与测试），一次改齐。
- [包作者可能以为 `util` 就是 `moe.util`，进而期待里面有 `defer` / `saveFile`] → 类型文件只声明那三个；`env-meta` 注释写明"是收窄的工具集，不是内核工具库本体"。

## Open Questions

- 将来要不要给内容侧"断言 / 报错"类工具（`util.assert(条件, 消息)`，让包里的错误信息统一格式）？等第一处真的需要时再定。
- 工具集要不要也开放给**装配方**（测试 / 将来的流程层）用同一份？它们本来就能 `require 'tools.utility'`，暂时不必。
