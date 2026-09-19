# Spec Delta

## ADDED Requirements

### Requirement: 内核门面的落点与命名

内核模块组（`server/core/` 下的各模块，**含规则加载器**）SHALL 各自**直接挂在 `moe` 上**：`moe.card` / `moe.zone` / `moe.orderedZone` / `moe.random` / `moe.attribute` / `moe.event` / `moe.desk` / `moe.player` / `moe.room` / `moe.rule`。系统 MUST NOT 提供 `moe.core` 这类中间层命名空间。内核的类型名（类名与注解）SHALL 统一用 `Moe.` 前缀（如 `Moe.Desk`、`Moe.Room`、`Moe.Rule`），MUST NOT 再使用 `Core.` / `Rule.` 前缀。

#### Scenario: 模块直接挂在 moe 下

- **WHEN** 取内核的任一模块（牌 / 牌区 / 有序牌区 / 随机源 / 属性 / 时机 / 桌子 / 玩家 / 场地 / 规则）
- **THEN** 它就在 `moe` 下的同名名字上，并且 `moe.core` 不存在

#### Scenario: 规则加载器与其它内核模块平级

- **WHEN** 从门面取规则加载器
- **THEN** 拿到的是 `moe.rule`（内核模块组的一员，与 `moe.room`、`moe.desk` 同处一层，多套不出「规则是一层、内核又是一层」的说法）
