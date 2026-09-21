# Design

## Context

- 现在的「摸牌」在 `package/@基础/回合.lua` 里：`draw(player, count)` + `recycleDiscard()` 都是**局部函数** ⇒ 只有这一处能用；`game:moveCard(cards, hand)` 已经是"一次结算挪一批"的效果（可 await、失败读 `.err`）。
- 内容侧手上有什么：注入的 `game` / `Card` / `Depends` / `util`；能写 `game:setValue`（规则数值，**不许存函数**）、能 `game:on(时机, 回调)` 注册行为、能 `Depends { 路径 }` 控制加载顺序。**没有**任何"包之间共享函数"的通道。
- 内核不预设区名（区名由 `@基础/牌堆.lua` 建：`抽牌` 有序 / `弃牌` / `处理`；玩家身上的 `手牌`）。
- 刚确立的同族形状（伤害 / 回复 / 濒死）：**内核给效果与时机，语义写在 `@基础` 的同名文件**（`@基础/伤害.lua`、`@基础/回复.lua`、`@基础/濒死.lua`）。
- 用户 2026-09-21 定：`Draw` 只给一个 `'摸牌'` 时机；并把「常用动作的形状」写成通用约定。

## Goals / Non-Goals

**Goals:** 「抽 X 牌」有一个**所有包都能调、签名带类型、可 await、失败可读**的入口；语义只有一份实现；顺手把"常用动作该怎么给大家用"写成约定，以后「获得 / 弃置 / 判定」照抄。

**Non-Goals:** 通用动作注册表；`'摸牌-前' / '摸牌-后'` 这类前后时机（将来真要用再加，加的位置在 `Draw:settle()` 里）；"获得牌"（从别处拿牌进手牌）与"弃置"（`game:moveCard` 已够）；改摸牌的规则语义。

## Decisions

### D1：内核不实现取牌，只发 `'摸牌'` 时机

```lua
-- server/core/draw.lua
function M:settle()
    self.game:fire('摸牌', self)
end
```

内核要真去取牌就得知道「哪个区是抽牌堆、哪个是弃牌、哪个是手牌」⇒ 与「内核不预设区名 / 属性名」冲突（伤害那次刚从"写死 `'体力'`"退回来）。所以内核只提供**效果外壳 + 一个时机**，取牌与洗回写在规则侧。

### D2：入口是 `game:draw(player, count)`（与 damage / heal 同形）

```lua
---@param player Player # 谁摸牌
---@param count integer # 摸几张
---@async
---@return Draw # 这次摸牌（已经结完：失败读 `.err`）
function M:draw(player, count)
    local draw = moe.draw.create { game = self, player = player, count = count }
    draw:apply():await()
    return draw
end
```

- 调用方拿到的是**效果实例**：可读父效果 / 深度、进效果链、失败读 `.err`（不抛），与其它动作一致。
- 规则侧的 `'摸牌'` 回调里 await `game:moveCard` ⇒ **整个调用链是异步的**，但写法与同步一致（项目前提：整个游戏都在协程里跑）。

### D3：语义写在 `package/@基础/抽牌.lua`

```lua
game:on('摸牌', function (draw)
    local deck  = assert(game:getZone('抽牌'), '局上没有抽牌区')
    local hand  = assert(draw.player:getZone('手牌'), '这个玩家没有手牌区')
    ---@type Card[]
    local cards = {}
    for _ = 1, draw.count do
        if deck:count() == 0 and not recycleDiscard() then
            break
        end
        cards[#cards + 1] = deck:takeTop()
    end
    if #cards > 0 then
        game:moveCard(cards, hand)
    end
end)
```

- 取顶**逐张**（中途可能洗回 ⇒ 每张都要看一眼牌堆），**整批只挪一次**（一次 `MoveCard` 效果）。
- 洗回规则原样从 `回合.lua` 搬来：弃牌全部挪回 `抽牌` + `deck:shuffle()`（有序区自带随机源）；两边都空 ⇒ 能摸多少摸多少，不报错。

### D4：`@基础/回合.lua` 的局部 `draw` / `recycleDiscard` 退休

摸牌阶段改成 `game:draw(player, DRAW_COUNT)`。**行为不变**（同一套取牌与洗回逻辑，只是搬了位置），所以 `rule.turn` 的两条用例应当继续通过 —— 这也是本次搬家的验收。

### D5：把「常用动作的形状」写成约定

> 凡会被多处复用的动作（抽牌 / 弃置 / 获得 / 判定…）：① 内核给**一个效果 + 一个便利入口**（`game:draw` / `game:heal` / …）；② 语义（区名、洗回、阈值、顺序）写在 `@基础` 的**同名文件**里，通常就是订阅该动作的那一个时机；③ **不为"替换整个动作"预先造注册表** —— 现在的覆盖手段是"改状态 + 注册顺序"，真要替换时再单独谈（按功能点就地补）。

写进 `moe-kill-dev/references/architecture.md`（§12 收尾）与 `sanguosha-rules` 的落地写法一节。

**Alternatives**：① 动作注册表（`game:registerAction('抽牌', fn)`）—— 多一套机制、名字是字符串（LuaLS 看不到签名与参数），而现在只有一个动作；② 内核直接实现 `game:draw` —— 要预设三个区名；③ 内容侧共享函数 —— 没有通道，得先给注入面开口子（比一个效果大得多）。

## Risks / Trade-offs

- [搬家可能悄悄改掉摸牌语义] → 把 `rule.turn` 的两条（摸 2 张 / 抽空洗回）当作搬家验收，另加 `rule.draw` 直接对入口本身做端到端。
- [内核侧用例建的是"裸局"，而"摸牌"的语义在 `@基础`] → `core/draw` 只断言"内核做的那点事"（触发时机、上下文、不碰牌区），真摸牌交给 `rule.draw`。
- [约定写得早、以后可能要改] → 约定只写"形状"（谁提供、语义在哪、不预造注册表），不写死时机个数与命名。
