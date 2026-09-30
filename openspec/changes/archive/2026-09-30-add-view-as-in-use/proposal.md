# Proposal

## Why

「视为」声明现在只接在**打出族**（`AskPlayCard:beforeAsk` 依次试），【丈八蛇矛】因此只有半张 —— 出牌阶段没法主动把两张手牌当【杀】用。

使用侧要接，但**不能照抄打出侧那份**：打出是响应（玩家只有「用 / 不用」），使用是**主动选择**（玩家在候选里挑用哪张牌）。窗口制在这里会先问一句「要不要用两张手牌当杀」、再要实体牌，既不自然（官方是「决定用【杀】⇒ 再选实体牌」），也得让内核**再问一次「打给谁」**。

## What Changes

- **使用侧的声明走「候选」**：`AskUseCard` 的选项里多一种形态 —— `{ viewAs = 那份声明, plan = 数量区间 }`（没有 `card`）。玩家在选项里挑中它、并在**同一份答复**里给出目标，与正常用牌完全同形；打出侧照旧「依次试」。
- **合法性全部由内核算**（内容侧不用补任何东西）：选项生成时**同步**判「素材够不够」（`ViewAs:canGatherMaterials()`）+ 拿一张**光板虚拟牌**跑 `game:canUse` 取 `plan`；答复之后跑声明的 `'发动'`（省略 = 成立）→ **内核按条件收素材** → 造真牌。
- **答复形状**：`AskCard.Answer` 多一条 **`viewAs?`**（与 `card` 互斥）；答复里给了 `viewAs` 的，按「选中的那个声明选项」校验目标 —— **素材给不出 = 客户端答错**，按既有规范**作废**（`.err` 记原因、不算失败、不发起使用）。
- **声明的关联**：`player:addViewAs(牌名, 关联?, 条件?)` + `ViewAs.source?` —— 客户端先点关联的武器 / 技能、再选牌与目标时要读它（内核只存不解释；约定装备传那张牌实例、技能传技能实例）。【丈八蛇矛】与【八卦阵】传的都是它们自己那张装备牌。
- 【丈八蛇矛】**使用侧落地**：出牌阶段可以主动用两张手牌当【杀】打人（两张手牌随虚拟牌进处理区 → 弃牌堆）。

## Capabilities

无。本变更属探索期的**决策记录**，不写规格增量（`.openspec.yaml` 设 `skip_specs: true`）。可执行契约由用例承担，见 `AGENTS.md`「工作流」。

## Impact

- 内核：`server/core/effect/ask-card.lua`（选项 / 答复形状、`checkAnswer` 认 `viewAs`、新增钩子 `collectExtraOptions` 与 `beforeResolve`）；`server/core/effect/ask-use-card.lua`（追加声明选项、把声明换成真牌）；`server/core/view-as.lua`（`source` 字段）；`server/core/player.lua`（`addViewAs` 第 3 参数）。
- 内容侧：`package/标准/卡牌/丈八蛇矛.lua`（传关联）。
- 测试：`server/test/core/effect/ask-use-card.lua`、`server/test/core/view-as.lua`、`server/test/rule/equip.lua`。
- 文档：`references/architecture.md` / `progress.md` / `sanguosha-rules` 同步。
