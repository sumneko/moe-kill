# Proposal

## Why

内核（`server/core/`）与将来的规则集（`game/`）都是纯 Lua 逻辑，改一行就要重启进程才能生效，开发期迭代成本高；本工程又是无头后端，没有任何前端热更新手段可用。需要在后端内部提供热重载能力，并确定一套「哪些模块可重载、状态如何跨重载存活」的约定。

## What Changes

- 引入热重载能力（`moe.reload`）：把模块登记为「可重载」，重载时清掉模块缓存并重新加载，重载前后各有回调（回调自动关联注册它的模块，模块本身被重载时不重复注册）。
- 可重载模块用 `include`（而非 `require`）加载；内核模块一律走 `include`，`tools/` 基础设施一律走 `require`（**基础设施 MUST NOT 被重载**）。**重载范围完全由「用哪个入口加载」决定，不引入名单 / 过滤配置。**
- **BREAKING**（对内核内部写法而言）：`moe.core` 改为「门面表 + 工厂函数」形状（`moe.core.card.create`），内核模块**不得**再持有模块级可变状态；必须跨重载存活的数据改成挂在类表/门面上的「有则复用」写法，例如 `moe.core.card.counter = moe.core.card.counter or moe.util.counter()`。当前唯一命中项是 `Core.Card` 的 ID 计数器（现在放在模块级 `local`，重载会让 ID 与已有实例撞车）。
- 依赖既有类库「同名类合并」语义：重载后同名类**复用同一个类表**，因此**已存在的实例自动用上新代码**（无需重建对象）。
- 顺带把 vendor 的 `tools/class.lua` 对齐 `sumneko/utility` 上游的一行修复（`class:__newindex` 首行补 `config:init()`，修「类重置后首次写入丢失继承 setter」）——正是重载路径上的问题。
- 本轮**只提供接口**：不做文件监视、不做协议/会话入口、不做自动触发；触发端（开发期 filewatch、将来的前端 RPC）留待后续变更。
- 重载范围目前只覆盖 `core`（因为只有内核模块用 `include` 加载）；`game`（规则集）将来可能不走 `require` 加载，需要支持像 mod 那样动态装载/卸载，本轮只保证注册表结构不挡这条路。
- 语言服务器侧配套：`.luarc.json` 把 `include` 视为 `require`（`runtime.special`），使 `include 'core.card'` 能被解析、跳转与推断返回类型，同时不再报「未定义的全局名」。

## Capabilities

### New Capabilities

- `hot-reload`: 后端内部的热重载能力——可重载模块的登记与重载过程、重载前后的回调、重载后类与实例的代码更新、跨重载存活状态的寄放约定，以及重载范围的边界（基础设施不可重载）。

### Modified Capabilities

- `core-zones`: 「牌的实例标识」这一条要求收紧——唯一标识在**热重载之后**仍必须唯一（不得与已存在实例的标识重复）。

## Impact

- 新增：`server/tools/reload.lua`（热重载实现，源自 `y3-editor/y3-lualib` 的 `tools/reload.lua`，按本工程命名与依赖改写）。
- 修改：`server/moe-kill.lua`（挂 `moe.reload`，它会在全局覆盖 `require`）、`server/core/init.lua`（门面改形状 + 改用 `include`）、`server/core/card.lua`（ID 计数器改挂类表）、`server/tools/class.lua`（对齐上游一行修复）。
- 配置：`.luarc.json` 增加 `runtime.special`（`include` → `require`）；`.vscode/settings.json` 不再重复放 Lua 运行期设置（`Lua.misc.parameters` 是启动参数，必须留在 VS Code 设置里，见 design.md）。
- 新增测试：`server/test/core/reload.lua` 一类（机制用例 + 真·改文件端到端用例），沿用现有 `--test` 骨架，**不需要前端**即可跑完整验证。
- 文档：`.agents/skills/moe-kill-dev/references/architecture.md`（`include` 与重载边界）、`code-style.md`（存活状态与门面约定）。
- 非目标：文件监视自动触发、前端/RPC 入口、`game` 的动态装载与卸载、会话与 Room 的重载后重建流程（等有消费者再说）。
