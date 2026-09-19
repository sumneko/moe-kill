# Design

## Context

- 现状：属性系统由规则包在加载期自己建（`rule:createAttributeSystem()`）再塞进规则数值 `属性系统`，装配方从规则数值里取；玩家读属性要 `player:getAttributes():get(...)`。
- 用户口径（2026-09-19）：`rule:getAttributeSystem()`、`player:setAttr(...)`；体力要能降到负数、写值要钳到当前上限。
- 上游已修：`sumneko/utility` 的 `3f347e4` 给 `compileComplex` 的 `getMax` 生成块补了 `local cache = instance.cache`（本批已同步）。

## Goals / Non-Goals

**Goals:**

- 属性系统有明确归属：**规则门面持有**，随规则集清空重载重建。
- 玩家对象上读写属性不必绕 `getAttributes()`。
- 体力的上下界符合三国杀口径（可为负、上限跟随）。

**Non-Goals:**

- **不做**「属性公式 / 百分比修正」的额外封装（属性库已支持，等真有消费者再用）。
- **不做** `getMax` 的上游修复（本批不依赖它；已知限制记进 `infrastructure.md`）。
- **不做**属性的"归属校验"（谁都能改谁都属性由规则层自己保证）。

## Decisions

### D1 属性系统由门面持有（`rule:getAttributeSystem()`）

- 属性系统是**规则集内容**：包的 `define` 写在加载期，装配方在装配时拿它给玩家建实例 ⇒ 生命周期与规则表一致。
- 实现：`M.__attributeSystem`（跨重载存活的数据挂门面表、`__` 前缀的既有约定）按需创建；**`clear()` 里置空**，于是清空重载后下一轮是一个全新的系统。
- 为什么必须重置：属性库**不允许在编译之后再新增属性定义**（报 `Cannot define new attributes after compilation`）；重载后如果复用旧系统，包里的 `define` 会直接报错。
- 顺带撤掉 `属性系统` 这条规则数值（它只是"把系统从包传到装配方"的中转站，现在不需要了）。

### D2 玩家上的属性读写代理

- `player:setAttr / getAttr / addAttr` 直接转发给玩家的属性实例 —— 只是省一层，语义完全一致（同一份数据）。
- 保留 `getAttributes()`：装配方要 `createInstance()`、规则层要做批量遍历时仍然需要它。

### D3 体力可为负、写值钳到上限

- 三国杀的濒死结算需要体力降到 0 以下，所以 `体力` 的**下界是负数**（取 -999999 这种够用的值，而不是"无下界"）。
- `体力` 的**上界写成字符串引用** `'体力上限'` ⇒ 写值会自动钳到当前上限（实测有效；`min`/`max` 用字符串引用在 `simple = true` 下也工作）。
- `体力上限` 自身给 `0..999999`（有实际上下界，避免"无上界"）。
- 注意：**抬上限不会自动加体力**（这正是身份场对主公那句"上限与体力各加一次"仍然必要的原因）。

### D4 属性定义必须在加载期

- 属性库把定义编译成一组生成函数，**编译后不能再 `define`** ⇒ 包的属性定义只能出现在加载期（`@基础/体力.lua` 顶层），MUST NOT 写在「游戏-开始」回调里。
- 这条约束写进规格（`base-rules`）与技能文档，免得后来者把 `define` 挪进运行时。

## Risks / Trade-offs

- [门面持有的属性系统容易被当成"全局单例"乱用] → 它随清空重载重置、只该由规则包 `define`、由装配方 `createInstance`；文档写清这两条。
- [字符串引用的 `max` 依赖属性库行为] → 已实测（钳制 / 负值 / 抬上限不动体力都对），但 `getMax` 在 **simple 路径**上仍会崩（上游未修）⇒ 不依赖它，记成已知限制。
- [体力下界取 -999999 是"够用"而非"数学上的无下界"] → 符合"不要过度防御"的取向：够用即可，真出现更大的负值再调。

## Migration Plan

- 门面：`createAttributeSystem` → `getAttributeSystem`（调用点：`support.lua`、`rule/init.lua` 的探针用例、`@基础/体力.lua`）。
- 包：体力属性定义换成新边界；身份场主公改 `addAttr`。
- 回滚：门面加回 `createAttributeSystem`、把 `属性系统` 规则数值写回、包还原即可。
