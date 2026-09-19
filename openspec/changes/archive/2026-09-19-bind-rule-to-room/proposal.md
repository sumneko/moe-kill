# Proposal

## Why

`moe.rule` 现在是**进程级单例**（`server/moe-kill.lua` 里 `require 'rule'` 挂上；规则表、包顺序、包元信息、规则数值、时机注册、属性系统全在模块表上）：一次加载决定全局 —— 两个房间不可能跑不同规则，改一次规则影响所有房间。但「装哪套规则」本质上是**一局游戏**的事，房间才是那条边界。

顺手有两处冗余要一起收掉：内核的门面要经 `moe.core.*` 这层多余前缀访问；规则加载器自成一「层」（`server/rule/`），却既依赖内核、又被内核侧的场地使用（分层图上其实是同一个东西）。

## What Changes

- **门面拍平**：内核模块组（含规则加载器）各自**直接挂在 `moe` 上**（`moe.card` / `moe.desk` / `moe.room` / `moe.rule` …），删掉 `moe.core` 中间层；类名与类型注解前缀 `Core.*` → `Moe.*`、`Rule.*` → `Moe.Rule.*`。
- **规则加载器挪进内核模块组**：`server/rule/*` → `server/core/rule/*`（模块名 `core.rule*`），并**进入热重载集合**（开发期改加载器代码不用重启）。
- **`moe.rule` 从单例门面变成类**：`moe.rule.create { sources?, packages? }` 建一份**规则实例**；规则表、包顺序、包元信息、规则数值、时机注册、属性系统全部**落在实例上**；给了 `packages` 就立刻加载，没给则建出一份空实例（可稍后 `rule:load(清单)`）。
- **房间自建规则**：`room.create { desk, random, sources?, packages? }` 在建场地时把规则实例建出来并装好，场地提供 `getRule()` 读回 —— **改规则是该场地自己的事**，不影响别的场地。
- **规则集侧的写法不变**：注入的 `rule` 就是本轮加载的那个实例；`rule.card '杀'` / `rule.depends { ... }` 仍是**点号**调用（实例上绑好），`rule:on` / `rule:setValue` 等仍是冒号调用。

## Capabilities

### New Capabilities

- `kernel-facade`：内核门面的落点与命名 —— 模块直接挂在 `moe` 下、没有 `moe.core` 中间层、类型统一 `Moe.` 前缀。

### Modified Capabilities

- `rule-loading`：新增「规则实例」（建实例即装规则、实例之间互不影响）；「清单驱动加载」与「规则集执行环境的注入面」改为实例语义。
- `core-room`：「场地对象」—— 建场地时给来源与清单，规则由场地自己装好并读回。
- `base-rules`：「体力属性与初值」—— 属性系统由**该场地的规则实例**持有（一局一份）。
- `hot-reload`：「重载后已存在的实例立即使用新代码」—— 规则实例同样适用。

## Impact

- 内核：`server/core/init.lua`（门面拍平）、`server/core/room.lua`（收 `sources` / `packages`、`getRule`）、`server/core/*.lua`（类型前缀改名）。
- 规则：`server/rule/{init,vfs,preparse,env-meta}.lua` → `server/core/rule/*`；`init.lua` 改造成 `Moe.Rule` 类（状态全部实例化）。
- 入口：`server/moe-kill.lua`（不再挂 `moe.core`）。
- 测试：`server/test/core/*`（`moe.core.X` → `moe.X`）、`server/test/rule/*`（全局单例 → 按用例建实例）、`server/test/rule/support.lua`（辅助改成建场地与实例）。
- 文档：`architecture.md`（第 1 / 8 / 9 / 10 / 11 节）、`code-style.md`、`infrastructure.md`、`moe-kill-dev/SKILL.md`、`sanguosha-rules/SKILL.md`、`AGENTS.md`。
- 规则包（`package/*`）**不改**：它们只看见注入的 `rule` 与 `ctx.room`，两者形状都没变。
