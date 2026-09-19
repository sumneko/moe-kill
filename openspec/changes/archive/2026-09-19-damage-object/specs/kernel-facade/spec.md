# Spec Delta

## MODIFIED Requirements

### Requirement: 内核门面的落点与命名

内核模块组（`server/core/` 下的各模块，**含装载器**）SHALL 各自**直接挂在 `moe` 上**：`moe.card` / `moe.zone` / `moe.orderedZone` / `moe.random` / `moe.attribute` / `moe.event` / `moe.desk` / `moe.player` / `moe.game` / `moe.damage` / `moe.loader`。系统 MUST NOT 提供 `moe.core` 这类中间层命名空间。内核的类名（`Class 'X'` 登记的名字与 `---@class` 注解）SHALL 直接用**类名本身**（如 `Desk`、`Game`、`Damage`、`Loader`），同一类下的从属类型 SHALL 写成「类名.子名」（如 `Loader.Context`、`Game.EventCtx.游戏开始`、`Damage.CreateOptions`）；MUST NOT 加 `Moe.` / `Core.` / `Rule.` 这类命名空间前缀，也 MUST NOT 用别的前缀替代它。

#### Scenario: 模块直接挂在 moe 下

- **WHEN** 取内核的任一模块（牌 / 牌区 / 有序牌区 / 随机源 / 属性 / 时机 / 桌子 / 玩家 / 局 / 伤害 / 装载器）
- **THEN** 它就在 `moe` 下的同名名字上，并且 `moe.core` 不存在

#### Scenario: 规则加载器与其它内核模块平级

- **WHEN** 从门面取装载器
- **THEN** 拿到的是 `moe.loader`（内核模块组的一员，与 `moe.game`、`moe.desk` 同处一层，多套不出「规则是一层、内核又是一层」的说法）

#### Scenario: 类型名不带命名空间前缀

- **WHEN** 看内核任一类的类型注解
- **THEN** 它就是类名本身（`Desk` / `Game` / `Damage` / `Loader`），从属类型是「类名.子名」（如 `Loader.Context`），没有任何命名空间前缀
