# Design

## Context

- **用牌这条链**（`server/core/effect/use-card.lua`）：`canUse` 校验 → 记一次次数 → 取牌 → 全局 `'卡牌-结算前'`（基础规则把牌放进 `处理`）→ 逐目标 `'生效'`（顺序 = `desk:actionOrder(目标)`，起点是**顺序锚点**）→ 全局 `'卡牌-结算后'`（基础规则把牌送进 `弃牌`）。
- **牌定义的钩子**原本只有两个（清单在 `server/core/loader/env-meta.lua`，包作者可见）：`'获取目标'`（算合法目标时 + 用牌时都调）、`'生效'`（每个目标一次，ctx = `CardEffect`）。
- **询问**（`server/core/effect/ask-card.lua`）：`Condition` 有 `name?` / `targets?`，选项由内核**遍历被问者的牌区**算出；答复必须落在选项里（不然拒收、原因记 `.err`）。`'打出'` 的牌由基础规则送 `处理` → `弃牌`。
- **状态载体**：`Phase` 与 `Player` 都有同形的标签袋（`setTag` / `getTag` / `removeTag`）；`Effect` 没有。`Effect.parent` 指外层效果，`CardEffect` 的 `parent` 就是这次用牌。
- **官方原文**（规则集 5.2）：【五谷丰登】使用时机：出牌阶段；使用目标：**所有角色**；执行动作：当此牌**指定目标后**，你亮出牌堆顶的 X 张牌（X 为目标数）；作用效果：目标角色**获得这些牌中（剩余）的一张牌**。◆使用结算结束后，将这些牌中剩余的牌置入弃牌堆。

## Goals / Non-Goals

**Goals:**

- 【五谷丰登】的行为逐条对上官方：亮出 X = 目标数的牌、从**顺序锚点**起逐人选一张、剩余的进弃牌堆。
- 三个新口子都做成**通用形状**（不是"五谷丰登专用"）：将来【过河拆桥】【顺手牵羊】用同一套"候选来自一批牌"，技能 / 无懈可击用同一对"结算前 / 结算后"时机。

**Non-Goals:**

- 过河拆桥 / 顺手牵羊 / 借刀杀人 / 无懈可击、延时锦囊与判定区。
- 不做"亮出的牌对谁可见"这套信息隐藏（内核不认识可见性；表现留给会话批次）。
- 不做官方的「若你未将执行动作完整执行完毕，终止此牌的使用结算」—— 我们的抽牌堆不足时有既有的不足回调（弃牌洗回；洗不回来就平局，见 §9.6）。

## Decisions

### D1 牌自己的两个钩子：`'结算前'` / `'结算后'`

```lua
-- UseCard:settle() 里
self.game:fire('卡牌-结算前', self)
for _, handler in ipairs(def:getHandlers('结算前')) do handler(self) end   -- 使用结算开始时（逐目标之前）
for target in self.game.desk:actionOrder(self.targets) do ... end
for _, handler in ipairs(def:getHandlers('结算后')) do handler(self) end   -- 使用结算结束后（全部生效之后）
self.game:fire('卡牌-结算后', self)
```

- **备选（都不取）**：① 亮牌写进 `'获取目标'` —— `canUse` 每次算合法目标都会调用它，会重复亮牌、提前掏空牌堆；② 在 `'生效'` 里用"是不是第一次"判断 —— 要额外状态、语义错位；③ 在牌文件里临时订阅全局 `'卡牌-结算后'` —— 要自己管 disposer，绕。
- 顺序：牌钩子夹在全局时机**内侧**（前：`'卡牌-结算前'` 之后；后：`'卡牌-结算后'` 之前），于是"基础规则把牌放进 `处理`"早于"亮牌"、"剩余牌进弃牌"早于"这张牌进弃牌"。
- 上下文 = `UseCard` 实例（`user` / `card` / `targets`），与全局 `'卡牌-结算前'` / `'卡牌-结算后'` 同形。

### D2 询问的候选可以来自"给定的一批牌"

```lua
---@field cards? Card[] # 候选就是这批牌（省略 = 遍历被问者的每个牌区）
```

- `collectOptions` 里：给了 `cards` 就按这批牌算选项（复用 `optionOf` 的 `name` 过滤与 `targets` 窗口），**不再**遍历被问者的牌区。答复校验、询问 / 答复时机、父效果全部沿用现成实现 —— "答复必须落在选项里"正好等于官方"获得这些牌中的一张"。
- **备选**：用通用 `Ask`（答复是 `any`、内核不校验）⇒ 内容侧要自己兜合法性；或新造一个"从一堆牌里选一张"的询问类型 ⇒ 与 `AskCard` 重复。

### D3 `Effect` 加标签袋

- 亮出的牌要在三个钩子之间传：`'结算前'` 挂上去，每个 `'生效'` 读出来并改（拿走一张），`'结算后'` 取剩余。`'生效'` 的 ctx 是 `CardEffect`，用 `assert(ctx.parent)` 拿到这次用牌的效果实例。
- 标签袋与 `Phase` / `Player` 同形（`setTag` / `getTag` / `removeTag`，键必须是非空字符串）—— 内核不解释值。

### D4 【五谷丰登】的写法

```lua
Card '五谷丰登'
    : extends '锦囊牌'
    : on('获取目标', function (ctx) return game.desk.alivePlayers end)
    : on('结算前', function (ctx)
        ctx:setTag('剩余', game:getZone('抽牌'):draw(#ctx.targets))
    end)
    : on('生效', function (ctx)
        local use = assert(ctx.parent)
        local remaining = assert(use:getTag('剩余'))
        local card = game:askCard(ctx.target, '五谷丰登', { cards = remaining }).card
        if not card then return end
        use:setTag('剩余', without(remaining, card))
        game:moveCard(card, assert(ctx.target:getZone('手牌'), '目标没有手牌区'))
    end)
    : on('结算后', function (ctx)
        local remaining = assert(ctx:getTag('剩余'))
        if #remaining > 0 then game:moveCard(remaining, '弃牌') end
    end)
```

- **亮出的牌不属于任何区**（与判定牌同一手法）：`OrderedZone:draw(n)` 把它们取出来，此刻谁都不属于 ⇒ 不会污染"牌堆 / 弃牌"的计数，也不用新造一个"展示区"。
- **拿牌必须用目标身上的牌区对象**（`ctx.target:getZone('手牌')`），不能用区名 `'手牌'` —— 区名解析会先找**当前回合角色**，会发错人。
- **"没人答"的处理**：不获得（那张牌留在剩余里，最后进 `弃牌`）。官方是强制获得，但"没人答"在无头测试与超时场景都会出现，保持"不答 = 不获得"的既有形状。
- **剩余为空时不 `moveCard`**：空列表的移动没有意义（`if #remaining > 0`）。

### D5 顺序 = 顺序锚点（使用者就是锚点时他第一个）

- 目标是"所有角色" ⇒ 逐目标 `'生效'` 的顺序 = `desk:actionOrder(目标)`，起点是**顺序锚点**；官方 3.2 的案例正是「最后**从黄月英开始**按逆时针方向依次进行结算」（使用者 = 当前回合角色）。
- 用例钉两条：① 使用者在 1 号位 ⇒ 被问顺序 `1,2,3,4`；② 使用者在 3 号位而锚点在 1 号位 ⇒ 被问顺序 `1,2,3`（**起点是锚点，不是使用者**）。

## Risks / Trade-offs

- [亮牌可能把抽牌堆与弃牌堆都掏空] → 走既有的不足回调：洗回；洗不回来就平局（§9.6）。不额外做官方的"执行动作没做完就终止使用结算"。
- [`'结算前'` / `'结算后'` 钩子让牌定义多两个名字] → 类型集中在 `env-meta.lua`（包作者可见，拼错在编辑期就报）；内核各只调一次。
- [`Effect` 标签袋是"任意值"的口子] → 与 `Phase` / `Player` 同一口径（内核只存不解释）；键必须非空字符串，其余不管。
- [亮出的牌对谁可见没有实现] → 内核本来就答应"只存不解释"，可见性属会话 / 前端批次。
