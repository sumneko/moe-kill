# Design

## 背景

现状：`moe.rule` 是挂在门面上的**单例**（`server/moe-kill.lua` 里 `require 'rule'`），所有状态都是模块级字段（`M.cards` / `M.values` / `M.events` / `M.meta` / `M.__attributeSystem`）；`server/rule/` 自成一「层」，却要用 `moe.core.*` 拿内核能力；场地（`server/core/room.lua`）只持有桌子、随机源与牌区，与规则毫无关系。

## D1 为什么把 `moe.core` 拍平掉

`moe.core` 只提供了一层前缀，没有承担任何隔离职责（它不是沙箱边界，导入面靠注入 `rule` 达成；它不是加载边界，内核模块一直是 `include` 的）。拍平后「内核」是**目录**（`server/core/`）与**模块组**的概念，而不是命名空间 —— 于是规则加载器搬进 `server/core/rule/` 后，访问它不需要「跨层」的说明，`moe.rule` 与 `moe.room` 平级。

类型名同理：`Core.*` 会让人以为运行时存在 `core` 命名空间，统一改成 `Moe.*`；规则加载器内部类型从 `Rule.*` 改成 `Moe.Rule.*`。

## D2 为什么是「房间自建规则」而不是「装配方注入实例」

- 用户口径：**规则是一局游戏的东西**，建房间的时候才决定装哪套规则，改规则也只影响这一个房间。
- 用户否掉了「注入」：注入的话建房间与装规则是两步，装配方要自己串；而且让 `Room` 只当个储物柜没有意义。
- 分层也不再是问题：拍平后 `Room` 与 `Rule` 同在内核模块组里，`core/room.lua` 调用 `moe.rule.create` 不构成反向依赖 —— 原来的「package → rule → core」这条链，现在是「package → `moe`（内核模块组）」。

## D3 哪些状态落在实例上

| 状态 | 单例时代 | 现在 |
| ---- | ---- | ---- |
| 规则表（包名 → 裸名 → 定义） | `M.cards` | 实例字段 |
| 包的加载顺序 | `M.packages` | 实例字段 |
| 包元信息 | `M.meta` | 实例字段 |
| 规则数值 | `M.values` | 实例字段 |
| 时机注册 | `M.events` | 实例字段（每次 `load` 重置） |
| 属性系统 | `M.__attributeSystem` | 实例字段（每次 `load` 重建） |
| 来源列表 | `M.sources` | 实例字段（默认 `{'./package/*'}`） |
| 上次清单 | `M.lastList` | 实例字段（`load()` 不带参时复用） |
| 加载上下文 | `M.context` | 实例私有字段（仅加载期） |
| `DEFAULT_SOURCES` | 模块字段 | 仍是模块字段（**常量**，可共享） |

原则不变：**实例之间 MUST NOT 共享可变状态**；常量与默认值放模块表上。

## D4 `rule.card` / `rule.depends` 为什么还能点号调

这两个是**加载期入口**，用户给定的写法是点号（`rule.card '杀'`、`rule.depends { ... }`），要求保持不变。做法：`create` 时在实例上绑两个闭包

```lua
self.card    = function (name) return M.card(self, name) end
self.depends = function (items) return M.depends(self, items) end
```

- 闭包的 upvalue 是**类表**（`Class` 合并语义下重载复用同一个表）⇒ 热重载后这两个入口自动执行新代码。
- 其余入口（`load` / `getCard` / `setValue` / `on` / `fire` / `getAttributeSystem` / `getPackageMeta` …）都是实例方法，冒号调用。
- 预解析的 stub 环境照旧只需要 `card` 与 `depends` 两个函数，签名（接收裸名字 / 字符串列表）不变。

## D5 热重载：加载器进集合、实例不丢

- `server/core/rule/*` 全部走 `include`（`core/init.lua` 里与其它内核模块一样 `includeCore`）⇒ 改加载器 / 词法层代码不用重启进程。
- 规则实例挂在**房间**上，房间不被重载 ⇒ 重载后实例照常可用，`Class` 合并语义保证老实例立即可用新代码（与既有 `hot-reload` 契约一致）。
- `env-meta.lua` 是**纯类型文件**（`---@meta`），不进重载集合，也不被 `include`（它没有运行期内容，只被语言服务器读）。

## D6 预解析与 stub 环境

试跑（`preparse.run`）用的 stub `rule` 由 `prepare(instance, items)` 就地构造，闭包捕获 `self`（实例）与本次加载的 `ctx` ⇒ 试跑天然是**实例级**的，不会污染别的实例。`without-check-nil` 仍是进程全局开关，必须成对开关（不变）。

## D7 属性系统是一局一份

属性系统跟着规则实例走（实例的 `load` 清空重载时重建）。于是「一局一份属性定义」成立：装配方从 `room:getRule():getAttributeSystem()` 取实例化玩家属性；两个房间的属性定义互不干扰。

## D8 `sources` 是实例级配置

包来源属于「这一局装了哪些包」的一部分，因此放在实例上（`create { sources }`），默认 `{ './package/*' }`；`setRoots` / `getRoots` 保留为实例方法（换来源后重新 `load`）。这是与单例时代**语义相同、只是换了持有者**的一处。

## 被否掉的方案

- **只把 `rule` 实例挂到房间、其余保持单例**：`moe.rule` 仍是全局状态，两个房间还是会互相踩。
- **让装配方建实例再注入 `room.create { rule }`**：用户否掉（见 D2）。
- **保留 `moe.core` 作为兼容别名**：同一份东西两个入口，文档与测试会出现两套写法，得不偿失。
