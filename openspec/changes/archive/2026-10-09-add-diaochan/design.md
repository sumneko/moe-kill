# Design

## Context

- 底本：【离间】「出牌阶段限一次，你可以弃置一张牌并选择两名其他男性角色，后选择的角色视为对先选择的角色使用了一张不能被【无懈可击】的【决斗】。」；【闭月】「结束阶段开始时，你可以摸一张牌。」
- 无懈的实现（`package/标准/卡牌/无懈可击.lua`）：订全局 `'效果-能否生效'` ⇒ `nullify(effect)`：`canNullify(effect.card)`（是锦囊）→ `nullified(card)` 按行动顺序问一圈「要不要对这张牌使用【无懈可击】」。
- `Game.UseOptions`（内核）：`ignoreDistance` / `ignoreUseLimit` / `notCounted` / `extraTargets` / `unrespondable` —— **全是内核自己要读的**（射程判断、次数检查、记账、目标数、询问层）。
- 现成件：`limit`（技能的阶段次数上限）、`cards` / `targets`（主动技前置声明）、`rule.ownZones`（手牌 + 装备子区）、`game:createVirtualCard`、`game:useCard(使用者, 牌, 目标, 选项)`、`player.sex`。

## Goals / Non-Goals

**Goals:**

- 貂蝉整将落地。
- 「不能被无懈可击」这条**不污染内核**：选项字段由**读它的那个包**自己注入 + 自己消费。

**Non-Goals:**

- 不改 `server/core/**`（一行都不动）。
- 不做「不能被无懈」的**逐目标**粒度（文本说的是整张牌不能被无懈 ⇒ 一个 boolean 够）。

## Decisions

### D1. 字段住内容侧：`unnullifiable`

用户 2026-10-09 定：「这个字段要在『无懈可击』这个内容包里注入和使用」。

- **类型面注入**：`package/标准/meta.lua` 里 `---@class Game.UseOptions` / `Game.UseOptionsInput` 各加 `@field unnullifiable? boolean`（与 `牌表` 的注入同一处）。
- **消费**：`无懈可击.lua` 的 `nullify()` 开头 `if effect.useCard?.useOptions?.unnullifiable then return nil end` ⇒ 不进 `nullified` ⇒ **不问**。
- **为什么读 `effect.useCard` 就够**：两种「生效」里，`CardEffect` 与 `CardEffectToCard` 都带 `useCard`（判定阶段那张延时锦囊没有 `useCard` ⇒ 不受影响，本来就该照常可无懈）。
- **为什么不用改 `cardTargets`**：候选只在「问」的时候才呈现 ⇒ 不问就不会出现「玩家白用一张无懈」的场景。
- **与既有内核字段的界线**：`unrespondable` 住内核是因为**内核自己要读**（询问层 `isResponseBanned`）；`unnullifiable` 只有无懈自己读 ⇒ 住内容侧。这条界线写进 `architecture.md`。

### D2. 【离间】依赖目标的点选顺序

官方「**后**选择的角色视为对**先**选择的角色使用」⇒ `cast.use.targets[1]` = 挨打的、`[2]` = 视为使用者。`AskUseCard` 的答复 `targets` 是列表且**保序**（玩家点选顺序）⇒ 直接用。

⚠️ 这是项目里**第一个吃「目标顺序」的规则**；用例钉住方向（决斗的响应问的是**先选的那位**），文档记下这条依赖 —— 协议层将来要保证「答复里目标的顺序 = 玩家的点选顺序」。

### D3. 【离间】其余部分用现成件

- 限一次：`limit('出牌', 1)`（用过了不进选项，不是「进了再拒」）。
- 弃置一张牌：`cards { zone = rule.ownZones, min = 1, max = 1 }` —— 官方「一张牌」不限手牌（与【制衡】同一口径），**不含判定区**。
- 两名其他男性：`targets { min = 2, max = 2, filter = player ~= owner and player.sex == '男' }`（`sex` 由武将写入，女性 / 无性别都进不了候选）。
- 「视为使用一张【决斗】」：`game:createVirtualCard('决斗')` + `game:useCard(后选者, 决斗, 先选者, { unnullifiable = true })` —— 虚拟牌走同一条使用链（【武圣】/【丈八蛇矛】的先例：不查声明的牌区、「无花色点数」照常结算）；目标写单值或列表都收（这里写单值）。
- 归因：整段写在 `'使用'` 钩子里 ⇒ `Skill:use()` 已包一层 `SkillCast`（归因在离间名下）。

### D4. 【闭月】零新机制

`auto(true)` + `event('阶段-开始')`（认 `phase.name == '结束'`）+ `tryCast` 里 `owner:draw(1)` —— 与【洛神】/【裸衣】同一个阶段时机口子；`auto(true)` 因为「摸一张」几乎总是想要的（照【奸雄】【天妒】）。

## Risks / Trade-offs

- **选项字段名是松契约**：内容侧塞进 `UseOptions` 的字段在协议层要能表达（将来前端要传 / 读）。目前只有 `unnullifiable` 一个，且它由**发起这次使用的人**（技能）给，不需要玩家输入 ⇒ 风险低。
- **目标顺序**（D2）：现在只靠「答复列表保序」这条隐含约定 —— 已写进文档与用例；若将来协议层把目标答复做成无序集合，离间会失效。
