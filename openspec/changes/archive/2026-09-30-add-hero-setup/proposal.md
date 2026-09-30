# Proposal

## Why

上一批（`add-hero-def`）只做了「武将定义」这个载体 —— 武将牌面的五样数据（姓名 / 性别 / 势力 / 体力上限 / 技能名）现在只是躺在那儿的定义，**没有任何路径把它交给一名角色**：`player.sex` 至今没人写、势力没有落点、体力上限还是 `@基础/体力.lua` 用规则数值 `默认体力` 一刀切给所有人。

## What Changes

- 新文件 **`package/@基础/武将.lua`**：给 `Player` 加 **`setHero(hero)`** —— 把武将装到这名角色身上：写 `player.hero`、`player.sex`、`player.kingdom`，并把武将的**初始体力上限与初始体力值**写进属性。
- **落点在内容侧**（不是内核）：要写「体力上限」「体力」这两个**属性名**，而属性名是内容侧的（内核不预设属性名）⇒ 照 `@基础/距离.lua`（`Player:distance`）/ `@基础/装备.lua`（`Player:equipCard`）的先例，用 `Class 'Player'` 给玩家加方法。
- **`@基础/体力.lua` 的默认值加兜底**：`'游戏-开始'` 里只给**还没选武将**的角色写默认体力 ⇒ 「先选将」与「后选将」两种顺序结果一致。
- **`@基础/meta.lua`** 补类型：`基础.势力` 别名 + `Player.hero` / `Player.kingdom`。
- **势力 / 性别 / 体力的声明与读法都住 `@基础/武将.lua`**（`HeroDef:kingdom` / `getKingdom` / `sex` / `getSex` / `hp` / `getHp`）：内核 `HeroDef` 只剩「定义本身」（姓名 / 技能名 / 自带数据），取值口径（`默认体力`、兜底 5）与势力 / 性别 / 体力这类牌面词全归内容侧。
- **体力在角色上的便捷读法**（也在 `@基础/武将.lua`）：`player:getHp()`（当前体力）/ `getMaxHp()`（体力上限）/ `getLostHp()`（缺失的生命 = 上限 − 当前，官方「已损失体力值」）。
- **装配顺序的口径**：`setHero` 用 `setAttr` **覆写**基础上限 ⇒ 装配方应当**先选将、后走开局流程**（身份场的「主公 +1」是 `addAttr` 增量，排在后面才对）；这条写进文档与 `sanguosha-rules`。技能挂载**本批不做**（技能系统下一批接进 `setHero`）。

## Capabilities

无。本变更属探索期的**决策记录**，不写规格增量（`.openspec.yaml` 设 `skip_specs: true`）。可执行契约由用例承担，见 `AGENTS.md`「工作流」。

## Impact

- 内容侧：新增 `package/@基础/武将.lua`；`package/@基础/体力.lua`（兜底）；`package/@基础/meta.lua`（类型）。
- 内核：`server/core/hero.lua` 删掉 `kingdom` / `getKingdom` / `sex` / `getSex` / `hp` 与 `kingdomName` / `sexName` / `maxHp` / `initialHp` 四个私有字段（搬去内容侧）；其余不动（`HeroDef` 的字段 / `game:getHero` 形态照旧）。
- 测试：新增 `server/test/rule/hero.lua`（并在 `server/test.lua` 注册）。
- 文档：`references/architecture.md` / `progress.md` / `sanguosha-rules`（§9.14 补装配）。
