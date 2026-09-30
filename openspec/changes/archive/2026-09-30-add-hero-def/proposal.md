# Proposal

## Why

武将系统是剩下最大的一块，但**先只做「武将定义」**（技能与装配下一批）—— 定义是后面所有东西的载体：体力上限 / 性别 / 势力现在都还写死在测试与身份场里（`身份场/开局.lua` 用规则数值 `默认体力` 给**没有武将**的开局定上限），而客户端要显示的武将牌面（姓名 / 势力 / 性别 / 体力 / 技能名）根本没有落点。

底本（《官方规则集》Chapter2/Section1）写明武将牌正面标识 **姓名 / 性别 / 势力 / 初始体力上限 / 武将牌的技能** 五样，Section4 还写明**初始体力值可以不等于体力上限**（高亮勾玉数）—— 这五样就是本批要的形状。

## What Changes

- 内核新增 **`HeroDef`**（`server/core/hero.lua`），形状照 `CardDef`：`name` / `package` / `fullName` / `source` + 牌面数据 + 通用数据袋。
- 环境里新增声明入口 **`Hero '曹操' : …`**（与 `Card` / `Buff` 并列），查询 `game:declareHero` / `game:getHero`（按包存、同包重名报错、只在加载期、随 `resetContent` 清空）。
- 牌面数据的写法（**链式**，读法照 `CardDef` 的一贯做法）：
  - `: kingdom '魏'` / `getKingdom()`（势力；取值由内容侧定）
  - `: sex '男'` / `getSex()`（性别）
  - `: hp(4)` 或 `: hp(3, 1)` / `getHp()` 返回两个值（初始体力上限、初始体力值；**不给第二个 = 与上限相同**）
  - `: skills { '奸雄', '护驾' }` / `getSkills()`（**技能名列表**，本批只是数据；技能定义与挂载下一批）
  - `: value(名字, 值)` / `getValue(名字)`（自带的数据，内核只存不解释）
- 内容侧落地两个武将做验证：`package/标准/武将/{曹操,刘备}.lua`。

## Capabilities

无。本变更属探索期的**决策记录**，不写规格增量（`.openspec.yaml` 设 `skip_specs: true`）。可执行契约由用例承担，见 `AGENTS.md`「工作流」。

## Impact

- 内核：新增 `server/core/hero.lua`；`server/core/game.lua`（`heroes` / `heroPackages` + `declareHero` / `getHero` + `resetContent`）；`server/core/init.lua`（装载顺序）；`server/core/loader/init.lua`（注入 `Hero`，真跑与预解析两处）；`server/core/loader/env-meta.lua`（注入项的类型声明）。
- 内容侧：`package/标准/武将/曹操.lua` / `刘备.lua`。
- 测试：新增 `server/test/core/hero.lua`（并在 `server/test/core/init.lua` 注册）。
- 文档：`references/architecture.md` / `progress.md` / `sanguosha-rules` 同步。
