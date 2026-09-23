# Proposal

## Why

`AskCard.Condition` 是上一批（`add-dismantle-and-snatch`）仓促长出来的：字段名是复数、语义各不相同（`cards` 换来源、`targets` 兼当窗口与「至少有一个合法目标」的开关、`zones` 兼当盲选候选），而且**同一件事有两种表达**。用户 2026-09-23 重定了形状：

> 每个字段都是筛选条件，如果是数组则满足其一即可，如果不是数组则需要满足这个（可以先归一化为数组），不填则是无要求。字段名我们改成单数形式。`zone` 表示牌需要在这个区域内。`target` 去掉「至少有一个合法目标」的规则，应该是用不到的。

同一轮里用户还定了两件事，都是这份设计的依据：

- **可见性是协议层的事**（服务器侧本来就看得见）：「客户端会实现秘密映射，把该区域的卡替换成『未知卡牌』，客户端选择后服务器映射回来（或者直接丢弃结果随机），然后把正确的卡返回给 `askCard`」⇒ 内核**不按明暗分候选**，一律逐张给 `card`。
- **「至少有一个合法目标才能使用」是使用语义**（官方 `'获取目标'` 返回至少 1 个目标才能使用），内核本来就拥有它（`canUse` / 次数限制）⇒ 用**缘由**表达：「内核直接判断 `reason == '使用'`」。

## What Changes

- **`AskCard.Condition` 重做**（`server/core/effect/ask-card.lua`）：字段单数、统一成筛选条件 —— `name?`（牌名）/ `zone?`（在哪个区）/ `card?`（就是这批里的哪一张）/ `target?`（可用目标与它至少有一个重合）；每个字段都接受「单值或数组」，数组 = 满足其一。
  - **候选来源**：给了 `zone` / `card` 就从那里取（并集），都没给才遍历被问者名下的牌区；`name` / `target` 是纯筛选。
  - **`target` 的新语义**：合法目标 ∩ 给定名单 ≠ ∅；选项里的 `targets` = 那个交集（应答方只能从名单里选）；`{}` 不再有「至少有一个合法目标」的特例。
- **使用语义的入口从条件搬到缘由**：`reason == '使用'` ⇒ 候选逐张跑 `canUse`（用不了的牌不进选项、选项带各自的可用目标）；`@基础/回合.lua` 的出牌阶段因此改成 `game:askCard(player, '使用', { zone = '手牌' })`，`'出牌'` 这个缘由退役。
- **两张牌改成逐张候选**（不再有「暗区盲选」）：【过河拆桥】`{ zone = 目标身上有牌的区 }`、【顺手牵羊】同理（加距离限制），答复挑中哪张就动哪张。
- **撤掉上一批为「盲选」加的东西**（新口径下它们没有用户，用户已确认）：`Condition.zones` / `Option.zone` / `Answer.zone` / `ask.zone`，以及 `server/test/rule/support.lua` 里为答「区域」加的联合类型（回到 `Card[]`）。
- **`Zone.visible` / `setVisible` / `isVisibleTo` / `owner` 留着**：不再用于候选，但正是**协议层遮蔽**要读的东西（哪些区的牌要换成「未知卡牌」）；`@基础/牌堆.lua` 里 `手牌` 仍标成暗区。

## Capabilities

### New Capabilities

无（探索期不写规格：见 `openspec/config.yaml` 与 `AGENTS.md` 的「工作流」；本变更在 `.openspec.yaml` 里设 `skip_specs: true`，可执行契约由用例承担）。

### Modified Capabilities

无（同上）。

## Impact

- 内核：`server/core/effect/ask-card.lua`（`Condition` / `Answer` / `Option` / `collectOptions` / `answerProblem`）。
- 内容：`package/@基础/{回合,濒死}.lua`、`package/标准/卡牌/{过河拆桥,顺手牵羊,五谷丰登}.lua`。
- 用例：`server/test/core/effect/ask-card.lua`、`server/test/rule/{support,turn,trick,slash,dying}.lua`。
- 文档：`moe-kill-dev` 的 `references/{architecture,progress}.md`、`sanguosha-rules` 的 §6/§7/§9.10。
- 明确不做：协议的遮蔽 / 秘密映射（等会话与协议批次）、`askSkill` / `timeout`、武将技能。
