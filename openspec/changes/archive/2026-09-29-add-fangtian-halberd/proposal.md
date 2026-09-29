# Proposal

## Why

装备技能的第一张（按「一张牌一个功能点」推进）。机制已齐、只差牌本身：

| 现状 | 影响 |
| --- | --- |
| 【方天画戟】只有定义（武器 / 攻击范围 4） | 「最后手牌放宽目标数」的官方效果未实现 |
| 地基三件已备好 | 牌『被动』（进槽启用 / 离槽停用 + disposer）、`CardDef:targetCount`（默认 1..1）、`Card:getTargetCount` 的「卡牌-目标数修正」收集点（`add-target-count`，2026-09-29） |

## What Changes

- `package/标准/卡牌/方天画戟.lua` 挂上技能：『被动』里订阅 `'卡牌-目标数修正'` —— 使用者是装备主 + 牌名是【杀】 + 此【杀】是其**最后手牌** ⇒ 返回 `+2`（最终上限 3，且不超合法目标数）；反注册函数交被动撤回（离槽即失效）。
- 用例（`rule/equip`）：正例两条（两名成立且区间 1..2；逐目标依次结算、互不影响——从 `rule/slash` 迁移的机制用例）+ **目标数量违规一组**：三名超合法数 / 不给目标 / 含不合法目标 / 不是最后手牌 / 没装备 / 拆下后 / 别的牌名 / 别人用的【杀】。
- 文档：`sanguosha-rules` §9.11（方天画戟移出「还没做」清单）、`progress.md`。

## Capabilities

### New Capabilities

无。

### Modified Capabilities

无新增对外契约（这是内容侧技能；机制在 `add-target-count` 已定）。探索期口径：本变更不写 `specs/`（`.openspec.yaml` 设 `skip_specs: true`）。

## Impact

- `package/标准/卡牌/方天画戟.lua`（技能）
- `server/test/rule/equip.lua`（用例一组 + 一个清手牌的辅助）
- 文档：`moe-kill-dev` 的 `references/progress.md`、`sanguosha-rules` 的 §9.11

## Non-goals

- 其余 9 张装备技能（各是一个功能点，依次推进）。
- 装备区的协议层表达（明牌 / 前端展示）。
