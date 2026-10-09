# Proposal

## Why

标准包余下 4 将里，陆逊是**只差一条「候选筛选」时机**的一个：

- **【谦逊】**（锁定技，不能被选择为【顺手牵羊】与【乐不思蜀】的目标）—— 现在合法目标由**牌自己**的 `targets.filter` 筛（发起方视角），候选者**自己**没有任何说话的机会 ⇒ 缺一个「他能不能被指定」的询问点。
- **【连营】**（失去手牌后若没有手牌，可以摸一张）—— 「玩家级『牌离开某个区』事件」在孙尚香批**已经补了**（区域事件对区主人再发一份）⇒ **零新机制**，只要判对「离开的是手牌」+「此刻手牌为空」。

## What Changes

- **内核：新时机 `'卡牌-目标-能否指定'`**（名字按用户 2026-10-09 定的「统一用『能否』」）
  - `collectLegalTargets` 里**逐候选**过完内容侧 `filter` 之后，**再问候选者自己一句**（`player:fire(...)`）—— 返回非空 = 「不能成为目标」（返回值就是那条原因）⇒ 把他从候选里剔出去。
  - **落点在候选者头上**：与结算前那三条 `'效果-能否生效'` / `'效果-来源-能否生效'` / `'效果-目标-能否生效'` **分工不同** —— 这条管**筛候选**（还没指定），那三条管**指定了也不生效**。
- **类型面**（`server/core/loader/env-meta.lua`）：`SkillDef:event` 与 `Player:on` / `Player:fire` 各补一条 `'卡牌-目标-能否指定'`（载荷 `CardDef.TargetPlan`）。
- **内容：新武将 `package/标准/武将/陆逊.lua`**（吴 · 男 · 体力上限 3）
  - **【谦逊】** = `tags '锁定技'` + `event('卡牌-目标-能否指定')`：牌名是【顺手牵羊】或【乐不思蜀】⇒ 返回 `'谦逊'`。
  - **【连营】** = `auto(true)` + `event('卡牌-离开区域')`（区主人那份，与【枭姬】同一份）：`zone ~= owner:getZone('手牌')` ⇒ 返回（只看离开的区、目的地不看）；`owner:getZone('手牌'):count() > 0` ⇒ 返回；否则 `tryCast` 里 `owner:draw(1)`。
- **不做「批量移动完成」时机**（用户 2026-10-09 定）：一次搬空手牌时内核**先摘完、再逐张发事件** ⇒ 第一张触发的【连营】摸到 1 张后手牌就不再为空 ⇒ 后面几张自然被 `count() > 0` 挡住 ⇒ 一次失去 N 张也只摸一张。底本里【枭姬】的口径本来就是逐张（失去 X 张装备 ⇒ 至多 X 次）。

## Capabilities

### New Capabilities

无。本变更属探索期的**决策记录**，不写规格增量（`.openspec.yaml` 设 `skip_specs: true`）—— 理由见 `AGENTS.md`「工作流」。

### Modified Capabilities

无。`openspec/specs/` 已冻结、不回头改。（⚠️ 新时机名 `'卡牌-目标-能否指定'` 是**对外契约**：第三方包与协议层都看得见 —— 已同步进 `architecture.md` 的 `game:canUse` 行与 `sanguosha-rules` §9.2 / §9.29。）

## Impact

- **内核**：`server/core/game.lua`（`collectLegalTargets` 逐候选问一句）、`server/core/loader/env-meta.lua`（类型面）
- **内容侧**：`package/标准/武将/陆逊.lua`（新）
- **用例**：`server/test/core/can-use.lua`（+1）、`server/test/rule/hero-skill.lua`（+7）
- **文档**：`sanguosha-rules`（§9.2 目标口径补一条、新增 §9.29 陆逊）、`moe-kill-dev/references/architecture.md`（`game:canUse` 行补这条时机与两边分工）、`progress.md`（基线 / 22 将 / 缺口表划掉「不能被选为目标」一行）
- **明确不做**：`'卡牌-移动后'` 这类「批量移动完成」时机（上面已述理由）；`Card:setVisible`（周瑜批已定，牌级朝向留给协议层那批）
