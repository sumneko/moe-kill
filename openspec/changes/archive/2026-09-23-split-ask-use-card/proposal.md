# Proposal

## Why

把 `package/` 里的询问调用点摊开看，「要不要能用」与「答复要不要给目标」是**完全同进同出**的：

| 调用点 | 条件 | 跑 `canUse`？ | 答复给目标？ |
| --- | --- | --- | --- |
| 出牌阶段 | `{ zone = '手牌' }` | ✅ | ✅ |
| 濒死求桃 | `{ name = '桃', target = player }` | ✅ | ✅ |
| 打出（闪 / 杀） | `{ name = '闪' }` | ❌ | ❌ |
| 五谷丰登 | `{ card = 亮出的牌 }` | ❌ | ❌ |
| 过河拆桥 / 顺手牵羊 | `{ zone = 目标的区 }` | ❌ | ❌ |

它们其实是同一件事的两面：**这次问的是「使用」**（官方：`'获取目标'` 返回至少 1 个合法目标才能使用）。用户 2026-09-23 指出：`target` 这个条件只有"要一次使用"才用得上，问要不要拆出 `AskUseCard`。

现状把"这次是使用"塞在**缘由字符串** `'使用'` 里（内核特判一个缘由取值），`target` 与 `canUse` 也都挂在通用 `AskCard` 上 —— 于是通用类背着一半使用语义，答复校验里还多出"该不该给目标"的分叉。拆成两个类之后，**使用语义由类型携带**，缘由回到完全不透明（回到早先定的口径）。

## What Changes

- **新增 `AskUseCard : AskCard`**（`server/core/effect/ask-use-card.lua`）：条件在基类三条（`name` / `zone` / `card`）之上多一条 `target?`；候选**逐张跑 `canUse`**（用不了的牌不进选项），选项带 `targets` = 可用目标（给了 `target` 时取**交集**）；**答复必须给目标**且落在可用目标里。
- **`AskCard` 瘦身**：`Condition` / `Answer` / `Option` 去掉 `target` 与目标那套；不再跑 `canUse`；**答复多给目标会被拒收**；`reason == '使用'` 的内核特判删掉。
- **基类把两处做成可覆写的钩子**（子类只覆写它们）：`makeOption(card)`（把一张牌装成选项）与 `checkOption(option, value)`（这份答复与这个选项配不配）。
- **入口**：`game:askUseCard(被问者, 缘由, 条件?)`（`moe.askUseCard`、`kind` = `'askUseCard'`）。
- **调用点**：出牌阶段 `game:askUseCard(player, '出牌', { zone = '手牌' })`（`'出牌'` 回到旧名）；濒死 `game:askUseCard(current, '濒死', { name = '桃', target = player })`；打出 / 五谷丰登 / 过河拆桥 / 顺手牵羊不变。
- **用例**：拆出 `server/test/core/effect/ask-use-card.lua`（目标与使用语义的用例从 `ask-card` 套件**搬过去**）。

## Capabilities

### New Capabilities

无（探索期不写规格：见 `openspec/config.yaml` 与 `AGENTS.md` 的「工作流」；本变更在 `.openspec.yaml` 里设 `skip_specs: true`，可执行契约由用例承担）。

### Modified Capabilities

无（同上）。

## Impact

- 内核：`server/core/effect/{ask-card,ask-use-card}.lua`、`core/effect/init.lua`、`core/game.lua`、`core/loader/env-meta.lua`（`'卡牌-询问'` / `'卡牌-答复'` / `'卡牌-答复后'` 的载荷类型写成 `AskCard|AskUseCard`）。
- 内容：`package/@基础/{回合,濒死}.lua`。
- 用例：`server/test/core/effect/ask-use-card.lua`（新）、`server/test/core/effect/ask-card.lua`（搬家）、`server/test/rule/turn.lua`（缘由改回 `'出牌'`）、`server/test.lua`（注册新套件）。
- 文档：`moe-kill-dev` 的 `references/{architecture,progress,infrastructure}.md` 与 `SKILL.md`、`sanguosha-rules`（§6 / §7 / §9.4 / §9.10）。
- 明确不做：`Ask`（弃牌阶段那个通用决策询问）与 `AskUseCard` 的合并 —— 后者服务"要一次使用"，前者"问什么答什么都由发起方解释"，各有各的形状；`askSkill` / `timeout` 仍另开一个类。
