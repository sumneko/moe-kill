# Design

## Context

- 官方（BWIKI 标准版）：【青龙偃月刀】「当你使用的【杀】被目标角色使用的【闪】抵消时，你可以再**对其使用**一张【杀】」——「使用」不是「打出」⇒ 要走 `canUse` 的整套校验（次数上限会挡）。
- 官方 FAQ 原文未拿到（用户 2026-09-30 定口径）：追加的【杀】**不受次数限制、不计入次数** —— 两件事分开；另按 FreeKill 实现补**无视距离**。
- FreeKill（`standard_cards/pkg/skills/blade.lua`）：触发挂 `CardEffectCancelledOut`（`isCancellOut` 状态）；`askToUseCard` 的 `extra_data` = `must_targets` / `exclusive_targets` / `bypass_distances` / `bypass_times`，`use.extraUse = true`（不计入次数）。
- 我们的现状：距离判断在内容侧各牌的 `'获取目标'`（【杀】比 `user:distance(player) <= 攻击范围`）；次数检查在 `checkCardItself` / 记账在 `UseCard:settle` —— 都不认识「这一次使用」的特殊形状。

## Goals / Non-Goals

**Goals:**

- 一条**使用级**的放行 / 记账管道（`Game.UseOptions` 三旗标），有真实消费者。
- 【青龙偃月刀】本体与用例。

**Non-Goals:**

- 抵消状态模型（贯石斧批）；顺手牵羊 / 借刀接 `ignoreDistance`；对牌使用侧。

## Decisions

### D1. 触发：用既有 `'卡牌-答复后'` 筛（用户 2026-09-30 定）

```lua
game:on('卡牌-答复后', function (ask)          -- 全局一份，手筛
    -- kind == 'askPlayCard'（打出的牌）+ card.name == '闪' + reason == '杀'
    -- + parent（CardEffect）的 user == owner（是你出的那张【杀】）
    -- 目标取 parent.target（= 打出【闪】的那个）
end)
```

- 优点：**零内核改动**；`'答复后'` 发在【杀】决定「打不打伤害」之前（位置正确）。
- 代价：「答复里出了闪」≈「被抵消」是按【杀】的现状约定的（杀只有闪这一条抵消路）；真「抵消」状态等贯石斧批（§9.11 同记）。
- `reason == '杀'` 与 `parent.card.name == '杀'` 重复，只留 reason；`parent.user == owner` 是不可省的那条（旁人的杀不触发）。

### D2. 追加使用：三个旗标一次给（用户 2026-09-30 拍）

```lua
game:askUseCard(owner, '青龙偃月刀', { name = '杀', target = parent.target }, {
    ignoreDistance = true,
    ignoreUseLimit = true,
    notCounted     = true,
})
```

- **「不计入次数」与「不受次数限制」分开**（用户指出：与「加一次使用机会」不是一回事）—— `ignoreUseLimit` 跳过检查、`notCounted` 不写账；链式触发时账恒为「正经用过的【杀】数」。
- **无视距离**：射程判断走 `Player:isInRange(对方, 范围, 选项)` —— 它认 `ignoreDistance`、直接算在（`distance` 保持诚实、只给真值）；内核**随选项对象把它传给 `'获取目标'` 的回调（第 2 个参数）**，【杀】把选项喂给 `isInRange` 即可 —— 「这次使用」的属性，规则细节留给内容。（**2026-09-30 当日调整**：原定「摊到 `TargetPlan`、内容自己读」⇒ 改为「选项随回调走 + `isInRange` 认标」；`TargetPlan.ignoreDistance` 字段已撤。）
- 只能对其、**不能选额外目标**：`condition.target` 限定后候选目标就他一个（【方天画戟】的 +2 也扩不出别的）。
- 不在自己阶段（借刀场景）：本来就不判次数 / 不记账，旗标无副作用。
- 未来若有「不查上限但计入」的技能：`ignoreUseLimit` 不带 `notCounted` 即可（两个旗标独立）。
- **不先问「是否发动」**（用户 2026-09-30 当日调整）：直接 `askUseCard` —— 用不用由这次询问表达（答复 = 发动、取消 = 不发动），不再先 `askChoice`「发动」。

### D3. 名字（用户定）

`Game.UseOptions`；参数名 `useOptions`（不与 `AskCard.options`（候选列表）相撞）；旗标 `ignoreDistance` / `ignoreUseLimit` / `notCounted`。

### 用例面

| 场景 | 期望 |
| --- | --- |
| 正例 | 闪 → 再杀（顺序）；第二张命中；**账还是 1**；两张都进弃牌堆 |
| 不发动 | 再杀取消（问了不答）；目标没掉血；第二张还在手上 |
| 没第二张【杀】 | 问了再杀；候选为空；无伤害 |
| 链 | 两次都被闪 ⇒ 两次再杀询问；第二次候选空；账 1 |
| 旁人用【杀】 | 不问 |
| 万箭的闪 | 不问（reason 不对） |
| 拆下 | 不问 |
| 内核 | 无视距离能把「没有合法目标」变合法；`notCounted` 不涨账且照样能用；`ignoreUseLimit` 过上限且照常记账；`askUseCard` 的候选与用出去都按选项来 |

## Risks / Trade-offs

- 「答复后」近似抵消：青龙够用；贯石斧要「翻回抵消」时必须开真模型（已记入 Non-goals 与 §9.11）。
- 三个旗标目前只有青龙一位消费者；`ignoreDistance` 只接了【杀】。
- 事件面：青龙订的是全局 `'卡牌-答复后'`（该时机没有 Player 份），每条答复过一遍四条筛 —— 订阅者少、开销可忽略。

## Open Questions

无。
