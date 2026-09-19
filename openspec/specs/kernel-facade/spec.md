# kernel-facade Specification

## Purpose
约定内核模块组的**门面落点与命名**：每个内核模块各自**直接挂在全局 `moe` 上**（`moe.card` / `moe.desk` / `moe.game` / `moe.loader` …），不设 `moe.core` 这类中间层；类名与类型注解直接用类名本身，不带命名空间前缀。于是装配方只有一个命名层级，装载器与其它内核模块平级，规则包只拿注入的 `game` 与 `Card` / `Depends`。

## Requirements

### Requirement: 内核门面的落点与命名

内核模块组（`server/core/` 下的各模块，**含装载器**）SHALL 各自**直接挂在 `moe` 上**：`moe.card` / `moe.zone` / `moe.orderedZone` / `moe.random` / `moe.attribute` / `moe.event` / `moe.desk` / `moe.player` / `moe.game` / `moe.loader`。系统 MUST NOT 提供 `moe.core` 这类中间层命名空间。内核的类型名（类名与注解）SHALL 统一用 `Moe.` 前缀（如 `Moe.Desk`、`Moe.Game`、`Moe.Loader`），MUST NOT 再使用 `Core.` / `Rule.` 前缀。

#### Scenario: 模块直接挂在 moe 下

- **WHEN** 取内核的任一模块（牌 / 牌区 / 有序牌区 / 随机源 / 属性 / 时机 / 桌子 / 玩家 / 局 / 装载器）
- **THEN** 它就在 `moe` 下的同名名字上，并且 `moe.core` 不存在

#### Scenario: 规则加载器与其它内核模块平级

- **WHEN** 从门面取装载器
- **THEN** 拿到的是 `moe.loader`（内核模块组的一员，与 `moe.game`、`moe.desk` 同处一层，多套不出「规则是一层、内核又是一层」的说法）
