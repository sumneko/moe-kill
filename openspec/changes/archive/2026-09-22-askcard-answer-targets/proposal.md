# Proposal

## Why

出牌阶段现在用 `game:ask(player, '出牌', { cards = hand:list() })` —— 走的是**通用决策询问** `Ask`（答复是 `any`，"问什么答什么都由发起方解释"）。

用户 2026-09-21 判断：**`Ask` 意义不明** —— 三国杀里的询问其实都有明确类型（要牌 / 要技能），将来会有 `askCard` / `askSkill` + `timeout` 做 race ⇒ 通用 `Ask` 没有立足点。出牌阶段应该用 **`askCard`**：「出不出牌、出哪张」本来就是**要一张牌**。

`askCard` 现在有两个不够用的地方：

1. **答复只有一张牌，装不下目标** —— 出牌必须说明"打给谁"，而 `AskCard:answer(那张牌)` 只接一张牌。
2. **第三个参数语义含糊** —— 现在是 `question: any`（"要什么牌，内容由发起方定"），实际当"任意载荷"用（出牌阶段甚至想把整副手牌塞进去）。用户定：它应当是**匹配条件**，`{}` = 任意牌。

## What Changes

- **`AskCard` 的答复从「一张牌」变成「一张牌 + 目标」**：答复形状 `AskCard.Answer = { card Card, targets? Player|Player[] }`；`card` / `targets` 用 **getter 转存**到 `.card` / `.targets`（读起来方便，也不必在 `settle` 里赋值一份），`.result` 仍是答复本体。
- **`ask:answer(答复)` 收答复表**；`answer(nil)` = 没答上（与「没人应答」同义）。
- **第三个参数 `question` → `condition`（匹配条件）**：要什么样的牌，`{}` = 任意牌；**内核仍不解释**（与 `reason` 同一口径）。
- **`game:useCard` 的 `targets` 接受 `Player|Player[]`**（入口归一化，与 `moveCard` 接受 `Card|Card[]` 同一写法）⇒ 出牌阶段可以直接把 `ask.targets` 递过去，将来的锦囊 / 技能也不用各写一遍归一。
- **出牌阶段改用 `askCard`**：`game:askCard(player, '出牌', {})`，答不上（`ask.card` 为空）就结束阶段；候选不再由发起方塞进询问（应答方按匹配条件从被问者的牌区自己算）。
- **连带读法改动**：`package/标准/卡牌/杀.lua`、`package/@基础/濒死.lua` 读 `.result` 的地方改成 `.card`。
- **用例**：`core.effect.ask-card`、`rule.support`（脚本应答）、`rule.turn`（出牌阶段的应答从 `'决策-询问'` 挪到 `'卡牌-询问'`）、`rule.slash`、`rule.dying` 全部改用新答复形状。

**明确不做**：

- **不动 `Ask`**（现在只剩弃牌阶段一个用户）。它"意义不明"这件事等 `askSkill` / `timeout` / race 落地时再评估 —— 删它要先单独提。
- **不做匹配条件的解读与校验**：内核不解释 `condition`（应答方按它自己算候选），答出来的牌是否真的匹配**当前不校验**。
- **不做 `timeout` / race**（用户已说明是将来）。
- 出牌阶段的**使用限制 / 候选过滤**（死循环问题的正解）是另一件事，不在本批。

## Capabilities

### New Capabilities

- （无）

### Modified Capabilities

- （无）

> 探索期不写规格（`.openspec.yaml` 设 `skip_specs: true`）：契约由用例承担 —— `server/bin/moe-kill.exe --test`（`core.effect.ask-card` / `rule.turn` / `rule.slash` / `rule.dying`）。

## Impact

- 内核：`server/core/effect/ask-card.lua`（答复形状 + `condition` + 转存 getter）、`server/core/game.lua`（`askCard` 参数名与文档；`useCard` 的 `targets` 接受单个或列表）
- 内容：`package/@基础/回合.lua`（出牌阶段改 `askCard`）、`package/标准/卡牌/杀.lua`、`package/@基础/濒死.lua`（读 `.card`）
- 用例：`server/test/core/effect/ask-card.lua`、`server/test/rule/{support,turn,slash,dying}.lua`
- 文档：`architecture.md` §12、`sanguosha-rules` §6 / §7 / §9.1 / §9.2 / §9.4
- **行为变化**：应答方给出答复的形状变了（`answer(牌)` → `answer{ card = 牌, targets = … }`）—— 只有内核侧的应答方（测试脚本 / 将来的匹配系统）需要跟；
  出牌阶段的询问从 `'决策-询问'` 变成 **`'卡牌-询问'`**（且带 `reason = '出牌'`），于是也会连着触发 `'卡牌-答复'` / `'卡牌-答复后'`（基础规则只管 `'打出'`，不会误挪牌）
