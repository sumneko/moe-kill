# Proposal

## Why

胜负判定**已经有了**（`package/身份场/胜负.lua` 订阅 `'玩家-死亡'` → `game:endGame { side, reason }`，三种结局：主公方 / 反贼 / 内奸），但它只覆盖「**有人赢**」这一半：

- **牌堆耗尽的结局没人接**：官方口径是「牌堆与弃牌堆都没有牌时，游戏平局」，而现在只是「能取多少取多少」—— 局会继续空转下去（摸不到牌、判定翻不出牌），没有任何东西会结束它。
- **现在正是接它的时机**：判定动作刚落地，取顶与洗回已经收敛到牌区接口（`OrderedZone:draw` + 不足回调）⇒「**两堆都空**」这件事全工程只有一个地方知道（抽牌区的不足回调用洗回失败来表达），接平局就是在那一处加一个判断。

## What Changes

- **内容侧（基础规则）：牌堆与弃牌堆都没牌 ⇒ 平局**
  - `package/@基础/牌堆.lua` 挂在抽牌区上的**不足回调**里：弃牌也为空（洗不回来）⇒ `game:endGame { side = '平局', reason = '牌堆与弃牌堆都没有牌' }`。
  - **一处覆盖全部取顶动作**：摸牌、判定、将来任何从抽牌堆取牌的动作都走同一个回调。
- **结局的取值加上「平局」**：`Game.Result.side` 现在是四种 —— 主公方 / 反贼 / 内奸 / **平局**（`server/core/game.lua` 的类型注释同步；`endGame` / `getResult` 的形状不变）。
- **明确不做**：不动 `身份场/胜负.lua` 的判据（平局与身份无关，属基础规则）；不做「牌堆快耗尽」的预警 / 前端提示；不为平局新增字段或方法（`endGame` 本来幂等，发现即结束）。

## Capabilities

### New Capabilities

无（探索期不写规格：见 `openspec/config.yaml` 与 `AGENTS.md` 的「工作流」，本变更在 `.openspec.yaml` 里设 `skip_specs: true`，契约以用例为准）。

### Modified Capabilities

无（同上）。

## Impact

- 内核：`server/core/game.lua`（**只改 `Game.Result` 的注释**：`side` 取值加「平局」；行为不变）。
- 内容：`package/@基础/牌堆.lua`（不足回调里加平局判断）。
- 用例：`server/test/rule/game-over.lua`（三条：摸牌时两堆都空 ⇒ 平局；判定时两堆都空 ⇒ 平局；抽牌堆空但弃牌还有牌 ⇒ 不结束、照常洗回）。
- 文档：`.agents/skills/sanguosha-rules/SKILL.md`（§2 结局口径 + §9.6 结局链路）、`moe-kill-dev` 的 `references/architecture.md`（§12 牌区取顶段）、`references/progress.md`。
