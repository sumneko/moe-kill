# Tasks

## 1. 内核：技能定义

- [x] 1.1 `server/core/skill.lua`（新）：`SkillDef` 类 —— 字段 `name` / `package` / `fullName` / `source` + 私有的 `kindName`（默认 `'主动'`）/ `tagSet`；方法 `kind(发动方式)` / `getKind()`、`tags(名字|名字[])`（并集）、`hasTag(名字)`（「觉醒技」派生）、`getTags()`（快照）—— **字段与方法不同名**（同行 `HeroDef`：字段私有 + 链式写 + 方法读）
- [x] 1.2 `server/core/game.lua`：`skills` / `skillPackages` 两个私有字段（`__init` 与 `resetContent`）+ `declareSkill(name)` / `getSkill(name)`（照 `declareHero` / `getHero`）
- [x] 1.3 `server/core/init.lua`：`include 'core.skill'`
- [x] 1.4 加载器：`loader/init.lua` 真跑注入 `Skill = function (name) … end`、试跑 stub `Skill = function () end`；`loader/env-meta.lua` 声明 `---@type fun(name: string): SkillDef`

## 2. 测试

- [x] 2.1 `server/test/core/skill.lua`（新）：声明与读回（名字 / 包名 / 完整名 / 来源）/ **不写发动方式就是「主动」** / 显式写「被动」/ 标签声明与 `hasTag` / 没声明就是没有 / `getTags` 快照 / **「觉醒技」派生锁定技与限定技** / 同包重复声明报错 / 名字带点号报错 / 加载之外不能声明 / 清空内容后没了 / 裸名与限定名都能查 / **技能名与牌名、武将名互不冲突**
- [x] 2.2 `server/test/core/init.lua`：注册新套件

## 3. 验收

- [x] 3.1 `server/bin/moe-kill.exe --test` 全绿（801 用例 0 失败）
- [x] 3.2 问题面板 information 及以上清到 0
- [x] 3.3 同步文档：`references/architecture.md`（内容定义入口表加 `Skill` / `SkillDef` 行）、`references/progress.md`（§1 条目 + 基线 + 包表格）、`sanguosha-rules`（新增 §9.15 技能定义 + §10 的技能范围那条）
