# Design

## Context

- **现在的实现**（`server/core/game.lua`）：`CardDef` 持 `kinds`（数组，按声明顺序）与 `kindSet`（去重用的集合），`kind(name)` 里 `if not kindSet[name] then 追加`；`isKind` 查集合、`getKinds` 给快照。
- **`extends` 的抄法**：`for _, kind in ipairs(base.kinds) do self:kind(kind) end` —— 因为 `kind` 是累加的，抄过来就等于**基类分类 + 子定义自己的分类**。
- **用例钉住的旧口径**：`server/test/core/card-def.lua` 里「同名只算一次」「分类累积（extends + 自己的 kind）」两条。
- **即将到来的用法**（用户 2026-09-23 给的目标形状）：非延时锦囊 `: kind { '锦囊', '非延时锦囊' }`、延时锦囊 `: kind { '锦囊', '延时锦囊' }`。

## Goals / Non-Goals

**Goals:**

- 一次调用就能把分类**说清楚**（给一张列表 = 就是这几类），不再依赖「重复调几次」来表达多分类。
- 重复调有确定语义：**后写的为准**（与 `limit` / `zone` 的「重复调以后写的为准」一致 —— 定义上的字段本来就都是这个口径）。
- `extends` 的抄分类与新口径一致。
- `isKind` / `getKinds` 对调用方零变化（谁在读分类的代码一行不改）。

**Non-Goals:**

- 分类名的取值校验 / 枚举（内核仍然只记录、不解释）。
- `zone` / `limit` / 钩子（`on`）的形状调整 —— `on` 是**累加**的（追加回调），那是另一码事（同一事件多个钩子是真实需求）。
- 拼点、装备分类这些消费者（各自另开变更）。

## Decisions

### D1 `kind(名字)`：入参 `string | string[]`，一次调用覆盖

```lua
--- 声明这张牌的分类（一次调用就把分类定下来；重复调以后写的为准；要多个就给一张列表）
---@param name string|string[] # 分类名（内核不解释取值）
---@return CardDef
function CardDef:kind(name)
    ---@type string[]
    local list
    if Type(name) ~= nil then
        ---@cast name string[]
        list = name
    else
        ---@cast name string
        list = { name }
    end
    self.kinds   = {}
    self.kindSet = {}
    for _, item in ipairs(list) do
        if not self.kindSet[item] then
            self.kindSet[item] = true
            self.kinds[#self.kinds + 1] = item
        end
    end
    return self
end
```

- **单值 / 列表的判别用 `Type(x) ~= nil`**：项目里已有的写法（`game.lua` 的 `toPlayerList` 判「单个还是列表」、`card.lua` 的 `toTargetList` 都是它）；`Type` 对**非表**返回 `nil` ⇒ 字符串落到「包成一张表」那一支。
- **列表内去重**（`{ 'A', 'A' }` 只算一次）、**顺序按列表**（`getKinds()` 的顺序稳定，用例可以断字符串）。
- **`kinds` / `kindSet` 直接换新表**（不是原地清空）：`getKinds()` 给的是快照，谁也不会持有内部表 ⇒ 换表最省事。

### D2 `extends` 抄分类：有则覆盖，没则不动

```lua
if #base.kinds > 0 then
    self:kind(base.kinds)
end
```

- 与 `zone` / `limit` 的「有才抄」同一口径（基类没声明就不拿空值去覆盖子定义）。
- **为什么不是「无条件覆盖」**：那会让「基类没分类」的子定义反而被清空 —— 继承不该有破坏性副作用。
- **顺序语义**（谁先谁后）：`extends` 之后写 `: kind` ⇒ 子定义的分类生效；`: kind` 之后写 `: extends` ⇒ 基类的分类生效。两条都是「后写的为准」，与其它字段一致（`Card '杀' : extends '基本牌'` 这种常规写法不受影响）。

### D3 `isKind` / `getKinds` 不动

读法形状不变（`getKinds()` 仍是快照、按声明顺序）⇒ 已有调用点（`core.game.lua` 的 `canUse`、用例、将来的锦囊判定）零改动。

### D4 用法示例（下一批直接用）

```lua
Card '基本牌' : kind '基本' : zone '手牌'          -- 单值：一张牌一类
Card '乐不思蜀' : kind { '锦囊', '延时锦囊' }        -- 列表：一张牌多类（同属「锦囊」，但走判定区）
Card '无中生有' : kind { '锦囊', '非延时锦囊' }
```

**备选（否）**：① 保留累加、另加一个 `setKinds(列表)` —— 两套接口、还得记哪个是哪个；② 只接受列表（连单值也要写成 `{ '基本' }`）—— 基本牌那边太啰嗦，且现有多处单值调用要全改。
