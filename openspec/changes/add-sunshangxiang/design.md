# Design

## Context

- 底本：【枭姬】「当你失去一张装备区的装备牌后，你可以摸两张牌。」；【结姻】「出牌阶段限一次，你可以弃置两张手牌并选择一名已受伤的男性角色，然后你与其各回复 1 点体力。」
- 现状：区域事件 `'卡牌-进入区域'` / `'卡牌-离开区域'` 由 `Zone:notifyEnter` / `notifyLeave` 发给**牌自己**（`Card:fireHandlers`），载荷 `(card, zone)`；装备模板（`@基础/卡牌/装备牌.lua`）就是这样按「是不是本人的、与分类对应的那个子区」启停被动的。
- 玩家头上的时机表：`Player:on` / `fire`（`moe.event` 表，`name → SimpleEvent`，参数原样透传）；技能声明式订阅走 `SkillDef:event(名, 回调)` ⇒ 挂到 `owner:on`，回调第一参补 `skill`（`makeEventCallback`）。
- 现成件（结姻）：`limit('出牌', 1)`、`cards { zone, min, max }`、`targets { min, max, filter(player, skill) }`、`game:heal(谁, 几点)`、`player.sex`、`player:getLostHp()`。
- 现成件（枭姬）：`Player:equipZoneOf(card)`（`rule.equipZones` 里按分类找子区）、`skill:tryCast`、`player:draw(n)`、`equipCard` 换装时把旧牌先送弃牌堆（旧牌的 `'卡牌-离开区域'` 自然先发）。

## Goals / Non-Goals

**Goals:**

- 孙尚香整将落地。
- 把「武将/技能怎么知道自己区里的牌走了」这条能力**按最小形状**补进内核（区域事件的第二份），不引入新的订阅机制。

**Non-Goals:**

- 不做「玩家级的事件表 + 内容侧随意发」（时机名的清单仍由 `env-meta.lua` 固定住）。
- 不做「牌离开某个**指定**区」的点名订阅（`'卡牌-离开区域'` 的载荷里带 `zone`，订阅者自己筛 —— 【枭姬】就是这么筛的）。
- 不改牌自己那份事件的语义 / 顺序 / 载荷。

## Decisions

### D1. 形状：同名两份，不新增时机名

用户 2026-10-09 定：「对区的主人再发一份」⇒ 名字**与牌自己那份一致**（`'卡牌-进入区域'` / `'卡牌-离开区域'`）。

- 已有约定「无方向可用的场合用**同名两份**」（`'阶段-开始'` / `'效果-收尾'` / `'判定-前'`）—— 区域事件正是这种：两张牌 / 两个区之间的「方向」不是一个词能说清的，而「谁被叫醒」由**订阅在哪张表上**决定（`Card` 表 = 牌的钩子、`Player` 表 = 区主人的技能）。
- 备选（否掉）：① 新增 `'装备区失去牌'` 这类**语义化**时机名 —— 把「装备区」这个内容概念塞进内核，且每种区都得再来一个；② 内容侧自己拿区对象 `zone:on('卡牌-离开区域')` —— 区的**更换**（换装 / 拆区）会让订阅失效，得再管一层生命周期，而「区主人再发一份」由内核顺手做掉、天然跟着主人走。

### D2. 顺序与既有不变量

- `notifyEnter`：**先** `disablePassive()`（区被禁用时压牌），**再**发牌自己那份，**再**发区主人那份。
- `notifyLeave`：**先**发牌自己那份，**再**发区主人那份，**最后**松开本区压的那层。
- 两条都不变的内核硬不变量（`progress.md` 有实测教训）：**内容侧收到事件时，牌已经不在那个区里了、压制状态也已经就位**。【枭姬】的判定依赖前者（`equipZoneOf` 看的是分类，不读牌的位置，但换装的旧牌确实已离开武器区）。

### D3. 【枭姬】怎么判「失去的是装备区的装备牌」

`Skill` 只知道自己区里的牌走了，不知道「走的是不是装备子区」⇒ 判定照**装备模板**的同一条：

```lua
if zone.owner?:equipZoneOf(card) ~= zone then return end
```

- `equipZoneOf(card)` = 「这张牌按分类该去的子区」；`== zone` ⇒ 它**就是从那个子区走的** ⇒ 手牌 / 判定区 / 别人的区 / 公共区（没有 `owner` ⇒ 结果 nil）全部被排除。
- `auto(true)`：摸两张几乎总是想要的（照【奸雄】【天妒】【闭月】）。
- **换装也算失去**：`equipCard` 先把旧牌送进弃牌堆（旧的 `'卡牌-离开区域'` 先发）⇒ 天然覆盖「用新装备顶掉旧装备」这条官方常见情形，用例钉住。

### D4. 【结姻】全用现成件

- 限一次：`limit('出牌', 1)`（用过了不进选项，不是「进了再拒」）。
- 弃两张**手牌**：`cards { zone = '手牌', min = 2, max = 2 }` —— 底本写的是「弃置两张**手牌**」（与【离间】的「一张牌」不同，这里**不含装备区**）。
- 目标：`targets { filter = player ~= skill.owner and player.sex == '男' and player:getLostHp() > 0 }` —— 性别缺失 / 未受伤 / 自己都进不了候选。
- 回复：`game:heal(cast.from, 1)` + `game:heal(target, 1)`；弃牌走 `game:moveCard(cast.use.cards, '弃牌')`（照【离间】）。

## Risks / Trade-offs

- **`?.` 与 `?:` 的坑（本批实测踩到）**：`zone.owner?.equipZoneOf(card)` 是**点号可选链** ⇒ 展开成 `zone.owner and zone.owner.equipZoneOf(card)` ⇒ **不传 self**，形参 `card` 收到 nil（现场报 `attempt to index a nil value (local 'card')`）。调方法要用**可选冒号调用** `zone.owner?:equipZoneOf(card)`（仓库既有惯例：`self.from?:fire(...)` / `self.flowTask?:cancel()`）。
- **区域事件现在每个区都有两份**（牌 + 主人）⇒ 公共区（抽牌 / 弃牌 / 临时区）只有一份。既有内容侧订阅（装备模板）不受影响（它们订的是 `CardDef`）。
- **两次触发**：同一张牌离开装备区时，装备模板的停用（`CardDef:on`）与【枭姬】的摸牌（`SkillDef:event`）都会跑 —— 顺序是「牌自己那份（停用被动）→ 区主人那份（技能问摸牌）」⇒ 技能结算时装备的加成**已经撤掉**了。
