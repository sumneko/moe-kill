# Spec Delta

## MODIFIED Requirements

### Requirement: 玩家对象

玩家 SHALL 持有：一个属性实例（`Core.Attributes`）、若干**可增删**的牌区、**不透明标签**（写入即存、读取原样返回，内核 MUST NOT 解释其含义或取值）、以及一个「参与行动」标记（供行动顺序跳过）。属性名、牌区名与标签键 MUST NOT 被内核预设。

玩家 SHALL 提供属性读写的**直接入口**：`setAttr(名字, 值)`、`getAttr(名字)`、`addAttr(名字, 增减)`，其语义 SHALL 与 `getAttributes()` 拿到的属性实例上的同名操作一致（同一份数据，不是副本）。

#### Scenario: 持有属性实例

- **WHEN** 用某个属性系统创建玩家并写入 `体力上限`
- **THEN** 该玩家读得到这个值，且不同玩家的属性互不影响

#### Scenario: 属性读写代理

- **WHEN** 用 `setAttr` / `addAttr` 写玩家的属性，再用 `getAttr` 或 `getAttributes():get` 读回
- **THEN** 两条路读到同一个值（代理与属性实例是同一份数据）

#### Scenario: 牌区可增删

- **WHEN** 给玩家加两个牌区再移除其中一个
- **THEN** 列举牌区时只剩一个，且它们的名字是创建时给的名字

#### Scenario: 标签原样存取

- **WHEN** 给玩家写入标签 `身份` = 某个值再读回来
- **THEN** 读到的就是写入的值（内核不校验、不转换）

#### Scenario: 参与行动标记可置位与清除

- **WHEN** 清除某个玩家的「参与行动」标记
- **THEN** 行动顺序推进时跳过该玩家；重新置位后又会被排进去
