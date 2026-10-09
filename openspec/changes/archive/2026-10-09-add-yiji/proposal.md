# Proposal

## Why

郭嘉【天妒】上一批已落地（`add-judge-player-event`），【遗计】当时留后 —— 卡在「**把某张牌交给某人**」这种询问上：项目里只有【仁德】那种「一批牌 → 一名角色」（走技能前置声明），没有「结算中逐次分配」的形状。

用户给了做法（2026-10-09）：「把牌堆顶 2 张移动到临时区，然后用 `askCardToPlayer { min = 1, zone = tempZone }` 进行反复询问，如果取消了就给自己。直到临时区的牌耗尽」（随后纠一处：**`max` 得是剩余牌的数量**）。

核查结论：**这个形状不用新开询问** —— `AskCardWithTarget`（2026-10-08 为【仁德】做的）已经具备 `zone`（可传区对象）+ `min` / `max`（张数区间）+ `targets` / `maxTarget`（给谁）+ `cancelable`，与草稿里那个方法名一一对应。

## What Changes

- **`package/标准/武将/郭嘉.lua` 加【遗计】**（与【天妒】同文件，`skills` 补齐）：
  - `auto(true)` + `event('伤害-目标-生效后')` ⇒ `for _ = 1, damage.amount do skill:tryCast(…) end`（**「1 点伤害」是粒度**：受 N 点发动 N 轮，一轮一次 `Cast`）。
  - 每轮的 body：`game:drawCards(owner, 2, cast:getTempZone())`（**观看 = 抽到自己这轮的临时区**）→ `while 区里还有牌` 反复 `game:askCardWithTarget(owner, '遗计', { zone = 该区, min = 1, max = 区里张数 })` → 答复为空（取消）就 `moveCard(区里剩下的, 手牌)` 并收尾。
  - 因此**整段不会剩牌**（分出去 / 取消归自己）⇒ **不需要**「置回牌堆顶 / 底」那套能力。
  - **这块临时区只指给郭嘉看**（用户 2026-10-09 定「用甲」）：`setVisible(郭嘉)` ⇒ 只有他看得见（官方「**你**观看」）。
- **顺带修订 `Zone:setVisible` 的语义**（用户同日定：「完全按照参数语义」）：扩成 **`boolean|Player|Player[]`** —— `true` = 所有人、`false` = 无人、给一名或一批角色 = **只有他们**；**`owner` 不再参与可见性**（去掉「暗区的持有者总能看见」这条潜规则）。连带：`@基础/牌堆.lua` 的 `手牌` 从 `setVisible(false)` 改成 `setVisible(各自的持有者)`；`Zone:bindOwner` 的说明回到「记下这个区属于谁」。
- **不新增询问类**：草稿里的 `askCardToPlayer` 不落地 —— 现有 `askCardWithTarget` 形状已覆盖（少一个对外契约，协议面不分叉）。
- **不新增可见性机制**：用户提的两个想法（① 秘密临时区、② 牌级临时展示）经讨论选**甲**= ① 的最小形式 —— 区级那对现成能力（`visible` + `isVisibleTo`）就是为此设计的；并**把 `setVisible` 的语义修对**（名单式，见下）。**牌级可见性（展示 / 覆盖）记成协议层那批的待办**（首个真需求是【反间】「展示一张手牌」）。
- **文档同步**：`sanguosha-rules` §9.24（收进【遗计】）、`architecture.md` 的 `askCardWithTarget` 行（首个「结算中的分配」消费者）、`progress.md`。

## Capabilities

### New Capabilities

无。本变更属探索期的**决策记录**，不写规格增量（`.openspec.yaml` 设 `skip_specs: true`）—— 理由见 `AGENTS.md`「工作流」。

### Modified Capabilities

无。`openspec/specs/` 已冻结、不回头改。**没有任何内核 / 协议面改动** —— 本变更纯内容侧（一个技能 + 用例），这也是「不必新开询问」的直接好处。

## Impact

- **内容侧**：`package/标准/武将/郭嘉.lua`（加【遗计】、`skills` 补成两个）。
- **用例**：`server/test/rule/hero-skill.lua`（遗计 4 条）。
- **文档**：`sanguosha-rules` §9.24、`moe-kill-dev/references/architecture.md`、`moe-kill-dev/references/progress.md`。
- **不动**：`server/core/**`（一问一行都不改）、协议层。
