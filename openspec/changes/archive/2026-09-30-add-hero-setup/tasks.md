# Tasks

## 1. 内容侧：装配

- [x] 1.1 `package/@基础/武将.lua`（新）：`HeroDef:hp(maxHp, hp?)`（只存不兜底）+ `HeroDef:getHp()`（**依次取 定义 → `默认体力` → 5**，不给初始体力值就取上限）+ `Class 'Player'` 的 `setHero(hero)` —— 写 `hero` / `sex` / `kingdom` 与 `体力上限` / `体力`；体力在角色上的便捷读法 `Player:getHp()` / `getMaxHp()` / `getLostHp()`（缺失 = 上限 − 当前）；势力 / 性别 / 体力三样的链式写法、私有字段与读法（`kingdom` / `getKingdom` / `sex` / `getSex` / `hp` / `getHp`）都从内核搬到这里；内核那边只剩 `name` / `package` / `fullName` / `source` / `skillNames` / `values`（「定义本身」）
- [x] 1.2 `package/@基础/体力.lua`：`'游戏-开始'` 里只给**还没选武将**的角色写默认体力（`if not player.hero then`）；顶部说明补一句
- [x] 1.3 `package/@基础/meta.lua`：`---@alias 基础.势力 '魏'|'蜀'|'吴'|'群'` + `Player.hero? HeroDef` / `Player.kingdom? 基础.势力`（加在已有的 `Player` 块里，兜底签名保留）

## 2. 测试

- [x] 2.1 `server/test/rule/hero.lua`（新）：装上之后读到武将 / 势力 / 性别 / 体力上限与体力（`support.start` 之后 `setHero` 覆写默认值）/ **初始体力值不为上限**（探针武将 `hp(3, 1)`）/ **武将没写体力就用默认值** / **先选将再开局**（默认体力不覆盖）/ **主公 +1 叠在武将之上**（先给所有人 `setHero` → 开局 ⇒ 主公上限 = 武将上限 + 加成）/ 没选将时仍是默认体力；并在 `server/test.lua` 注册（顺手给 `support.start` 加了 `beforeStart` 钩子）；另加「**势力与性别的声明与读法**」（内容侧方法：声明 / 重复调以后写的为准 / 没声明就是空）与「**体力的声明与读法**」（只给上限 / 给初始值 / 重复调以后写的为准 / 没写就兜成 `默认体力`）两条
- [x] 2.2 `server/test/rule/base.lua` 加一条「**体力的便捷读法**」（满血时缺失 0 / 掉血后当前与缺失 / 抬上限后缺失跟着变大）

## 3. 验收

- [x] 3.1 `server/bin/moe-kill.exe --test` 全绿（789 用例 0 失败）
- [x] 3.2 问题面板 information 及以上清到 0
- [x] 3.3 同步文档：`references/architecture.md`（`Player:setHero` 行 + 装配顺序口径）、`references/progress.md`（§1 新条目 + 基线 + §2 武将那条）、`sanguosha-rules`（§9.14 补装配 + §1 里 `默认体力` 的定位）
