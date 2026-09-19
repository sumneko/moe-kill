# Proposal

## Why

`rule` 这个类一身两职：**装载器**（读文件、执行、依赖、包路由）与**一局的内容状态**（规则表 / 数值 / 时机 / 属性系统）。两者生命周期完全不同 —— 装载器是工具，内容状态属于「这一局」。现状的后果：

- `rule` 与 `room` 必须**互指**才能凑齐一局（包要场地得写 `rule.room`，装配方要规则得写 `room:getRule()`）；刚加的 `rule.room` 立刻显得多余。
- `depends` 是**加载期指令**，却挂在「一局的对象」上，位置不对。

## What Changes

- **删掉 `rule` 类**，拆成两样东西：
  - `moe.loader`（`server/core/loader/`，**无状态模块**）：只负责加载 —— 包来源合并（vfs）、试跑（preparse）、执行、依赖 / 互斥、包内作用域、包元信息；入口 `moe.loader.install(game, { sources?, packages? })`，返回本次执行过的文件列表。
  - `moe.game`（`server/core/game.lua`，`Moe.Game` 类）：**一局** —— 吃掉现在的 `room` 与规则内容状态：桌子、随机源、公共牌区 + 规则表 / 包顺序 / 包元信息 / 规则数值 / 时机注册 / 属性系统。`moe.game.create { desk, random, sources?, packages? }` 建局并顺手把规则装好（省略清单 = 只装默认包，口径不变）。
- **注入环境改成 `game` + `Card` + `Depends` + 标准库白名单**：`Card '杀'` 声明内容定义（返回可链式 `:on(...)` 的定义对象），`Depends { '../基础' }` 声明依赖 / 互斥；查询与运行期入口都走 `game`（`game:getCard` / `game:getValue` / `game:on` / `game:fire` / `game:getAttributeSystem` / `game:createZone` / `game:createCard` …）。环境的**函数**用 PascalCase（与 `Class` / `New` 同类，也避免被 `local card = ...` 遮蔽），**对象**小写（`game`，与 `moe` 同类）。
- **门面与类型名跟随**：`moe.game` / `moe.loader`；`Moe.Game`（原 `Moe.Room`）、`Moe.Loader.*`（原 `Moe.Rule.*`）、`Moe.CardDef`（原 `Moe.Rule.Card`）；`moe.loader` 与 `moe.game` 都进热重载集合。
- 规则集侧的其它写法不变（时机名、包路由、默认加载的 `@`、互斥声明都不动）；顺手把注解里的可选标记规范成**写在名字上**（`---@param key? T`）。

## Capabilities

### New Capabilities

- `core-game`：「局」取代 `core-room` 的「场地」—— 除桌子 / 随机源 / 牌区外，SHALL 还持有**这一局的规则内容**。

### Modified Capabilities

- `kernel-facade`：门面清单变成 `moe.game` / `moe.loader`；类型名 `Moe.Game` / `Moe.Loader.*`。
- `rule-loading`：注入面改成 `game` + `Card` + `Depends`；「规则实例」不再是概念（规则内容属于局、装载器无状态）—— 该条 REMOVE，另 ADD「局持有规则内容与装载器入口」；「规则定义入口」与两处依赖写法同步。
- `game-events`：注册与触发入口从 `rule:on` / `rule:fire` 改成 `game:on` / `game:fire`。
- `base-rules`：规则数值、属性系统与牌堆的归属表述改成「局」（`game:getValue` / `game:getAttributeSystem` / `game:createZone`）。
- `hot-reload`：跨重载存活的不再叫「规则实例」，而是**局**（装载器可重载，重载后已建好的局照常可用）。
- `core-room`：能力被 `core-game` 取代 —— 两条需求 REMOVE（见 deltas 的 Reason / Migration）。

## Impact

- 内核：新增 `server/core/loader/{init,vfs,preparse,env-meta}.lua` 与 `server/core/game.lua`；删除 `server/core/rule/` 与 `server/core/room.lua`；`server/core/init.lua` 挂 `moe.loader` / `moe.game`。
- 规则包：`package/**` 六个文件改写法（`rule:X` → `game:X`、`rule.card` → `Card`、`rule.depends` → `Depends`、`rule.room` → `game`）。
- 测试：`server/test/core/room.lua` → `server/test/core/game.lua`（套件 `core.room` → `core.game`）、`server/test/rule/**`（建局代替建规则实例、脚本改名）、`server/test.lua` 注册表；顺手规范化 26 处类型侧可选注解（`server/tools/` 照搬文件不动）。
- 文档：`architecture.md` 第 1 / 8 / 9 / 10 / 11 节、`moe-kill-dev/SKILL.md` 目录表、`infrastructure.md`（套件名）、`sanguosha-rules`（§8 / §9.1 示例）、`AGENTS.md`。
