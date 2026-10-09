# Proposal

## Why

标准包余下 6 将里，孙尚香是**只差一条小机制**的一个：

- **【结姻】零新机制** —— `limit` / `cards` / `targets.filter` / `game:heal` 全都在（【青囊】是同类先例）。
- **【枭姬】只差「武将怎么知道自己装备区的牌走了」** —— 内核的 `'卡牌-进入区域'` / `'卡牌-离开区域'` 目前**只发给牌自己**（`CardDef:on`，装备模板就是这么用的），**没有玩家那一份**；而这两条按底本是**技能**（「当你失去一张装备区的装备牌后」），必须能挂在**角色**头上。

## What Changes

- **内核：区域事件对「区的主人」再发一份**（`server/core/zone.lua`）
  - `notifyEnter` / `notifyLeave` 跑完牌自己那份之后，`self.owner?:fire('卡牌-进入区域' / '卡牌-离开区域', card, self)`。
  - **名字同名、不带方向词**：与 `'阶段-开始'` / `'效果-收尾'` / `'判定-前'` 同一套「同名两份」约定（时机的「方向」在这里没有可用的词 —— 两个方向的当事人不一样）。
  - **顺序**：牌自己那份**先**、区主人那份**后**；`notifyLeave` 仍是「先发两份、再松开本区压的那层」，`notifyEnter` 仍是「先压、再发两份」—— 既有硬不变量（发给内容侧时牌已不在区里 / 已压好）不动。
- **内核：类型面**（`server/core/loader/env-meta.lua`）
  - `Player` 块补 `on` / `fire` 的 `'卡牌-进入区域'` / `'卡牌-离开区域'`（载荷 `(card: Card, zone: Zone)`）。
  - `SkillDef` 块补 `event('卡牌-进入区域')` / `event('卡牌-离开区域')` 候选（回调第一参补 `skill`，与既有 `event` 同形）。
- **内容：新武将 `package/标准/武将/孙尚香.lua`**（吴 · 女 · 体力上限 3）
  - **【枭姬】** = `auto(true)` + `event('卡牌-离开区域')`：只有「**本人的、与这张牌分类对应的那个子区**」才算失去装备（`zone.owner?:equipZoneOf(card) == zone`，照装备模板的判法）⇒ `tryCast` 里 `owner:draw(2)`。**换装也算**（旧牌先被送进弃牌堆）。
  - **【结姻】** = `limit('出牌', 1)` + `cards { zone = '手牌', min = 2, max = 2 }` + `targets { filter = 其他 · 男 · 已受伤 }`；`'使用'` 里弃两张 ⇒ `game:heal(自己, 1)` + `game:heal(目标, 1)`。

## Capabilities

### New Capabilities

无。本变更属探索期的**决策记录**，不写规格增量（`.openspec.yaml` 设 `skip_specs: true`）—— 理由见 `AGENTS.md`「工作流」。

### Modified Capabilities

无。`openspec/specs/` 已冻结、不回头改。（⚠️「区域事件也对区主人发一份」是**内核时机清单**的一部分，属于将来要写规格的那类对外契约 —— 已同步进 `architecture.md` 与 `sanguosha-rules` §9.2。）

## Impact

- **内核**：`server/core/zone.lua`（两个 `notify*` 各加一行）、`server/core/loader/env-meta.lua`（类型面）。
- **内容侧**：`package/标准/武将/孙尚香.lua`（新）。
- **用例**：`server/test/core/zone.lua`（+1）、`server/test/rule/hero-skill.lua`（+5）。
- **文档**：`sanguosha-rules`（§9.2 补「对区主人再发一份」、新增 §9.27 孙尚香）、`moe-kill-dev/references/architecture.md`（区域事件行 + 「同名两份」名单）、`progress.md`（基线 / 武将表 / 缺口表）。
