# Proposal

## Why

「效果」这一层的实现早就换了模型，规格还停在上一版：现在是 **Task 驱动 + 局上只增记牌器**（用户 2026-09-20 定：取消走 `reject`、失败只记 `.err` 不抛给调用方、`Effect:suspend` 整层删除），而 6 份主规格里还写着 `game:pushEffect` 的**结算栈**、`game:getCurrentEffect()`、`:wait()`、让出理由分派与「内核错误照常向外传播」。

规格是真相源，下一批功能（濒死与死亡要**插入**一次结算）会照着它做设计；留着旧模型，要么把已废弃的机制重新实现一遍，要么在实施时才发现规格是假的。这笔债现在只剩描述漂移 —— **代码一行不用改**，成本最低。

## What Changes

**`core-effect` 重写**（8 条需求里 6 条与实现不符）：

- REMOVED：`效果与结算栈`、`压栈与退栈`（`game:pushEffect` 已不存在）、`结算栈的查询`（`getCurrentEffect` 已不存在、`getEffects` 语义变了）、`让出与恢复`（`Effect:suspend` 整层已删）、`错误的传播`（内核错误不再抛给调用方）、`效果的完成信号与等待`（`:wait()` 已改名，且「挂起」「失败同时抛出来」两段是谎）
- ADDED：`效果与记牌器`（发起即登记、每个效果一个执行体 / 一个任务、嵌套深度上限 100）、`记牌器的查询`（`game:getEffect()` / `getEffects()` 按**发起顺序**的快照）、`效果的驱动与等待`（`:apply()` 驱动、`:await()` 等它结完、结果读 `.result`、失败读 `.err`、取消与超时算「没有结果」而不算失败）、`失败的记录`（内核错误不抛给调用方、记在 `.err` 上；内容包回调的错误按 `game-events` 隔离）
- MODIFIED：`效果的父子关系`（父 = **当前正在结算的效果**，在结算开始之前取自驱动这次结算的任务）、`即将生效与取消`（删掉「关闭一个挂起的结算」这类措辞）

**另 5 份规格同步措辞**（去掉「进结算栈 / 退栈 / 挂起 / 抛错」）：

- `core-damage`：伤害的结算不再「进结算栈、抛错后退栈」
- `core-play`：使用入口的「压入结算栈…退栈」、整段「挂起」描述、场景里的「栈恢复原状 / 查询结算栈」
- `core-response`：Purpose 与「询问」需求里的「从结算栈与效果链上查到」
- `core-decision`：决策询问的「进结算栈」措辞
- `core-move`：挪牌需求与场景里的「在结算栈上」

**Purpose 手改**（不在 delta 机制里，实施时直接编辑主规格）：`core-effect` 与 `core-response` 的 Purpose。

**技能文档同步**（同一笔债的另一半）：`moe-kill-dev/references/architecture.md` §12 接口表、`moe-kill-dev/SKILL.md` 目录表、`sanguosha-rules/SKILL.md` §7、`moe-kill-dev/references/code-style.md` §10、`moe-kill-dev/references/infrastructure.md` 的命令说明。

**MUST NOT 动代码**：这是纯规格与文档同步，`server/**` 一行不改，也不新增/修改用例。

## Capabilities

### Modified Capabilities

- `core-effect`: 结算栈模型整体换成「任务驱动 + 只增记牌器」——`pushEffect` / `getCurrentEffect` / `:wait()` / 挂起让出 / 错误向外传播都不再成立
- `core-damage`: 伤害的结算描述去掉栈
- `core-play`: 使用入口的栈与挂起描述
- `core-response`: 询问的栈描述
- `core-decision`: 决策询问的栈描述
- `core-move`: 挪牌的栈描述

## Impact

- 只动文档：`openspec/specs/**`（6 份）与 `.agents/skills/**`（5 处）；**代码与测试零改动**
- 影响后续设计：濒死 / 死亡（要靠效果嵌套与 `.err` 读法来做插入结算）、以及任何新增的效果类型
- 不改任何运行时接口，已有调用方不受影响
