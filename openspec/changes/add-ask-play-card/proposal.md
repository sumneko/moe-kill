# Proposal

## Why

上一步拆出 `AskUseCard` 之后，把剩下的询问调用点再摊开看，**缘由字符串**这一列还是乱的：

| 调用点 | 改前的缘由 | 实际含义 |
| --- | --- | --- |
| 出牌阶段 | `'出牌'` | 阶段名 |
| 濒死求桃 | `'濒死'` | 时机名 |
| 【杀】要闪 | `'打出'` | **动作类别**（不是"为什么问"） |
| 【万箭齐发】要闪 | `'打出'` | 同上 |
| 【南蛮入侵】要杀 | `'打出'` | 同上 |
| 【决斗】要杀 | `'打出'` | 同上 |
| 五谷丰登 | `'五谷丰登'` | 发起者牌名 |
| 过河拆桥 / 顺手牵羊 | 牌名 | 发起者牌名 |

`'打出'` 是**唯一一个把"动作类别"塞进缘由**的取值，而且它同时是**唯一的读者**：`package/@基础/打出.lua` 靠 `reason == '打出'` 决定那张牌往哪去（发起那次结算的临时区）。也就是说，"这次是打出"这件事既进不了类型，又得靠一个魔法字符串在内容侧传话 —— 与上一步"语义由类携带、缘由不透明"的口径不一致。

用户 2026-09-23 提出：**把「打出」也拆成一个类**，于是询问按语义分三种 —— 「询问使用牌」`AskUseCard`、「询问打出牌」`AskPlayCard`、「询问选择牌」`AskCard`。

## What Changes

- **新增 `AskPlayCard : AskCard`**（`server/core/effect/ask-play-card.lua`，`kind` = `'askPlayCard'`）：形状与 `AskCard` 完全一样（条件筛候选、答复只有牌、拒收目标），只多一件事 —— **答复的牌当场交出来**：`onAnswered()` 把它 `moveCard` 进**发起这次结算的临时处理区**（`self.parent:getTempZone()`）；**没有父结算就不动**，交给内容侧。
- **基类多一个可覆写钩子 `onAnswered()`**（`---@async`，基类为空）：在答复定下之后、`'卡牌-答复'` 之前跑 —— 子类在此处置"答复了要顺手做什么"。
- **入口**：`game:askPlayCard(被问者, 缘由, 条件?)`（`moe.askPlayCard`）。
- **缘由只剩下"谁发起的"这一种含义**（惯例写牌名 / 阶段名）：四张牌改用它 —— 【杀】`'杀'`、【万箭齐发】`'万箭齐发'`、【南蛮入侵】`'南蛮入侵'`、【决斗】`'决斗'`。
- **`package/@基础/打出.lua` 删掉**（它是 `reason == '打出'` 的唯一读者，职责移交内核类）—— 用户明确同意。
- **用例**：新增 `server/test/core/effect/ask-play-card.lua`；`ask-card` 套件里两条 `'打出'` 用例换成一条"`AskCard` 自己不处置那张牌"。

## Capabilities

### New Capabilities

无（探索期不写规格：见 `openspec/config.yaml` 与 `AGENTS.md` 的「工作流」；本变更在 `.openspec.yaml` 里设 `skip_specs: true`，可执行契约由用例承担）。

### Modified Capabilities

无（同上）。

## Impact

- 内核：`server/core/effect/{ask-card,ask-play-card}.lua`、`core/effect/init.lua`、`core/game.lua`、`core/loader/env-meta.lua`（三个时机载荷类型写成 `AskCard|AskUseCard|AskPlayCard`）。
- 内容：`package/@基础/打出.lua`（**删除**）；`package/标准/卡牌/{杀,万箭齐发,南蛮入侵,决斗}.lua`（改调 `askPlayCard`、缘由换名）。
- 用例：`server/test/core/effect/ask-play-card.lua`（新）、`server/test/core/effect/ask-card.lua`（两条 `'打出'` 用例改写成基类行为）、`server/test.lua`（注册新套件）。
- 文档：`moe-kill-dev` 的 `references/{architecture,progress,infrastructure,code-style}.md` 与 `SKILL.md`、`sanguosha-rules`（§6 / §7 / §9.2 / §9.10）。
- 明确不做：`AskPlayCard` 的候选**不跑 `canUse`**（打出的牌不看次数、不跑 `'卡牌-能否使用'`）、**不记次数**；「使用」与「打出」的区分就体现在**用哪个类**上。
