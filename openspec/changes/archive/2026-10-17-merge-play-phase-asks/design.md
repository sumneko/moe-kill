# Design

## Context

（动机见 `proposal.md` 的 Why；这里只记形状与约束。）

现状：出牌阶段在内容侧用

```lua
local useCard  = game:startAskUseCard(player, '请使用一张牌', PLAY_PHASE_CONDITION)
local useSkill = game:startAskUseSkill(player, '请发动一个技能')
local result = game:effectRace({ useCard, useSkill }, ...)
```

两路并行；内核是两个**互不相干**的类（`AskUseCard` / `AskUseSkill`），协议是两条方法（`Ask.Use` / `Ask.UseSkill`）。

可复用的既有设计：`server/user/client-user.lua` 里那句「**params 里传了哪些组件就带上哪些，回包里有几个字段就解析几个**」—— 它天然支持「一条方法、多组可选分量」，这次不用改这套解析骨架，只需把 `askUseSkill` 的发送点换个方法名、把技能那组塞进 params。

## Goals / Non-Goals

**Goals:**

- 一次询问能同时摆出「能用的牌 / 可用的视为 / 能发动的技能」，答复给出其中一项。
- 协议上两类**复用同一条方法与同一份结果**，三组分量各自可缺。
- 出牌阶段只发一条询问，前端不再有「落败那条抢界面」的时序窗口。
- 技能按钮的可点性来自这条询问，不再依赖「主询问恰好是技能那条」。

**Non-Goals:**

- 不动 `Ask.Select` / `Ask.Choice` / `Ask.Hero` / `Ask.Panel`，也不动「视为要素材」那一步（它继续走 `Ask.Select`）。
- 不做协议兼容别名（本项目是这份协议目前唯一的消费者，随代码一起改）。
- 不删 `AskUseCard` / `AskUseSkill` / `effectRace`（前两者各有语义、各有用例，`effectRace` 是通用机制）。

## Decisions

### 1. 新增内核效果 `AskUse`，而不是把技能塞进 `AskUseCard`

`AskUseCard` 的语义是「要**一次使用**」（选项 = 牌 + 可用目标，答复必须带目标），技能不是牌，硬塞会让这个类变成两套语义的并集、且它现有的所有调用点都要开始关心「有没有技能那半」。

`AskUse` 是「要**一次行动**」：选项分两半（`options` = 牌，形状沿用 `AskUseCard.Option`；`skills` = 技能，形状沿用 `AskUseSkill.Option`），答复按给了 `card` / `viewAs` / `skill` 哪一样判别，执行入口两个 —— 用牌走**继承来的 `:use()`**、发动技能走 `:useSkill()`。

⚠️ 用牌那个入口**不能**叫 `useCard` —— `AskUseCard` 上有个**同名字段** `self.useCard`（那次使用），而实例字段会遮蔽方法，于是 `AskUseCard:use()` 里那句 `if self.useCard then return self.useCard end` 会直接返回方法本身、牌根本没用出去（实测踩到：内核用例报「目标掉 1 点体力 期望 4 实际 5」，加了 `useCard` 处的探针才看出 `card` 是对的、`game:useCard` 压根没跑）。

**备选**：① 把技能并进 `AskUseCard`（语义混、调用点全要动）；② 只在内容侧拼装（做不到 —— 选项收集与答复校验都在内核）。

### 2. 技能那半的逻辑抽成共享片段，`AskUseSkill` 与 `AskUse` 共用

`AskUseSkill` 现在的 `collectOptions` / `makeOption` / `checkCards` / `checkTargets` / `checkAnswer` / `normalizeAnswer` 是「技能前置 + 素材 + 目标」的完整口径。`AskUse` 直接照抄一份必然漂移，所以把这些**按技能那半**的职责抽出来（同文件里的本地函数或一个内部类），两个类都调它。

**备选**：让 `AskUse` 内部持有一个 `AskUseSkill` 实例来算选项 —— 那实例还得顺带处理答复与执行，等于把 `effectRace` 搬进类里，反而更绕。

### 3. 协议：三组分量各自可缺，复用一条方法

```lua
---@field card?   Proto.CardWithPlan[] # 能用的牌（不问牌就不给）
---@field viewAs? Proto.ViewAs[]       # 可用的视为技列表（同上）
---@field skill?  Proto.SkillPlan[]    # 能发动的技能（同上）

---@field usedCard?   integer   # 与 usedViewAs / usedSkill 互斥
---@field usedViewAs? integer
---@field usedSkill?  integer
---@field targets?    integer[]
---@field cards?      integer[]
```

字段名一律**单数**（与现有的 `card` / `viewAs` 一致）；`Proto.SkillPlan` 原样沿用。判别靠 `used*` 而不是新加 `kind` 字段 —— 与现有风格一致，且 `client-user.lua` 的逐字段解析天然支持。

**备选**：新增一条 `Ask.UseAll`（客户端两套分支、服务端两处形状）；加一个必给的 `kind` 字段（与现有形状不符）。

**一个必须写死的歧义**：`viewAs` 里的项可能来自技能（`sourceSkill`），但答复时**给 `usedViewAs` 就是「用那个视为」**（不论来源是牌还是技能），`usedSkill` 只用于「发动技能本身」。

### 4. 前端 `Ask.Use` 按「哪组在就渲染哪组」

`Ask.ts` 把现在 `Ask.UseSkill` 分支那排技能按钮并进 `Ask.Use` 分支（`skills` 存在就渲染）；`pick.ts` / `App.ts` 里按 `ask.method === 'Ask.UseSkill'` 分流的地方改成按**答复里带什么**分流；`ASK_METHODS` 去掉 `Ask.UseSkill`。

## Risks / Trade-offs

- **用例探针大面积要改**（`ask.kind == 'askUseCard'` 之类的判据）→ 漏改会静默走错分支、甚至用例仍绿。对策：先全局搜 `askUseCard` / `askUseSkill` / `effectRace` 列清单，改完跑全量用例并核对基线数（不只到 0 失败）。
- **`AskUse` 与 `AskUseCard` 的牌子半可能重复**（都调 `game:canUse`）→ 抽公共片段，别复制第二份。
- **协议 BREAKING**：任何旁路实现（旧页面 / 脚本）会失效 → 本项目是唯一消费者，随代码同步改；活规格 `openspec/specs/jsonrpc-protocol/` 一起更新。
- **`skills` 为空时**：一条什么都不问的询问没有意义 → `AskUse` 在「三组都为空的场合」直接失败（不发询问），避免又出现一条空提示。
- **节拍不变**：这次改动不碰 `game:animSleep` 的落点；答复后的 1 秒节拍照旧由内容侧那几张 `BEAT` 表管。

## Migration Plan

一次性切换（协议 + 内核 + 内容侧 + 前端 + 用例同批提交）：先加内核 `AskUse` 与共享片段 → 改内容侧出牌阶段 → 改协议声明并 `--gen-proto` → 改 `client-user.lua` / `user.lua` → 改前端 → 改用例 → 跑 `server/bin/moe-kill.exe --test` 与真链路（4 人局出牌阶段不再出现第二条询问）。回滚 = 整批回退到本次提交之前。

## Open Questions

- 将来「结束阶段用技能」那一路，是复用 `AskUse`（只给 `skill` 那组）还是继续用 `AskUseSkill`？两者都能走同一协议，等真做那个功能时再定，不影响本次实现。
