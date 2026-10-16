# Proposal

## Why

出牌阶段的「用牌 / 用技能」是**两条并行**的询问：服务端同时下发 `Ask.Use` 与 `Ask.UseSkill`，再用 `effectRace` 二选一。客户端同一时刻只呈现得出一条，于是答完「用牌」那条之后，**还挂在半路的「用技能」那条会短暂占住界面** —— 玩家看到约 1 秒的「请发动一个技能」闪一下（2026-10-17 实测：两条询问在 `01:58:31.919` 连着下发，落败那条要等答复那一拍处理完才被取消）；能点的技能按钮也跟着这条询问的来去明灭。

两条路问的其实是**同一件事**（「这次出牌你要做什么」），合成一条既消掉这个时序窗口，也让服务端少发一条消息、客户端少一套分流。

## What Changes

- 内核新增**合体询问** `AskUse`：一次询问里**同时**摆出「能用的牌 / 可用的视为 / 能发动的技能」，答复给出其中一项即可；内容侧出牌阶段改用它，不再用 `effectRace`。
- 协议：`Proto.Request.Ask.Use` 增加可选的一组 `skill`（`Proto.SkillPlan[]`），与现有的 `card` / `viewAs` 并列、**各自可缺** —— `AskUseCard` 只给 `card` + `viewAs`、`AskUseSkill` 只给 `skill`、合体的 `AskUse` 三组都给，**两类复用同一条方法**。
- **BREAKING**：`Proto.Request.Ask.UseSkill` 与 `Proto.Result.Ask.UseSkill` 退役、`Ask.UseSkill` 不再下发；`Proto.Result.Ask.Use` 增加 `usedSkill`，一份结果承载三种答复（`usedCard` / `usedViewAs` / `usedSkill`，三者互斥；`targets` / `cards` 复用）。不做兼容别名 —— 我们是这份协议目前唯一的消费者。
- 客户端：`Ask.Use` 那一支按「`card` / `viewAs` / `skill` 哪组在就渲染哪组」，技能按钮的可点性直接从这条询问里取；`ASK_METHODS` 去掉 `Ask.UseSkill`。
- **保留**：`AskUseCard` / `AskUseSkill` 两个内核类与它们各自的用例都留着（后者将来「结束阶段用技能」那一路还要用）；`effectRace` 是通用机制，不删。

## Capabilities

### New Capabilities

（无 —— 本变更不引入新能力，只改已有询问的对外形状与内核实现）

### Modified Capabilities

- `jsonrpc-protocol`: 询问的答复方法清单由六个收敛为五个（`Ask.UseSkill` 退役）；`Proto.Request.Ask.Use` / `Proto.Result.Ask.Use` 的形状扩成「牌 / 视为 / 技能三组、各自可缺、结果按 `used*` 判别」

## Impact

- 协议声明与产物：`server/proto.d.lua`、`client/src/proto.d.ts`（`--gen-proto` 重生成）、活规格 `openspec/specs/jsonrpc-protocol/`
- 内核：`server/core/effect/ask-use.lua`（新增）、`server/user/client-user.lua`、`server/user/user.lua`
- 内容侧：`package/@基础/阶段/出牌阶段.lua`
- 前端：`client/src/state/agent.ts`、`client/src/view/Ask.ts`、`client/src/view/pick.ts`、`client/src/view/App.ts`
- 用例：`server/test/core/effect/ask-use.lua`（新增）、`server/test/user/ask-use-skill.lua`、`server/test/proto.lua`、`server/test/rule/{hero-skill,turn,...}.lua` 里按 `ask.kind` 认询问的探针
