# Spec Delta

## MODIFIED Requirements

### Requirement: 规则集执行环境的注入面

规则集文件 SHALL 在**注入的执行环境**里看到且只看到：**这一局的局对象**（`game`）、加载期入口 `Card` / `Depends`、一份**收窄的纯函数工具集**（`util`），以及一份**标准库白名单**。`util` SHALL 只含**纯函数**（不读写文件、不起进程、不碰时间与环境），MUST NOT 是内核工具库本体（那个里面还有读写文件之类的副作用能力）；它提供的函数清单 SHALL 以类型文件（`server/core/loader/env-meta.lua`）为准。

`moe`（含 `moe.core` 之类的中间层）、`require`、`io`、`os` 一类 MUST NOT 被提供 —— 规则包不许直接调内核，也不可能开文件 / 起进程，也不该依赖项目内部的其它全局（`moe.util`、`moe.server` 等）。规则包需要的内核资源 SHALL 全部经**局对象**取得：**属性系统**由局持有（`game:getAttributeSystem()`，包的 `define` 写在加载期）、**牌区与牌**由局提供（`game:createZone` / `game:createCard`）、规则数值与时机注册也在局上（`game:setValue` / `game:on` …）；MUST NOT 由包自己构造内核对象。**环境的函数用大写开头**（`Card` / `Depends`，与 `Class` / `New` 这类框架入口同类），**对象小写**（`game` / `util`）。规则集文件里 SHALL 可以使用中文标识符。

时机上下文 SHALL 只承载**该时机的事件参数**：没有额外参数的事件（如 `'游戏-开始'`）传的就是**空表**。规则包 MUST NOT 指望上下文里出现环境对象（局 / 桌子 / 随机源）—— 这些要从 `game` 取。

#### Scenario: 规则集里能建对象

- **WHEN** 规则集文件里调用 `game:getAttributeSystem()` 并在其上 `define` 属性
- **THEN** 调用成功，装配方之后能用同一个属性系统给玩家建属性实例

#### Scenario: 拿不到内核门面

- **WHEN** 规则集文件里使用 `moe` 或 `core`
- **THEN** 以错误结束（两者都不在注入面里）

#### Scenario: 拿不到 require 与 io

- **WHEN** 规则集文件里使用 `require` 或 `io`
- **THEN** 以错误结束（它们不在注入面里）

#### Scenario: 规则集里可以写中文标识符

- **WHEN** 规则集文件里声明中文变量、函数名或表键
- **THEN** 解析与执行都正常

#### Scenario: 环境对象从实例取，上下文只装事件参数

- **WHEN** 规则包在「游戏-开始」的回调里要这一局的场地（例如建抽牌堆），而触发时传的上下文是空表
- **THEN** 它读 `game`（`game:createZone` / `game.desk` / `game.random`）拿到需要的对象，回调照常完成（不依赖上下文里有什么环境字段）

#### Scenario: 规则集里能用工具集

- **WHEN** 规则集文件里用 `util` 的函数按条件筛一个列表（例如筛出可达的角色）
- **THEN** 拿到筛选后的列表，结果与手写循环一致

#### Scenario: 工具集里只有纯函数

- **WHEN** 看 `util` 里提供的东西
- **THEN** 都是纯函数；读写文件 / 起进程 / 打日志这类副作用能力不在里面（也因此拿不到）
