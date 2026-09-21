# Design

## Context

动机见 `proposal.md` 的 Why。这里只记动手前需要的事实（都已按代码与用例核实过，来源同一批实现提交）：

- **实现侧的事实**（`server/core/effect.lua`、`server/core/game.lua`、`server/tools/task.lua` 与 `server/test/core/effect.lua`）：
  - 效果由 `moe.task` 驱动：`apply()` 里建任务并立即执行，`settle()` 的返回值就是任务结果；`Effect.result` / `Effect.err` 是两个 getter，读的是任务上的结果与失败。
  - 局上只有 `---@field private effects Effect[]`（注释即「记牌器：发起过的根效果（只增）」）+ `addEffect` / `getEffect`（最近发起过的那一个）/ `getEffects`（按发起顺序的快照）。**嵌套的内层不单独记**（它是外层的子效果）。
  - 深度是效果自己的字段：`deep` 从 1 开始，`addChildEffect` 里父 +1；`apply()` 里 `deep > 100` 时报「效果嵌套过深」（失败记 `.err`，不抛）。
  - `remove()` = `Delete(self)` → `__del` 里 `task:reject(CANCELED)`，因此在**未开始 / 已结束**的效果上都是空操作（用例「不在结算中或已经结束的效果不能取消」钉住）。
  - 失败不抛给调用方（用例「失败记在 err 上，不抛」）：错误记 `.err`、交给任务的错误处理器（生产 = 日志，测试 = `lt.errors`），错误信息带出错位置。取消不算失败、不交给错误处理器。
  - `Effect:suspend`、`game.suspender`、`enterWaiting`、「挂起期间不能起新结算」都已删除；等待由任务承担，应答方在时机回调里直接让出（用例「应答方可以让出后再答复」）。
- **规格侧的现状**：`openspec/specs/` 里 6 份规格仍按旧的「结算栈」模型描述（`core-effect` 8 条需求里 7 条与实现不符）。
- **OpenSpec 的机制约束**（本次实测）：delta 里**同名**的 REMOVED + ADDED 会被 `openspec validate` 直接判错（`Requirement present in both ADDED and REMOVED`）；MODIFIED 块**不能改名或删掉已有场景**（`omits scenario(s) the current spec still has`），只能改 WHEN/THEN 与正文、或新增场景。
- 项目既有先例：语义**反转**时用 REMOVED（带 Reason/Migration）+ ADDED 新名字（`card-zone-ownership`）；需求名没坏、只是场景名/正文过期时，保留旧场景名、只改 WHEN/THEN，并在正文把真实语义写清（`player-death` 的「参与行动标记可置位与清除」）。

## Goals / Non-Goals

**Goals:**

- 6 份主规格与实现一致：读规格能直接得出「效果 = 任务驱动 + 只增记牌器」这件事，不再出现已删除的接口（`pushEffect` / `getCurrentEffect` / `:wait()`）。
- 每一步改动的**理由可追溯**：哪条需求为什么被摘掉、迁移到什么，都写在 delta 的 Reason/Migration 里。
- 归档后主规格**不留空壳**：`core-effect` 仍有实质需求（7 条），`core-damage` / `core-play` 的需求名与场景名不缩水。
- 代码与测试**零改动**。

**Non-Goals:**

- 不顺手改任何行为（哪怕规格读起来"更想这样"）：本次只让文档追上代码。
- 不重构 `core-effect` 的接口命名（`:await()` / `:apply()` / `remove()` 保持现状）。
- 不补 `core-decision` / `core-response` 之外的新能力，也不动 `turn-flow` 等其它规格。

## Decisions

### D1：按「需求名是否还成立」分三种处理

- **需求名与语义都反转了** → REMOVED + ADDED：`core-effect` 里 7 条（结算栈 / 压栈与退栈 / 结算栈的查询 / 让出与恢复 / 错误的传播 / 效果的完成信号与等待 / 即将生效与取消）。
- **需求名仍成立、只有正文与个别场景过期** → MODIFIED（保留全部旧场景名）：`core-effect` 的「效果的父子关系」、`core-damage` 的「造成伤害」、`core-play` 的「使用入口」「结算与牌的去向」「逐目标生效」、`core-response` 的「询问与应答」、`core-decision` 的「决策询问」、`core-move` 的「把牌挪进某个牌区」。
  - 先按「同名 REMOVED + ADDED」写，被 `openspec validate` 判错，改成 MODIFIED（见 D2）。
  - 两个场景名（`伤害结算期间在栈上`、`使用失败或抛错后栈恢复原状`）里的「栈」字已成历史名词，但场景名不能改 ⇒ 保留名字，把 THEN 改成事实，并**在需求正文里写明现在没有结算栈、只有记牌器**，避免读者按名字误解。
- **一条需求里混了两件事** → 拆成两条 ADDED：`core-effect` 的「即将生效与取消」拆成 **「即将生效的时机」**（触发时机本身）与 **「取消一次生效」**（`remove()` 的语义与作用域）。这样「取消是幂等空操作」这条准确结论能落在一个名字不撒谎的需求上，而不是塞进名字写着"被拒绝"的旧场景。

**Alternatives**：① 全部用 MODIFIED、连名字都不改（会把「结算栈」这类已废弃名词永久留在需求名里）；② 全部 REMOVED + ADDED（`core-play` / `core-damage` 的需求名本来是对的，白白改名会让主规格的引用点全部失效）。

### D2：不碰同名 REMOVED + ADDED

`openspec validate --strict` 会报 `Requirement present in both ADDED and REMOVED`，且同一个名字放进 ADDED 也无法表达「改名」以外的语义（我们真正要的是"内容换成准的"，不是"换一条新需求"）。⇒ 需求名没坏就用 MODIFIED。

### D3：把「实测事实」写进规格而不是只写在文档里

`getEffect()` 是「最近发起过的根效果」而**不是**「正在结算的效果」—— 这是最容易让后续实现写错的一点（用例名里也还留着「结束就清掉」这种旧说法）。规格里为此单列场景：**「结算结束后仍留档」**（`core-effect` 的「记牌器的查询」）与 `core-damage` 的「伤害结算期间在栈上」（改 THEN 后明确写「结束后它仍留在记牌器里」）。

### D4：Purpose 手改，不走 delta

`core-effect` 与 `core-response` 的 Purpose 整段是按旧模型写的。OpenSpec 的 delta 对已有能力**忽略** `## Purpose`（工具指引明确要求直接编辑主规格）⇒ 这两处列为 tasks 里的手工步骤，并在改完后跑 `openspec validate --all --strict` 确认。`core-effect` 的 Purpose 里也不能再有「TBD」占位（该能力早已存在）。

## Risks / Trade-offs

- [摘掉 7 条需求后再归档，`core-effect` 的需求数从 8 掉到 7（拆出来 6 条新的）] → 归档后立刻跑 `openspec validate --all --strict` 与 `openspec show core-effect --type spec`，确认没有空需求、没有 TBD 占位、没有孤儿场景。
- [把「证据」落在谁身上：本次引用的"用例钉住了这一点"若将来用例改名就会失效] → 规格正文只描述行为，不写用例名做依据；依据留在 design 与提交信息里。
- [文档漂移是"改了也看不出来"的工作，容易半途而废] → tasks 按文件逐条拆（6 份规格 + 5 处技能文档 + 2 处 Purpose），每条都能单独核对，最后以 `validate --all --strict` 与一次人工通读收尾。
- [下一步（濒死/死亡）依赖这批规格的准确性] → 本次收尾时把「效果可嵌套、父/深度可读、失败读 `.err`、入口自动驱动+等」这四条在 `sanguosha-rules` §7 里点名，作为后续设计的输入。

## Migration Plan

纯文档变更，没有运行期迁移：不涉及数据、接口或调用方。回滚 = 还原这些 markdown 文件（主规格的旧版本在 git 历史里；delta 与归档记录同样保留在 `openspec/changes/**`）。归档后旧模型只存在于 `openspec/changes/archive/2026-09-21-add-effect-suspend/` 这类历史目录中，是**有意留档**，不要再回头改。
