# Proposal

## Why

基础设施齐了（内核对象 / 牌区 / 属性 / 随机源 / 时机 / 加载器 / 包路由），但 `package/` 还是空的 —— **一份能开局的基础规则都没有**。这一批交付"能开局"的最小集合：坐次、血量、牌堆，以及身份场（含主公 +1 血）。

## What Changes

- 规则集执行环境增加**内核门面** `core`（与 `rule` 并列注入）：规则集要建玩家 / 牌区 / 牌 / 属性 / 随机源，必须能调内核 —— 依赖方向本来就是 `package/ → server/core`。
- 内核补两件**最小形状**：
  - `Core.Desk`：入座、座位列表、行动顺序（**按座位号递增**推进，跳过空位与"不参与行动"者）、`desk:getDistance(from, to)`（沿两个方向取较小值、**最小为 1**、每次当场求值不缓存）。
  - `Core.Player`：一个属性实例（`Core.Attributes`）+ 若干**可增删**的牌区 + **不透明标签** + 「参与行动」标记。
- 新增规则包：
  - `package/基础/`：规则数值配置（默认体力上限 4、主公加成 1…）、体力 / 体力上限属性定义与初值、牌堆机制（注册「游戏开始」：按牌表建牌实例 → 放入有序牌区 → 用注入的随机源洗牌）。
  - `package/身份场/`：人数 → 身份配置表（4~8）、注册「游戏开始」分配身份并写进玩家标签、主公体力上限 +1、主公坐 1 号位（于是首回合由主公开始）。
  - `package/标准/`：标准版牌表（每种牌的**张数与花色点数**）—— 数据在规则集里，内核不认识任何牌名。
- 规则数值落地为显性接口：`rule:setValue(名字, 值)` / `rule:setValues { ... }` / `rule:getValue(名字)` / `rule:getValues()`（全局一张表、按加载顺序后者覆盖前者、随清空重载清空）。
- **开局装配不进内核**：装配 = 调用方（无头测试；将来的 Room）组合内核接口 + `rule:fire('游戏开始', ctx)`，本批用测试驱动一次 8 人完整开局作为验收。

## Capabilities

### New Capabilities

- `core-desk`: 座位、行动顺序、座位距离求值。
- `core-player`: 玩家对象（属性实例 / 牌区 / 标签 / 参与行动标记）。
- `base-rules`: 规则数值、体力属性与初值、牌堆构建与洗牌。
- `identity-mode`: 人数与身份配置、分配身份与主公加成。

### Modified Capabilities

- `rule-loading`: 新增「规则集执行环境的注入面」需求（`rule` + `core` + 标准库白名单；不给 `require` / `io` / `os`）。

## Impact

- 内核：新增 `server/core/desk.lua`、`server/core/player.lua`，`core/init.lua` 挂载。
- 门面：`server/rule/init.lua` 增加规则数值接口，并把 `core` 加进注入环境。
- 新增目录（仓库根，与 `server/` 平级）：`package/基础/`、`package/身份场/`、`package/标准/`。
- 测试：`server/test/core/desk.lua`、`server/test/core/player.lua`、`server/test/rule/base.lua`、`server/test/rule/identity.lua`、`server/test/rule/setup.lua`（8 人开局组合场景）。
- 前置：`add-rule-loader-extras`（互斥 / 预解析）不阻塞本批，但同期落地用于拦住"身份场 + 国战"这类组合。
