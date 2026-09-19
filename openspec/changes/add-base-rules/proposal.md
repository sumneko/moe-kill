# Proposal

## Why

基础设施齐了（内核对象 / 牌区 / 属性 / 随机源 / 时机 / 加载器 / 包路由），但 `package/` 还是空的 —— **一份能开局的基础规则都没有**。这一批交付"能开局"的最小集合：坐次、血量、牌堆，以及身份场（含主公 +1 血）。

## What Changes

- 规则集执行环境**只注入 `rule`**（MUST NOT 注入内核门面 `core`）：规则包不许直接调内核，需要的能力由规则层收口 —— `rule:createAttributeSystem()` / `rule:createCard(name)` / `rule:createZone()` / `rule:createOrderedZone()` 四个最小工厂（用户 2026-09-19 定）。装配方（无头测试；将来的 Room）不受此限，它本来就要组合内核接口开局。
- 内核补两件**最小形状**：
  - `Core.Desk`：入座、座位列表、行动顺序（**按座位号递增**推进，跳过空位与"不参与行动"者）、`desk:getDistance(from, to)`（沿两个方向取较小值、**最小为 1**、每次当场求值不缓存）。
  - `Core.Player`：一个属性实例（`Core.Attributes`）+ 若干**可增删**的牌区 + **不透明标签** + 「参与行动」标记。
- 新增规则包：
  - `package/基础/`：规则数值配置（默认体力上限 4、主公加成 1…）、体力 / 体力上限属性定义与初值、牌堆机制（注册「游戏开始」：按牌表建牌实例 → 放入有序牌区 → 用注入的随机源洗牌）。
  - `package/身份场/`：人数 → 身份配置表（4~8）、注册「游戏开始」分配身份并写进玩家标签、主公体力上限 +1、主公坐 1 号位（于是首回合由主公开始）。
  - `package/标准/`：标准版牌表（每种牌的**张数**；花色点数留到需要判定 / 拼点时再加）—— 数据在规则集里，内核不认识任何牌名。
- 规则数值落地为显性接口：`rule:setValue(名字, 值)` / `rule:setValues { ... }` / `rule:getValue(名字)` / `rule:getValues()`（全局一张表、按加载顺序后者覆盖前者、随清空重载清空）。
- **开局装配不进内核**：装配 = 调用方（无头测试；将来的 Room）组合内核接口 + `rule:fire('游戏-开始', ctx)`，本批用测试驱动一次 8 人完整开局作为验收。
- **时机名改成带分类的写法**（用户 2026-09-19 定）：`分类-动作`，例如 `游戏-开始`、`回合-开始`（已有的测试与文档同步改名）。
- **事件参数写成 meta**（新）：新增分析器用的 meta 文件，把每个时机的上下文类型（`Rule.EventCtx.<事件名去连字符>`）与 `rule:on` / `rule:fire` 的调用签名声明出来，于是规则集里注册回调时能推断 `ctx` 的类型（纯类型声明，不带运行时行为）。

## Capabilities

### New Capabilities

- `core-desk`: 座位、行动顺序、座位距离求值。
- `core-player`: 玩家对象（属性实例 / 牌区 / 标签 / 参与行动标记）。
- `base-rules`: 规则数值、体力属性与初值、牌堆构建与洗牌。
- `identity-mode`: 人数与身份配置、分配身份与主公加成。

### Modified Capabilities

- `rule-loading`: 新增「规则集执行环境的注入面」需求（`rule` + 标准库白名单；**不给** `core` / `require` / `io` / `os`）。

## Impact

- 内核：新增 `server/core/desk.lua`、`server/core/player.lua`，`core/init.lua` 挂载。
- 门面：`server/rule/init.lua` 增加规则数值接口与四个内核能力工厂（`core` **不进**注入环境）；`server/rule/env-meta.lua` 只声明 `rule` 这个注入全局。
- 新增目录（仓库根，与 `server/` 平级）：`package/基础/`、`package/身份场/`、`package/标准/`。
- 测试：`server/test/core/desk.lua`、`server/test/core/player.lua`、`server/test/rule/base.lua`、`server/test/rule/identity.lua`、`server/test/rule/setup.lua`（8 人开局组合场景）。
- 前置：`add-rule-loader-extras`（互斥 / 预解析）不阻塞本批，但同期落地用于拦住"身份场 + 国战"这类组合。
