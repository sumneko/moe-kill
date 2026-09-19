# Design

## Context

- 现状：`server/moe-kill.lua` 在启动时一次性 `require` 全部模块（`moe.core = require 'core'` 等），没有任何重载入口。内核模块的写法统一为 `local M = Class 'Core.X'` + 模块级工厂函数（如 `M.create`），`server/core/card.lua` 用一个模块级 `local nextId = 0` 发唯一标识。
- `server/tools/class.lua` 与 `sumneko/utility` 的 `class.lua` **逐字节相同**（已核对哈希），而它**本来就为重载设计**：`M.declare` 遇到同名类时走 `if M._classes[name] then config:reset(); return M._classes[name], config end`（复用**同一个类表**），且 `Config:reset` 的注释原文就是「重置缓存，用于支持重载」（清 `initOrder`/`initCalls`/`mergedCompress`、递归 reset 已 init 的子类、清掉从父类复制过来的 `extendsKeys`）。⇒ 已存在的实例与类共用同一张类表，方法被重写后老实例立即可见。
- 参考实现：`y3-editor/y3-lualib` 的 `tools/reload.lua`（不在 `sumneko/utility` 里，也没有 `y3-editor/y3lib` 这个仓库）。它依赖 `Class` / `New` / `Delete` 全局、`log.error`、`y3.util.{revertMap, defer}`；本工程对应物齐全（`server/tools/utility.lua` 提供 `defer`(456 行) / `revertMap`(564 行) / `counter`(346 行)，`Class`/`New`/`Delete` 在 `server/moe-kill.lua` 赋值）。
- 约束：`server/core/` 必须保持「无 IO、纯同步、可直接调用」；测试必须无头可跑；项目约定「可叠加的操作返回 disposer」；`tools/` 是基础设施，被替换会连带炸掉事件循环与类库。

## Goals / Non-Goals

**Goals:**

- 在进程内提供可重载模块的登记、重载、前后回调与重载状态查询，接口形状与本工程命名/错误约定一致。
- 明确「重载后老实例自动用上新代码」这条语义成立，并且**不修改** `Class` 的既有实现（只同步上游一行修复）。
- 给出「必须跨重载存活的数据放哪里」的写法约定，并用 `Core.Card` 的标识计数器作为第一个落地样本。
- 让重载范围可配置、默认安全（只 `core`，基础设施永不重载）。

**Non-Goals:**

- 不做文件监视自动触发、不做协议/会话入口、不做 `--develop` 下的自动重载开关。
- 不做「重载时自动清理 timer / 事件订阅 / 旧的闭包引用」（`getIncludeName` 已能反向识别模块，留给有消费者的后续变更）。
- 不做 `game` 的动态装载与卸载；只保证注册表结构不挡这条路。
- 不做 Room / session 的「重载后重建世界」流程。

## Decisions

### D1 直接改写 `y3-lualib` 的 `tools/reload.lua`，不自研

它已经把「登记 → 清缓存 → 重新加载 → 前后回调」这条链路和回调归属这套细节做完了（含「模块自身被重载时它的回调自动注销」），自研只会重造一遍并漏掉细节。改写点仅限：

- `y3.util.X` → `moe.util.X`；`Class 'Reload'` 保持（本工程有同名全局）；挂到 `moe.reload = require 'tools.reload'`，并把 `M` 同时作为全局 `reload` 暴露？→ **不暴露全局**，只走 `moe.reload`（本工程除 `Class`/`New`/`Delete`/`Type`/`Extends`/`Presize` 外不再往全局加东西）。
- 回调注册 `onBeforeReload` / `onAfterReload` **返回 disposer**（上游返回空），以符合项目约定；撤销后再次重载不再触发。

### D2 接受全局 `require` 覆盖（用户拍板）

`reload.lua` 在模块顶层定义全局 `require`，用途是**登记 `loaderdata` → 模块名 的映射**（`M.modNameMap`），也就是「给定一个函数，反查它属于哪个可重载模块」的基础，将来清理 timer/事件订阅要靠它（`getIncludeName(func)` / `getCurrentIncludeName()`）。替代方案是不覆盖、只靠 `includeStack`，但那样只有「加载期间」能识别归属，**运行期拿到的回调闭包无从反查**，能力会残缺。

风险与约束：这是全局副作用，只在启动早期安装一次；实现必须与原始 `require` 行为一致（缓存优先、`package.loaded` 语义不变）；`tools/` 自身的加载顺序在其之前，不受影响。

### D3 类合并语义成立，`Class` 实现不动（用户拍板 ①②）

依赖上游既有行为（见 Context 的哈希核对与 `Config:reset` 注释），因此**不分叉** y3 那版已经分叉 786 行的 `class.lua`。唯一要动的是同步上游一行修复：`class:__newindex` 首行补 `config:init()` —— `config:reset()` 之后 `inited` 为 nil，此时首次写入实例会绕过 `config:init()`，导致「类重置后首次写入丢失继承 setter」。我们目前没用 `__getter`/`__setter`，但这是重载路径上的既有缺陷，顺手对齐上游（`utility` 上游另有 `mergeStruct` 等新增，本轮**不**跟）。

### D4 存活状态寄放：挂「重载后仍是同一张表」的载体 + 「有则复用」

门面表用 `moe.core = moe.core or {}`（首次加载创建，重载复用同一张表，外部持有的引用不失效）；类表由 `Class` 合并语义保证跨重载同一。必须存活的数据写成：

```lua
M.__counter = M.__counter or moe.util.counter()
```

两个细节：

- **命名建议 `__` 前缀**：`Config:init` 把父类的非 `__` 开头字段复制给用 `Extends` 的子类（并记入 `extendsKeys`，reset 时清除）。把状态挂在这个路径上会**串到子类**，也会被 reset 清掉；`__` 开头两件事都不会发生。
- 模块级 `local` 只允许放**不可变常量与纯函数**（如 `random.lua` 的 `GOLDEN`/`mix`、`zone.lua` 的 `resolvePosition`），可变量一律不许放。

### D5 重载范围：加载方式即边界，不做过滤配置

- `tools/` 一律普通 `require`（含 reload 自身）；`server/core/init.lua` 用 `include` 加载各内核模块，从而把它们登记进可重载集合，顺序即加载顺序。
- **判定只靠登记**：登记就是唯一依据，用 `require` 加载的模块天然不会被重载（「未登记的模块不受影响」）。因此**不需要**「只重载 core」这类过滤配置 —— 将来 `game` 只要改用 `include` 加载就自动进入范围（用户 2026-09-19 拍板）。
- 上游库自身带的 `list` / `filter`（`setDefaultOptional`）**保留但不用**：不引入默认范围配置，`reload()` 无参即重载全部已登记模块。这样少一个容易配错的旋钮。

### D6 语言服务器侧把 `include` 当作 `require`

`.luarc.json` 的 `runtime.special` 设 `{ "include": "require" }`。作用（已核实扩展 3.19.0 的实现）：

- `server/script/vm/global.lua` 里 `checkIsUndefinedGlobal` 先查 `rspecial[key]`，命中则直接返回「不是未定义全局」⇒ **不必**再把 `include` 塞进 `diagnostics.globals`（符合用户「不往 globals 里塞项目全局名压警告」的要求）。
- `server/script/parser/compile.lua` 会把该调用当 `require` 特殊调用处理（`addSpecial`），于是 `include 'core.card'` 的参数会被当作模块名解析、跳转、参与类型推断。

另：`.vscode/settings.json` 里的 `Lua.misc.parameters`（`--develop=true --dbgport=11418 --loglevel=trace`）**不能**挪进 `.luarc.json` —— 它是启动语言服务器的命令行参数，由扩展客户端用 `vscode.workspace.getConfiguration().get('Lua.misc.parameters')` 读取（`client/out/src/languageserver.js`），服务端只把它当参数描述文本，不消费它；`.luarc.json` 里写了不生效。因此只把重复的 `Lua.runtime.version`（`.luarc.json` 已有 `runtime.version`）从 VS Code 设置里去掉。

### D7 只提供接口，不做触发端（用户拍板 ⑤）

`--develop` 目前只开调试器，本轮不接 filewatch（半成品触发反而会掩盖问题）。触发端形态留待后续：开发期可用 `bee.filewatch`（上游 LuaLS 4.0.0 的 `script/tools/filewatch.lua` + `tools/glob.lua` 可照搬，但本轮不引入）；将来前端走协议方法触发。

### D8 测试策略：假模块测机制，真文件测端到端

- 机制类用例用 `package.preload['test.reload.probe']` 注册一个「文件」：清 `package.loaded` 再 require 时 preload 函数会重新执行，用变量模拟「文件内容变了」，无需落盘、确定性强，覆盖登记/重载/回调/自注销/范围边界。
- 端到端用例在 `server/tmp/`（已 gitignore）里真写一个模块文件、把它所在目录临时补进 `package.path`，改内容后重载并断言新行为，证明「改磁盘文件 → 重载生效」。
- 用例只断言**自己探针**的行为（探针自身幂等），不依赖其它已登记模块；用完撤销自己注册的回调。因为范围就是登记集合，测试不会引入额外配置。

### D9 注册表为将来 `game` 的装卸预留形状

登记时按顺序保留 `includedNames`（现在就有），使「一次性卸掉某一前缀的全部模块」成为可能；本轮**不提供**卸除接口，也不实现 mod 式装载。将来若 `game` 不走 `require`（例如从内存/打包产物加载），需要的是「自定义加载器 + 卸除」两件事，届时另开变更。

## Risks / Trade-offs

- [合并语义下**被删掉的方法不会消失**：类表复用只覆盖字段不删除，删掉源码里的一个方法后老类表上仍然有它] → 文档写明「重载只保证新增/改写生效，不保证删除生效」；避免给公共方法改名或删除。
- [老实例不会重跑 `__init`：新代码若要求实例多一个字段，老实例没有该字段] → 约定实例字段读取要容忍 `nil`；需要新字段时由调用方显式初始化（或重建对象）。
- [全局 `require` 被覆盖是进程级副作用，出错会波及所有模块加载] → 实现保持与原生语义一致（缓存优先），只在启动早期安装一次；`tools/` 在自己的加载期用不到它。
- [登记表只增不减：测试登记的探针模块会留在集合里] → 探针自身幂等，用例只断言自己的探针；生产入口只在启动时登记一次内核模块。
- [重载期间旧的闭包（timer、事件订阅）仍指向旧函数] → 本轮明确不做清理；将来用 `getIncludeName` 按模块清理时，接口已备好。
- [重载 `core` 时若门面表被重建，外部持有的旧引用失效] → 门面写成 `moe.core = moe.core or {}`；同时约定「状态寄放在类表或门面表，不放在模块级局部」。
- [改 `class.lua` 会与 `sumneko/utility` 上游分叉] → 只同步上游已有的那一行修复，改动量 1 行，保持可与上游继续 diff。

## Migration Plan

- 门面形状调整只影响内核内部写法（`moe.core.card.create` 这类调用点形状不变），无需调用方迁移。
- 回滚：删掉 `server/tools/reload.lua` 与 `moe.reload` 挂载、把 `core/init.lua` 的 `include` 换回 `require`、`card.lua` 的计数器回到模块级 `local` 即可；`class.lua` 的一行修复可单独保留（它是上游行为）。

## Open Questions

- 触发端最终形态（filewatch 自动重载 vs 只在协议里暴露 `reload` 方法 vs 两者都要）——等有前端/开发壳时再定。
- `game` 的装载模型（`require` 扩展名包 vs 自建加载器）与卸载粒度（整包卸载 vs 单模块）——等规则层提案时定。
