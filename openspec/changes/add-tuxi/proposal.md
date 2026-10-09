# Proposal

## Why

标准包余下 8 将里，**张辽是唯一可能「零新机制」收掉整个武将**的一个（他只有【突袭】一个技能）。底座已经够了：

- **摸牌数**是玩家属性、技能可以在 `'阶段-开始'` 改它（2026-10-09，【裸衣】批）⇒「**改为**获得…」可以用「把本阶段摸牌数归零」表达；
- **盲取别人手牌**不需要新机制（手牌区 `list()` + 局随机源）；
- 唯一缺的是「**至多两名**」这种「一次选几名角色」的询问 —— `AskPlayer` 只有候选名单、没有个数区间（`AskCard` 早就有 `min` / `max`）。

## What Changes

- **内核：`AskPlayer` 支持 `min` / `max`**（用户 2026-10-09 定「askPlayer 得加 min 和 max」）：
  - `AskPlayer.Condition` 加 `min?` / `max?`（**`min` 省略 = 1、`max` 省略 = `min`** ⇒ 不写就是 1/1 = 正好一名，**与从前行为一致**）；同日续改：**候选字段 `players` → `player`，四态 `Player|Player[]|true|fun(Player): boolean`**（一名 / 一批 / `true` = 不限 / 谓词在存活角色里筛）。
  - 答复可以是**一名或一批**（`Player|Player[]`）；校验复用 `moe.askCard.checkTargets`（个数 / 在候选里 / 不重复）⇒ 文案随之与别的询问统一（`答复不在可选角色里` → **`答复的目标不在可选项里`**）。
  - 读法加 **`.players`**（恒列表，没答 = 空表）、`.player` 保留（= `players[1]`）；**`min = 0` 时「一个都不选」是合法答复**。
- **内容：张辽（新武将，整将）** `package/标准/武将/张辽.lua`：
  - **【突袭】** = `event('阶段-开始')`（摸牌阶段）：先 `askPlayer(owner, '突袭', { players = victims, min = 0, max = 2 })`，**选到人才发一次动**（`skill:cast(…)`）——**不问「发不发动」，选 0 名就是不发动**（照常摸牌）；**「改为」= `phase:bindGC(owner:addAttr('摸牌数', -1000))`**（属性下界 0 ⇒ 事实归零，照项目里「1000 = 事实上不限」的同一惯例）。
  - **选人**：`game:askPlayer(owner, '突袭', { players = victims, min = 0, max = 2 })` —— 候选 = 其他存活且手牌非空者；**候选为空就不问也不发动**（免得白弃摸牌）。
  - **盲取一张**：`hand:list()[game.random:nextInt(1, hand:count())]`（手牌是无序区、不暴露牌面 ⇒ 必须随机；用局随机源 ⇒ 可复现）。

## Capabilities

### New Capabilities

无。本变更属探索期的**决策记录**，不写规格增量（`.openspec.yaml` 设 `skip_specs: true`）—— 理由见 `AGENTS.md`「工作流」。

### Modified Capabilities

无。`openspec/specs/` 已冻结、不回头改。（⚠️ `AskPlayer` 的答复形状属于对外契约面：一次可以给多名 —— 记在 `architecture.md` §12 与 `sanguosha-rules` §9.25，等协议层那批一起进规格。）

## Impact

- **内核**：`server/core/effect/ask-player.lua`（`min` / `max` + `.players`）、`server/core/game.lua` 与 `env-meta.lua` 的说明。
- **内容侧**：`package/标准/武将/张辽.lua`（新）。
- **用例**：`server/test/core/effect/ask-player.lua`（+4）、`server/test/rule/hero-skill.lua`（+4）。
- **文档**：`sanguosha-rules`（新增 §9.25 + §9.15/§9.16 的询问清单）、`moe-kill-dev/references/architecture.md`（`game:askPlayer` 行）、`progress.md`。
- **不动**：摸牌阶段本身（业务仍是「读摸牌数、摸那么多」）、协议层。
