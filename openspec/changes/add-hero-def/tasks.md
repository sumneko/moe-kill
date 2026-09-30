# Tasks

## 1. 内核：武将定义

- [x] 1.1 `server/core/hero.lua`（新）：`HeroDef` 类 —— 字段 `name` / `package` / `fullName` / `source` + 私有的 `kingdomName` / `sexName` / `maxHp` / `hpValue` / `skillNames` / `values`；方法 `kingdom` / `getKingdom`、`sex` / `getSex`、`hp(maxHp, hp?)` / `getHp()`（返回两个值）、`skills(names)` / `getSkills()`（快照）、`value(name, value)` / `getValue(name)`
- [x] 1.2 `server/core/init.lua`：`include 'core.hero'`（排在 `core.game` 之前）
- [x] 1.3 `server/core/game.lua`：字段 `heroes` / `heroPackages`；`declareHero(name)` / `getHero(name)`（照 `declareBuff` / `getBuff`：只在加载期、按包存、同包重名报错、裸名带包内作用域）；`resetContent` 里一并清空

## 2. 装载器

- [x] 2.1 `server/core/loader/init.lua`：真跑注入 `Hero = function (name) return game:declareHero(name) end`；预解析的 stub 里 `Hero = function () end`（武将声明**不参与**条目校验，同 `Buff`）
- [x] 2.2 `server/core/loader/env-meta.lua`：注入项 `Hero`（`fun(name: string): HeroDef`）

## 3. 内容侧

- [x] 3.1 `package/标准/武将/曹操.lua`：`Hero '曹操' : kingdom '魏' : sex '男' : hp(4) : skills { '奸雄', '护驾' }`
- [x] 3.2 `package/标准/武将/刘备.lua`：`Hero '刘备' : kingdom '蜀' : sex '男' : hp(4) : skills { '仁德', '激将' }`

## 4. 测试

- [x] 4.1 `server/test/core/hero.lua`（新）：声明与读回（势力 / 性别 / 技能名）/ `hp(4)` ⇒ 初始 = 上限、`hp(3, 1)` ⇒ 3、1 / `value` 数据袋 / 同包重名报错 / 加载之外声明报错 / 裸名与限定名查询 / 重装后清空 / 名字含 `.` 报错；并在 `server/test/core/init.lua` 注册
- [x] 4.2 同上的套件里加一条：标准包的两个武将查得到（端到端的最小验证）

## 5. 验收

- [x] 5.1 `server/bin/moe-kill.exe --test` 全绿（781 用例 0 失败）
- [x] 5.2 问题面板 information 及以上清到 0
- [x] 5.3 同步文档：`references/architecture.md`（内容定义入口的表 + `HeroDef` 行）、`references/progress.md`（§1 新条目 + 基线 + §2 里武将那条）、`sanguosha-rules`（新增 §9.14 武将定义 + §10 待确认口径里武将范围那条）
