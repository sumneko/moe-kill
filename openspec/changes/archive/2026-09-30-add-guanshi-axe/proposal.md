# Proposal

## Why

装备技能按「一张牌一个功能点」推进到第八张。【贯石斧】只有定义（武器 / 攻击范围 3），「被【闪】抵消后弃两张牌令【杀】依然造成伤害」未实现。它带出两件家族 / 内核级的事（都有明确消费者，不是提前设计）：

| 缺口 | 谁在用 |
| --- | --- |
| 「打出 = 抵消」没有一等对象：答复语义（名义成立 / 被驳回 / 没打出）散在标签与手筛里 | 【杀】（要【闪】）、【贯石斧】（驳回）、【青龙偃月刀】（迁移） |
| 「被抵消」没有对外宣布的时机 | 同上 —— 青龙原先靠『答复后』手筛四条近似 |

## What Changes

- **新 ask 子类 `AskOffsetCard : AskPlayCard`**（`server/core/effect/ask-offset-card.lua`；`kind` = `askOffsetCard`；入口 `game:askOffsetCard(被问者, 缘由, 条件?)` + `moe.askOffsetCard`）：**打出 = 抵消名义成立**；答复一落定发**两段时机**（全局 `'效果-被抵消'` → 来源 `'效果-来源-被抵消'`，载荷 = 这次询问）；**谁返回原因就驳回这次抵消**（原因记进 `.err`，子类拿它 `cancel` 自己）；**最终「抵消成没成立」读 `.success`**（没打出 / 被驳回 / 答错被拒收 = 假）。
- **【杀】**改用 `game:askOffsetCard(target, '杀', { name = '闪' }).success` 判「被闪抵消」。
- **【贯石斧】**：『被动』订 `owner:on('效果-来源-被抵消')` ⇒ `askCard` 弃两张（候选 = 手牌 + 装备区、**去掉斧子自己**；凑不出两张不问）⇒ `moveCard(两张, '弃牌')` ⇒ 返回 `'贯石斧'` 驳回。
- **【青龙偃月刀】**迁到 `'效果-来源-被抵消'`（四条手筛 → 两条）。
- 用例：新套件 `core.effect.ask-offset-card` +5、`rule.slash` +1（两段时机集成）、`rule.equip` +7（贯石斧）；测试里模拟「打出闪」的筛选跟着改 kind（约 10 处）。
- 文档：`architecture.md`（§10 玩家份事件名规则 + §12 表与样本）、`sanguosha-rules` §9.11、`progress.md`、`HANDOVER.md`。

## Capabilities

### New Capabilities

无。

### Modified Capabilities

无（探索期：本变更只做决策记录，`skip_specs: true`）。
