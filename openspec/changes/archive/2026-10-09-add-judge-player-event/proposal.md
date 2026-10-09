# Proposal

## Why

判定只有一个全局时机（`'判定-前'` / `'判定-后'`），于是「**你的**判定牌」类技能只能订全局那份、再在回调里自己筛 `judge.player`：

```lua
Skill '洛神'
    : globalEvent('判定-后', function (skill, judge)     -- 订的是全局那份
        if judge.player ~= skill.owner then return end  -- 于是得自己认领
        ...
    end)
```

而项目已有一条成熟口径（2026-09-30 定）：**时机在全局之外，对当事人再发一份**（`'阶段-开始'`、`'效果-收尾'`、伤害 / 治疗的来源 / 承受两侧、`'卡牌-来源-指定目标后'` …）。判定缺这一份。

郭嘉【天妒】（「当**你的**判定牌生效后，你可以获得之」）正是这类技能的典型，本变更顺带把它落地 —— 并把已有同类技能【洛神】一起改过来。

## What Changes

- **判定两条时机各发两份**（`package/@基础/判定.lua`）：全局那份之后，对 **`judge.player`** 再发一份。
  - **同名**（`'判定-前'` / `'判定-后'`）—— 判定没有「来源 / 目标」之分可用，归入「同名两份」那一类（与 `'阶段-开始'` / `'效果-收尾'` 同类）。
  - **顺序**：全局先、当事人后（照既有口径）。
- **类型面**：`package/@基础/meta.lua` 补 `Player.on` / `fire` 的判定两条收窄；`SkillDef` / `CardDef` 各补 `event('判定-前')` / `event('判定-后')`（`globalEvent` 那两条**保留** —— 「一名角色的判定」那种仍订局）。
- **郭嘉（新武将，只做【天妒】）**：`package/标准/武将/郭嘉.lua` —— `auto(true)` + `event('判定-后')` + `tryCast` 里把判定牌搬进手牌（判定牌还在该次判定的临时区里，赶在内核收尾送弃牌之前）。
- **【洛神】改订自己那份**：`globalEvent('判定-后')` → `event('判定-后')`，**保留** `judge.reason == '洛神'` 筛选（自己的判定里还有【闪电】【乐不思蜀】与别人的技能引发的那一些）。

## Capabilities

### New Capabilities

无。本变更属探索期的**决策记录**，不写规格增量（`.openspec.yaml` 设 `skip_specs: true`）—— 理由见 `AGENTS.md`「工作流」。

### Modified Capabilities

无。`openspec/specs/` 已冻结、不回头改；其中也没有描述判定时机份数的条目。

## Impact

- **内容侧**：`package/@基础/判定.lua`（两个时机各发两份）、`package/@基础/meta.lua`（类型面）、`package/标准/武将/郭嘉.lua`（新）、`package/标准/武将/甄姬.lua`（洛神改订）。
- **用例**：`server/test/rule/judge.lua`、`server/test/rule/hero-skill.lua`。
- **文档**：`sanguosha-rules`（§9.8 判定两份、§9.15 口径、新增 §9.24 郭嘉）、`moe-kill-dev/references/architecture.md`（方向词规则那条 + 判定行）、`moe-kill-dev/references/progress.md`。
- **不动**：`'判定-前'` 的改判窗口语义、【鬼才】的全局订阅、协议层。【遗计】另批。
