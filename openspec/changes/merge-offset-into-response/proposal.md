# 变更：响应收成一个概念（并掉 `AskOffsetCard`）

## 需求

内核**不再区分「抵消」与「响应」**：删掉 `AskOffsetCard`，把「一次响应成功」并进 `AskPlayCard`；事件名 `'效果-被抵消'` / `'效果-来源-被抵消'` 改成 **`'效果-被响应'` / `'效果-来源-被响应'`**。「这次响应算不算抵消」由**内容侧自己判**（青龙偃月刀 / 贯石斧 只认 `reason == '杀'` 的响应）。

## 为什么

- 现状：`AskOffsetCard` 只有**一个生产性调用点**（`package/标准/卡牌/杀.lua`），它承载的三件事 —— ① 答复没到手 ⇒ 明确的「没有打出」；② 答复到手 ⇒ 一次响应成立；③ 两段可驳回的时机 —— 对**整个打出的响应族**（杀 / 万箭 / 南蛮 / 决斗）都是共通的。
- 官方 §2.7 的「抵消」= 此牌对该目标不生效，杀的闪、万箭 / 南蛮的杀与闪**都是抵消**；它们现在因为走 plain `askPlayCard` 而不发那个时机（只是恰好没人订）。
- 用户口径（2026-10-09）：**内部不区分这两个词**，一律按「响应」处理，判据交给内容侧。
- 前因：【吕布】【无双】要「一次响应要两张牌」，得先有「一次响应」这个统一概念（本变更只做收口，`count` 留给【无双】那批）。

## 做什么

1. **内核**：`AskPlayCard:settle` 承担响应语义（没答上 ⇒ `reject('没有打出')`；答复到手且没被驳回 ⇒ 发两段时机）；删 `ask-offset-card.lua` / `moe.askOffsetCard` / `game:askOffsetCard`；事件改名；类型面跟着改。
2. **内容**：`杀.lua` 一行（`askOffsetCard` → `askPlayCard`）；青龙偃月刀 / 贯石斧 改订新事件名（判据不变）。
3. **用例**：`test/core/effect/ask-offset-card.lua` 并进 `ask-play-card.lua`（用例名「抵消：…」→「响应：…」并删原文件）；约 25 处应答脚本的 `kind == 'askOffsetCard'` 改成 `kind == 'askPlayCard' and reason == '杀'`。
4. **文档**：`architecture.md` / `sanguosha-rules` / `progress.md` 里的引擎措辞统一成「响应」。

## 不做什么

- **不改官方原文里的「抵消」**（卡牌顶部的牌面、规则集引文、官方 §2.7 的定义）：那是底本原话，改了就没法跟规则书对账。引擎自己的名字里不再出现这个词。
- **不动其它询问类**（`AskCard` / `AskUseCard` / `AskUseCardToCard` / `AskPlayer` / `AskChoice` / `AskUseSkill`）。
- **不加「一次响应要几张」**（`count`）：那是【无双】那批的形状，本批只把概念收口。
- **不做 `'效果-被响应'` 的「谁被响应」细分**：载荷仍是那次询问（`ask`），订阅者按 `reason` / `ask.card` 自己判。

## 验收

`server/bin/moe-kill.exe --test` 全绿（**1044 → 1045**：9 条从 `ask-offset-card` 挪进 `ask-play-card`，另加一条「答复之后被驳回 ⇒ 时机不发」）；问题面板 information 及以上 0；【杀】被【闪】响应仍发两段时机、青龙 / 贯石斧照旧能发动与驳回。
