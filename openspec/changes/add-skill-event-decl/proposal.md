# Proposal

## Why

技能里**绝大多数**「被动」钩子其实只做一件事：订阅一个时机、发动时做点什么。

```lua
Skill '集智'
    : auto(true)
    : on('被动', function (skill, host)                       -- 内核机制层
        local owner = skill.owner
        host:bindGC(owner:on('卡牌-结算前', function (useCard) -- 生命周期层
            ...                                                -- 技能真正想说的
        end))
    end)
```

三层里只有最后一层是内容（条件与「要不要发动」都在那儿）。`'被动'` 那一层要求内容侧知道「怎么订阅」；`host:bindGC` 那一层要求它知道「技能停用时谁负责撤」—— 两件都是内核机制。（**「先 `confirm` 后 `cast`」的顺序问题已由 `Skill:tryCast` 解决，与本变更无关。**）

「视为」已经走过这一步（`add-view-as`：从写在 `'被动'` 里 → `: viewAs(...)` 声明，内核在 `applyPassive` 里照声明挂、`host:bindGC` 管生命周期）。本变更把**同一件事对「订阅时机」再做一遍**。

## What Changes

- **`SkillDef:event(名, 回调)` / `SkillDef:globalEvent(名, 回调)`**（可多次调）—— 声明式订阅时机：
  - `event` 订在**技能主人头上**（`owner:on`）、`globalEvent` 订在**局上**（`game:on`）。
  - 技能启用时内核照声明挂上（`host:bindGC(…)`）、停用 / 离场 / 被克制自动撤 —— 与 `viewAs` 声明共用同一套生命周期。
  - **只做订阅**：载荷与返回值原样转给回调（第一参补上技能自己）；**要不要发动（`skill:tryCast(…)`）与条件仍由回调自己写** ⇒ 与手写 `on('被动')` + `host:bindGC(owner:on(…))` 等价，省的只是那两层壳。
  - 回调签名 `fun(skill: Skill, ...: any): any`（第一参是技能自己，照 `'被动'` 收 `(skill, host)` 的惯例）。
- **`'被动'` 仍然保留**：它承载的是「**启用时做点什么**」（`addAttr` / `addLimit` 这类持续性修正：【马术】【咆哮】），不是时机订阅。
- **两条口径**（写进文档）：
  1. `event` 订自己 / `globalEvent` 订局，**不可互换**（【鬼才】的 `'判定-前'`、洛神的 `'判定-后'` 都是订局）；
  2. **条件写在 `tryCast` 之前** —— `event` 只转发、内核不替技能问，所以「不满足条件就不问」照旧成立（把条件挪到询问之后会让无关触发也被问一次）。
- **武将技能全迁**（11 处订阅：奸雄 / 集智 / 奇才 / 克己 / 铁骑 / 鬼才 / 反馈 / 刚烈 / 裸衣 / 洛神×2）；装备侧（`CardDef`）另批。
- 类型面：`SkillDef` 的 `event` / `globalEvent` 按名收窄 —— **内核**时机的候选在 `loader/env-meta.lua`，**内容侧**时机（伤害 / 治疗 / 判定）的候选同步补进 `package/@基础/meta.lua`。

## Capabilities

### New Capabilities

无。本变更属探索期的**决策记录**，不写规格增量（`.openspec.yaml` 设 `skip_specs: true`）—— 理由见 `AGENTS.md`「工作流」：探索期只留决策记录，可执行契约由用例承担。

### Modified Capabilities

无。`openspec/specs/` 已冻结、不回头改；其中也没有描述「技能怎么订阅时机」的条目。

## Impact

- **内核**：`server/core/skill.lua`（两个声明 + `Skill:applyPassive()` 照声明挂）。
- **内容侧**：`package/标准/武将/**`（11 处订阅迁移）、`package/@基础/meta.lua`（本包时机的 `event` / `globalEvent` 候选）。
- **类型面**：`server/core/loader/env-meta.lua`。
- **用例**：`server/test/core/skill.lua`。
- **文档**：`moe-kill-dev/references/architecture.md` §12、`sanguosha-rules/SKILL.md` §9.15、`moe-kill-dev/references/progress.md` §1。
- **不动**：装备侧（`CardDef`，另批）、协议层。
