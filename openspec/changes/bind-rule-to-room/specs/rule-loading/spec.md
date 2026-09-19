# Spec Delta

## MODIFIED Requirements

### Requirement: 清单驱动加载

规则**实例** SHALL 接受一个**加载清单**并按清单顺序依次加载；清单项是**逻辑路径**（见 `package-vfs`），解析为文件时直接加载该文件，解析为目录时加载该目录（含子目录）下的所有文件。加载方式是**读取文件内容并执行**，MUST NOT 通过模块加载器（`require`）—— 因此被加载的规则集 MUST NOT 参与热重载。同一轮加载中同一个文件被重复引用时 SHALL 只执行一次；同一逻辑路径在多个来源中都存在时，SHALL 只执行生效版本（最后一个来源的那个文件）。加载完成后 SHALL 能读回**实际被执行的文件**（逻辑路径，按执行完成的顺序）。

#### Scenario: 按清单顺序加载

- **WHEN** 传入一个包含多个文件与至少一个目录的清单并触发加载
- **THEN** 清单里的文件都被执行，顺序与清单一致，且目录项展开了该目录下的所有文件

#### Scenario: 不通过模块加载器

- **WHEN** 通过加载器加载一个文件，并检查可重载模块的登记集合与模块缓存
- **THEN** 该文件不出现在两者中（它不参与热重载）

#### Scenario: 同一文件只执行一次

- **WHEN** 清单里同一个文件被两次引用（或同时被清单与依赖声明引用）
- **THEN** 本轮加载中它只被执行一次

#### Scenario: 跨来源时只执行生效版本

- **WHEN** 清单项的同一个逻辑路径在两个来源里都存在
- **THEN** 只执行后一个来源的那个文件，前一个来源的同路径文件不执行

### Requirement: 规则集执行环境的注入面

规则集文件 SHALL 在**注入的执行环境**里看到且只看到：`rule`（**正在加载的那个规则实例**）与一份**标准库白名单**。`moe`（含 `moe.core` 之类的中间层）、`require`、`io`、`os` 一类 MUST NOT 被提供 —— 规则包不许直接调内核，也不可能开文件 / 起进程，也不该依赖项目内部的其它全局（`moe.util`、`moe.server` 等）。规则包需要的内核资源 SHALL 经规则实例取得：**属性系统**由该实例持有（`rule:getAttributeSystem()`，包的 `define` 写在加载期），**一局的牌区与牌**由场地提供（`ctx.room`，见 `core-room`）；MUST NOT 由包自己构造内核对象。规则集文件里 SHALL 可以使用中文标识符。

#### Scenario: 规则集里能建对象

- **WHEN** 规则集文件里调用 `rule:getAttributeSystem()` 并在其上 `define` 属性
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

## ADDED Requirements

### Requirement: 规则实例

规则加载器 SHALL 以**实例**为单位工作：`moe.rule.create { sources?, packages? }` SHALL 建出一份规则实例；给了 `packages` 就 SHALL 立刻按它加载（连同自动加载的默认包，见「默认加载的包」），没给则 SHALL 建出一份空实例（可稍后 `rule:load(清单)` 加载）。来源省略时 SHALL 用默认来源。

规则表、包的加载顺序、包元信息、规则数值、时机注册与属性系统 SHALL **全部属于该实例**；实例之间 MUST NOT 共享任何可变状态（常量与默认值除外）—— 因此改一份实例的规则（含清空重载、换来源、重设数值）MUST NOT 影响别的实例。实例上的查询与登记接口（`rule:getCard` / `rule:getValue` / `rule:on` / `rule:fire` / `rule:getAttributeSystem` / `rule:getPackageMeta` …）SHALL 与单例时代的同名接口语义一致。

加载期入口 `rule.card '名字'` 与 `rule.depends { ... }` SHALL 仍然以**点号**调用可用，且 SHALL 作用于**正在加载的那个实例**。

#### Scenario: 建实例即装规则

- **WHEN** 建一个规则实例并在建的同时给出加载清单
- **THEN** 实例上能立刻查到清单里定义的条目，且能读回实际执行过的文件

#### Scenario: 两个实例互不影响

- **WHEN** 建两个规则实例，分别加载不同清单，并对其中一个清空重载
- **THEN** 两者的规则表、规则数值、时机注册与属性系统互不影响（重载过的那份变了，另一份照旧）

#### Scenario: 点号入口作用在正在加载的实例上

- **WHEN** 规则集文件里用 `rule.card '名字'` 声明定义、用 `rule.depends { ... }` 声明依赖
- **THEN** 两者都作用在本次加载的那个实例上（写法与单例时代完全一致）
