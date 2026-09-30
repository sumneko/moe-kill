# Design

## 为什么放 `身份场` 包，而不是 `@基础` 或内核

身份**只在身份场模式里存在**（规则集 Chapter1 身份场；基础包不含这个概念）—— 放进 `@基础` 或内核就等于宣称「换个规则集也有身份」。

内核更不该有：内核只搬运、不解释取值（`architecture.md` 第 3 节），而身份的取值（`'主公'` / `'反贼'`…）与用途（胜负 / 奖惩）全在内容侧。内核连 `sex` / `kingdom` 都没占字段位，身份同理。

## 形状

```lua
---@class Player
local M = Class 'Player'

--- 给这名角色定下身份
---@param name 身份场.身份
function M:setIdentity(name)
    self.identity = name
end
```

- **写用方法、读用字段**：`setIdentity(name)` 写 `player.identity`，读直接读字段 —— 与 `setHero` / `player.hero` 同形（`code-style.md` §11：不传参数的读取直接用字段）。
- **不返回 disposer**：一次性设置，不是可叠加的添加（同 `setHero` / `setTag`）。
- **可重复设置**：`game-over` 那类测试靠它把随机身份改写成固定局；规则上换身份没有约束，不做防御。
- **不给 `getIdentity()`**：无参读取不写成 `getXxx()`（存量里的不主动清理）。

## 与标签袋的分工

标签袋（`player:setTag`）保留，但**降级为「临时数据」**：一次结算里挂的中间值。**常用的、协议层要读的、要有类型的**信息应当有正式字段 —— 身份是第一条按这个口径迁移的（`architecture.md` 第 3 节的推论：「内核不认识它」不能当借口把功能塞进不透明袋子）。

## 本批不做

- **不删 tag 机制**：内核的 `Player` / `Effect` / `Phase` 三处都留着（测试广泛使用）。
- **不做「身份明牌 / 隐藏」的可见性建模**：规则上「身份牌除主公外均隐藏」，但那是表现层的事，与协议层一起谈。
