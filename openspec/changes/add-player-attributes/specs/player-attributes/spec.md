# player-attributes Specification

## Purpose

玩家属性的对外形状与下行：哪些属性对谁可见、变化怎么通知、快照里长什么样。属性是**内核自己在读**的数据（体力参与濒死判定），所以它不走 `custom`（内容侧自由数据），而是单开一路。

## ADDED Requirements

### Requirement: 逐属性可见性（fail-closed）

每个玩家 SHALL 有一份「属性名 → 可见性」的账本。**没有声明过可见性的属性 MUST NOT 下发 —— 连本人也一样看不见**。

声明 SHALL 通过 `Player:setAttrVisible(name, options)` 完成；`options` SHALL 是通用的可见性值（`true` / `false` / 一名角色 / 角色表 / 谓词）。

属性值**没有变化**但可见性变化时，也 SHALL 视为「这份数据变了」。

#### Scenario: 没声明过就谁都不见

- **WHEN** 玩家的某个属性有值，但没有任何人声明过它的可见性
- **THEN** 谁（含本人）都收不到这个属性

#### Scenario: 声明给所有人

- **WHEN** 内容侧把某个属性声明成公开
- **THEN** 每一名有连接的玩家都能看到这个属性

#### Scenario: 改了可见性会重发

- **WHEN** 某个属性的可见性从「只有本人」改成「所有人」
- **THEN** 别的连接在下一次下发行里收到这个属性（不必等属性值再变）

### Requirement: 属性下行的通知

已声明过可见性的属性，其值变化时 SHALL 触发下行。后端 SHALL 把同一次调度里攒下的变化合并成**一条** `Proto.Notify.Player.UpdateAttribute`，载荷 SHALL 是 `{ players: Proto.Player.Attribute[] }`，其中每项带 `id` 与该收件人**这次看得见的属性数组**（`Proto.Attribute` = `{ name, value }`）。

`attributes` MUST 用数组表达，MUST NOT 用「键 → 值」的映射。

对一个收件人而言**一个属性都看不见**的玩家 MUST 被跳过；**没有连接**（没有 `user`）的玩家 MUST NOT 下发。

#### Scenario: 属性变了会收到通知

- **WHEN** 一名玩家的体力变化，且它的可见性已声明
- **THEN** 有连接的玩家收到一条 `Player.UpdateAttribute`，带这名玩家的 `id` 与 `{ name = '体力', value = … }`

#### Scenario: 一条带一批玩家

- **WHEN** 同一笔调度里多名玩家的属性都变了
- **THEN** 客户端收到**一条**通知，`players` 里带上他们各自的那份

#### Scenario: 看不见的属性不下发

- **WHEN** 某个属性只声明给本人看，而另一名玩家有连接
- **THEN** 发给那名玩家的这条通知里 MUST NOT 出现该属性

#### Scenario: 没有连接的玩家不下发

- **WHEN** 属性变了的玩家身上没有连接
- **THEN** 谁也不收到关于他的这条通知

### Requirement: 快照里的属性

`Game.SnapShot` 的每个 `Proto.Player` SHALL 带 `attributes`：该收件人此刻看得见的属性数组，裁剪口径与增量通知一致。

#### Scenario: 快照带上看得见的属性

- **WHEN** 客户端要一份整局快照
- **THEN** 每个玩家的 `attributes` 都是按这名收件人裁过的（看不见的不出现）
