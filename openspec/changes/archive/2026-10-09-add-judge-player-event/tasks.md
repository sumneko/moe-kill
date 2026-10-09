# Tasks

> 本批 = **判定对判定者再发一份 + 郭嘉【天妒】+【洛神】改订**（用户 2026-10-09 定：「先做天妒，添加玩家对象事件，把洛神也一起改了」）。**【遗计】另批。**

## 1. 判定两份

- [x] 1.1 `package/@基础/判定.lua`：`fireReplaceWindow` 与 `Judge:settle()` 里，全局那份之后对 `judge.player` 再发一份（同名；文件头一行说明）；验证：`--test rule.judge` 全绿
- [x] 1.2 `package/@基础/meta.lua`：补判定的 `Player.on` / `fire` 收窄（载荷 `Judge`，注明「对判定者再发一份、同名」）
- [x] 1.3 类型面三块：`SkillDef` / `CardDef` 各加 `event('判定-前')` / `event('判定-后')`（`globalEvent` 那两条保留）；验证：问题面板 information 及以上 0

## 2. 内容：郭嘉【天妒】

- [x] 2.1 新建 `package/标准/武将/郭嘉.lua`：`Hero '郭嘉'`（魏 / 男 / 3 体力 / `: skills { '天妒' }`）+ `Skill '天妒'`（`auto(true)` + `event('判定-后')` + `tryCast` 里 `moveCard(judge.card, 手牌)`）；文件顶部照 §9.3 写官方描述
- [x] 2.2 `package/标准/武将/甄姬.lua`：【洛神】`globalEvent('判定-后')` → `event('判定-后')`（**保留** `judge.reason == '洛神'`）

## 3. 用例

- [x] 3.1 `server/test/rule/judge.lua`：两个时机各对判定者再发一份（全局先、当事人后、旁人收不到）+ 当事人那份也在改判窗口里
- [x] 3.2 `server/test/rule/hero-skill.lua`：天妒三组（自己的判定拿到手 / 别人的判定不要 / 不发动就照常进弃牌堆）
- [x] 3.3 全量 `server/bin/moe-kill.exe --test` 0 失败（报出基线数：967 → 971）；洛神既有 4 条一行未改、全绿

## 4. 验收与文档

- [x] 4.1 `sanguosha-rules`：§9.8 判定（两份 + 表格的「谁用」列）、§9.15 硬口径 (a)（按文本管谁的来选订哪份）、【洛神】条目更新、新增 §9.24 郭嘉【天妒】
- [x] 4.2 `moe-kill-dev/references/architecture.md`：§12 方向词规则那条加判定（同名两份那一类）+ 判定行补「两份」
- [x] 4.3 `moe-kill-dev/references/progress.md`：§1 记账 + 基线 971；§2 的武将表郭嘉行与缺口表更新
- [x] 4.4 收尾清单过一遍：问题面板 0、硬约束自查（命名 / 注释 / 键的落点）、停在待确认状态
