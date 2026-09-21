# kernel-facade Specification

## Purpose
约定内核模块组的**门面落点与命名**：每个内核模块各自**直接挂在全局 `moe` 上**（`moe.card` / `moe.desk` / `moe.game` / `moe.loader` …），不设 `moe.core` 这类中间层；**门面由模块自己建**（`moe.card = {}`，模块不 `return` API 表）；类名与类型注解直接用类名本身，不带命名空间前缀。于是装配方只有一个命名层级，装载器与其它内核模块平级，规则包只拿注入的 `game` 与 `Card` / `Depends`。

## Requirements

### Requirement: 内核门面的落点与命名

内核模块组（`server/core/` 下的各模块，**含装载器**）SHALL 各自**直接挂在 `moe` 上**：`moe.card` / `moe.zone` / `moe.orderedZone` / `moe.random` / `moe.attribute` / `moe.event` / `moe.desk` / `moe.player` / `moe.game` / `moe.askCard` / `moe.moveCard` / `moe.useCard` / `moe.damage` / `moe.loader`。系统 MUST NOT 提供 `moe.core` 这类中间层命名空间。

**门面 SHALL 由模块自己建**：模块里写 `---@class X.API` + `moe.X = {}`，工厂直接挂在这个字段上（`function moe.X.create(…)`），模块 MUST NOT `return` 自己的 API 表；`server/core/init.lua` SHALL 只 `include` 各模块，MUST NOT 再赋值门面。于是门面由**可重载的模块自己**持有并在重载时重建，`moe.X` 的类型由赋值处的 `---@class` 定下，`server/moe-kill.lua` 的 `MoeKill` 上 MUST NOT 重复声明这些字段。

**类的模块 SHALL 只以 API 表形式对外**：类模块 SHALL 把工厂放在另起的 API 表上（类自己**不放 `create`**），API 表里 SHALL 只有**工厂入口**（`create`），类上与实例上的其余成员 MUST NOT 从全局可达 —— `moe.player.create { … }` 可用，而 `moe.player:getAttr(…)` / `moe.desk.getDistance(a, b)` 这类写法**不存在**（拿到 `nil`，误用当场失败）。API 表的类型 SHALL 写成「类名.API」（`Player.API` / `Desk.API` …）。**没有工厂的类（`Effect` 基类）MUST NOT 建门面**（`moe.effect` 不存在），其类名仍在类注册表里（`Extends('UseCard', 'Effect')` 照旧可用）。装载器同样写 `moe.loader = {}`：它的公开入口就是这张表自己的字段（`install` / `declareDepends` / `DEFAULT_SOURCES`）。

内核的类名（`Class 'X'` 登记的名字与 `---@class` 注解）SHALL 直接用**类名本身**（如 `Desk`、`Game`、`Effect`、`Loader`），同一类下的从属类型 SHALL 写成「类名.子名」（如 `Loader.Context`、`Game.EventCtx.游戏开始`、`Damage.CreateOptions`）；MUST NOT 加 `Moe.` / `Core.` / `Rule.` 这类命名空间前缀，也 MUST NOT 用别的前缀替代它。

#### Scenario: 模块直接挂在 moe 下

- **WHEN** 取内核的任一模块（牌 / 牌区 / 有序牌区 / 随机源 / 属性 / 时机 / 桌子 / 玩家 / 局 / 询问 / 挪牌 / 用牌 / 伤害 / 装载器）
- **THEN** 它就在 `moe` 下的同名名字上，并且 `moe.core` 不存在

#### Scenario: 门面在模块里建，不在 init 里拼

- **WHEN** 看 `server/core/card.lua` 与 `server/core/init.lua`
- **THEN** 卡牌模块里是 `---@class Card.API` + `moe.card = {}` + `function moe.card.create(…)`，没有 `return API`；`server/core/init.lua` 只有 `include 'core.card'` 这样的行，没有任何对 `moe.*` 的赋值

#### Scenario: 规则加载器与其它内核模块平级

- **WHEN** 从门面取装载器
- **THEN** 拿到的是 `moe.loader`（内核模块组的一员，与 `moe.game`、`moe.desk` 同处一层，多套不出「规则是一层、内核又是一层」的说法）

#### Scenario: 类型名不带命名空间前缀

- **WHEN** 看内核任一类的类型注解
- **THEN** 它就是类名本身（`Desk` / `Game` / `Effect` / `Loader`），从属类型是「类名.子名」（如 `Loader.Context`），没有任何命名空间前缀

#### Scenario: 门面里只有工厂

- **WHEN** 看 `moe.player` / `moe.desk` / `moe.game` 上有什么
- **THEN** 只有 `create`：`moe.player.create { attributes = … }` 拿到玩家，而 `moe.player.getAttr`、`moe.desk.getDistance`、`moe.desk.sit` 都不存在（`nil`）

#### Scenario: 没有工厂的类不建门面

- **WHEN** 看 `moe.effect`
- **THEN** 它不存在（`Effect` 是基类、没有工厂，就没有门面）；用牌与伤害仍然通过 `Extends` 继承 `Effect`
