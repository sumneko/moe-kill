# Design

## Context

- **玩家现在只有一个区**：`package/@基础/牌堆.lua` 的 `'游戏-开始'` 里给每名角色 `addZone('手牌')`；`装备` / `判定` 还没建（`奖惩.lua` 顶部的「装备区还没做」就是记号）。
- **`Zone` 没有归属、也没有可见性**（`server/core/zone.lua`）：字段只有 `kind` / `cards` / `enabled`，能力是 `put/take/move/peek/count/list/clear` + `disable/enable` + 有序区那两个（`takeTop` / `draw` / `shuffle`）。曾经的「参数袋」（`setParam/getParam`）已经不在。
- **用牌这条链**（`server/core/effect/use-card.lua`）：`canUse` 校验 → 记一次次数 → 取牌 → 全局 `'卡牌-结算前'` → 按行动顺序逐目标 `'生效'`（钩子拿到 `(cardEffect, useCard)`）→ 全局 `'卡牌-结算后'`；牌的去向由基础规则在收尾时统一处理。
- **询问**（`server/core/effect/ask-card.lua`）：`Condition = { name?, targets?, cards? }`，选项由内核**遍历被问者的牌区**（给了 `cards` 就用那批牌）算出，答复必须落在选项里（否则拒收、原因记 `.err`）；`ask.card` / `ask.targets` 都是读 `.result` 的 getter。
- **距离**：`desk:getDistance(from, to)` 两方向取小、最小 1、当场求值。
- **随机**：`game.random`（局上的，seed 可注入 ⇒ 整局可复现）—— `pick(list)` 现成。
- **官方原文**（标准版）：
  - 【过河拆桥】出牌阶段，对一名**区域里有牌**的其他角色使用。你**弃置**其区域里的一张牌。
  - 【顺手牵羊】出牌阶段，对**距离 1 以内**的一名**区域里有牌**的其他角色使用。你**获得**其区域里的一张牌。
  - 口径推论：目标的手牌是**暗的**（使用者只能盲选 ⇒ 官方做法是**随机**弃 / 拿一张），装备区与判定区是**明的**（使用者可以挑具体哪一张）。

## Goals / Non-Goals

**Goals:**

- 两张牌的行为逐条对上官方：「区域里有牌」的目标口径、明区挑牌 / 暗区随机、距离 1 以内、获得的牌进使用者的手牌。
- 两个新口子都做成**通用形状**（不是"这两张牌专用"）：**牌区可见性**（将来的明牌技能、延时锦囊与判定、`奖惩.lua` 的"弃置所有装备牌"都要用）与**区域候选**（同样表达"从某个区里拿一张"）。
- 装备区 / 判定区**只建空区**，顺手让"从别人的区里拿牌"有一个三区的真实形状（否则可见性机制没有用户）。

**Non-Goals:**

- **正式的「弃置」/「失去牌」动作**：本批 `moveCard(牌, '弃牌')` 就够（`add-draw` 那批已把「获得 / 弃置」列为 Non-Goal；`奖惩.lua`、弃牌阶段也都这么写）。真正需要的是"谁弃的 / 从哪来"这类信号，落点等**武将技能**那批（可能要做更泛的「失去牌」）。
- 装备机制与距离修正、借刀杀人、无懈可击、延时锦囊与判定阶段的结算。
- 信息在协议层的表现（谁能看见什么，怎么推给前端）—— 留给会话批次。
- `奖惩.lua` 的弃置范围（装备区现在必然为空，改了没有行为差异）。

## Decisions

### D1 牌区可见性：`visible` + `owner` + `isVisibleTo(视角)`

```lua
-- server/core/zone.lua
---@field private visible boolean # 是否对所有人可见（默认 true；false = 只有持有者看得见）
---@field private owner? Player # 这个区属于谁（玩家建区时自动记；公共区没有）

--- 记下这个区属于谁（只有玩家建区时用）
function M:bindOwner(player) end

--- 设置可见性
function M:setVisible(value) end

--- 这个区对某人是否可见
---@param viewer Player
---@return boolean
function M:isVisibleTo(viewer)
    return self.visible or self.owner == viewer
end
```

- **玩家建区时自动记归属**：`player:addZone(name, zone)` 里 `instance:bindOwner(self)`（跨文件不能写私有字段，所以收进方法 —— 与 `Card:bindZone(zone)` 同一先例）。
- **`false` 的含义**：只有持有者看得见。公共区（`owner` 为 nil）配 `false` ⇒ **谁都看不见** —— 正好是抽牌堆的语义（本批没有消费者，见「可延后」）。
- **备选（都不取）**：① 取值写成 `'所有人' / '持有者'` 这样的字符串 —— 现在只有明 / 暗两态，多一层取值只是啰嗦（将来真有"对某些人可见"再加）；② 判定放到 `Player` 上（`player:getVisibleZones(viewer)`）—— 那样 `Zone` 不需要 `owner`，但公共区就没法被问"它对谁可见"，而"这个区对谁可见"本来就是区自己的事。

### D2 询问的候选可以是「区域整体」，且与「牌」同一次问

```lua
---@field zones? Zone[] # 候选还可以是这几个区域整体（盲选：里面有什么看不见）
---@field cards? Card[] # 候选就是这批牌（与已有语义一致；zones 可以同时给）
```

- 于是【过河拆桥】的**一次询问**就表达完了官方语义：候选 = 「目标身上你看得见的每一张牌」+「那几个看不见的区」——选牌 = 明区里挑一张，选区 = 从那个暗区里随机拿一张。
- **备选（不取）**：分两段问（先用通用 `Ask` 问"选哪个区"、再问"哪张牌"）—— 多一次询问，且要为一个"选区域"的询问现造形状；而单一区域的常见情形（目标只有手牌）本来就不该多问一句。
- **校验**沿用现成规则：答复必须落在选项里 —— 区域选项按 `zone` 比对，牌选项走原逻辑；`Answer` 加 `zone?`、`Option` 加 `zone?`，`ask.zone` 做成读 `.result.zone` 的 getter（与 `ask.card` 同形）。
- **记下名字的代价**：`AskCard` 现在还能"要区域"，名字不再贴切。用户 2026-09-23 选的是"给 `AskCard.Condition` 加 `zones`"⇒ 本批不新造询问类型；将来若要通用化（`askChoice`），与「`timeout` + `askSkill`」那批一起谈。

### D3 盲选 = 局上的随机源

`game.random:pick(zone:list())` —— 别自己 `math.random`（局上的随机源可注入 seed ⇒ 整局可复现，判定 / 洗牌都用它）。

### D4 两张牌的写法

```lua
-- package/标准/卡牌/过河拆桥.lua
---@param player Player
---@return boolean
local function hasCard(player)
    for _, zone in ipairs(player:getZones()) do
        if zone:count() > 0 then
            return true
        end
    end
    return false
end

Card '过河拆桥'
    : extends '锦囊牌'
    : on('获取目标', function (target)
        return table.filter(game.desk.alivePlayers, function (player)
            return player ~= target.user and hasCard(player)
        end)
    end)
    : on('生效', function (cardEffect)
        local user   = cardEffect.user
        local target = cardEffect.target
        local cards  = {}
        local zones  = {}
        for _, zone in ipairs(target:getZones()) do
            local held = zone:list()
            if #held > 0 then
                if zone:isVisibleTo(user) then
                    table.move(held, 1, #held, #cards + 1, cards)
                else
                    zones[#zones + 1] = zone
                end
            end
        end
        local ask  = game:askCard(user, '过河拆桥', { cards = cards, zones = zones })
        local card = ask.card
        if not card and ask.zone then
            card = game.random:pick(ask.zone:list())
        end
        if not card then
            return
        end
        game:moveCard(card, '弃牌')
    end)
```

```lua
-- package/标准/卡牌/顺手牵羊.lua：获取目标多一条距离，拿到的东西进自己的手牌
    : on('生效', function (cardEffect)
        ... 同上挑一张 ...
        game:moveCard(card, cardEffect.user:getZone('手牌'))
    end)
```

- **"区域里有牌"两处各写一份局部函数**（`hasCard`）：内容包之间没有共享函数的通道（共享 env 的全局函数可以，但那要求加载顺序、且这是个很小的判定）；真有第三处再用时再抽（先记进「可延后」）。
- **答不上就不动**（官方不会发生，但"没人应答"是正常情形）：`card` 为空直接返回，牌留在原处、不报错。
- 【过河拆桥】不写 `limit`（锦囊不限次），用掉的牌的去向由基础规则统一处理（临时区 → 收尾进弃牌）。

### D5 开局建两个空区，手牌标暗

```lua
-- package/@基础/牌堆.lua
for _, player in ipairs(game.desk.players) do
    player:addZone('手牌')
    player:addZone('装备')
    player:addZone('判定')
    assert(player:getZone('手牌')):setVisible(false)
end
```

（`addZone` 返回的是**撤销函数**，所以拿区实例仍走 `player:getZone('手牌')`。）

- 只建区：装备区里不会自己出现牌，判定区也不会被结算 —— 装备机制与判定阶段是后面两批的事。
- **不改** `package/身份场/奖惩.lua`：它现在只弃手牌，装备区必然为空 ⇒ 改了没有行为差异（要改单独提）。

### D6 用例落点

- 内核：`server/test/core/zone.lua` 补可见性（默认可见 / 暗区只有持有者 / 无归属的暗区谁都不见）；`server/test/core/effect/ask-card.lua` 补区域候选（选项是区域、答复落在里面、不在里面被拒、与 `cards` 同时给）。
- 规则：`server/test/rule/trick.lua` 扩充（两张牌各若干条 + 并入既有的分类循环用例）。`server/test/rule/support.lua` 的脚本化应答要能答"区域"（现在只会答牌）。

## 可延后的问题

- **抽牌堆现在是"所有人可见"**（没设 `setVisible(false)`）：本批没有消费者，等【观星】这类技能或明牌机制再加。
- **「区域里有牌」这个小判定**现在在两张牌里各写一份，第三处出现时再提到 `Player`（如 `player.hasCards`）或共享函数。
- **`AskCard` 的名字**：它现在既能要牌也能要区域（D2）；要通用化时的落点是单独的 `askChoice`，与「`timeout` + `askSkill`」那批一起谈。
- **明牌机制**：本批的可见性是"整区明 / 暗"，官方的"某张牌被亮出来后对所有人可见"还没有形状。
