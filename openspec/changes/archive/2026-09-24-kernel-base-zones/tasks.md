# Tasks

## 1. 内核：建五个基础区

- [x] 1.1 `server/core/game.lua`：`Game:__init` 里建两个公共区 `抽牌`（有序，`createZone('抽牌', true)`）/ `弃牌`（无序）；验证：`--test core.game` 新增用例「建局后两个公共区都在，抽牌是有序区」通过
- [x] 1.2 `server/core/player.lua`：`Player:__init` 里建三个玩家区 `手牌` / `装备` / `判定`（照旧走 `addZone`，`owner` 自动记上）；验证：新增用例「`moe.player.create` 出来就有三个区、且都归属于它」通过
- [x] 1.3 复核「先建区的顺序」：公共区在 `zoneList` / `zoneMap` 建好后不变量仍成立（`getZones()` 按创建顺序给出 2 个公共区，`player:getZones()` 给出 3 个）；验证：新增断言通过

## 2. 内核：结算的默认收尾

- [x] 2.1 `server/core/effect/effect.lua`：`bindFinish` 的 `finish()` 改成「`self.tempZone` 非空 ⇒ `fire('效果-收尾', self)`，**之后**把 `tempZone` 里剩下的牌同步送进 `game:getZone('弃牌')`」（`zone:list()` 是快照，直接 `zone:move(card, discard)`；不再起 `MoveCard` 效果）；验证：`--test core.effect` 新增用例「结完时临时区剩下的牌进弃牌区」通过
- [x] 2.2 同处：内容侧在 `'效果-收尾'` 里先搬走的牌，内核收尾不再动它（内核只清 `fire` 返回后还在临时区里的牌）；验证：`--test core.effect` 新增用例「先在收尾里搬走的那张不会被收尾动到」通过
- [x] 2.3 边界：没建过区的效果（`tempZone` 为空）照旧不发收尾、也不碰任何牌；验证：`--test core.effect` 既有用例「没要过区的效果不发收尾」仍通过

## 3. 内核：抽牌工具

- [x] 3.1 `server/core/game.lua`：新增 `game:drawCards(player, count, to?)` —— `to` 省略取 `player:getZone('手牌')`，`getZone('抽牌'):draw(count)` 取顶后 `game:moveCard(cards, to)`，返回**实际抽到的牌**；验证：新增用例「抽 2 张进手牌（堆少 2 张）」「给了 `to` 就进那块区」「堆不够时照实返回（可能是 0 张）」通过
- [x] 3.2 签名落在 `server/core/game.lua`（`env-meta.lua` 自己写着「Game 上其余入口的声明在 game.lua，别往这里抄一份」）：`drawCards` 带 `@async` 与 `@return Card[]`；验证：问题面板 0 问题、`--test` 通过
- [x] 3.3 三个调用点改用它：`package/@基础/抽牌.lua`（缩成一行）、`package/@基础/判定.lua`（抽 1 张到 `judge:getTempZone()`，`judge.card` 仍由它自己记）、`package/标准/卡牌/五谷丰登.lua` 的 `'结算前'`；验证：`--test rule.draw`、`--test rule.judge`、`--test rule.trick` 通过

## 4. 内容侧跟上

- [x] 4.1 `package/@基础/牌堆.lua`：删掉建区那几行，改成 `game:getZone('抽牌')` / `game:getZone('弃牌')` / `player:getZone('手牌')`；造牌、洗牌、标暗、`setShortageHandler` 全部不动；顶部那行功能说明同步改；验证：`--test rule.base`、`--test rule.setup` 通过
- [x] 4.2 `package/@基础/抽牌.lua`、`package/@基础/判定.lua`、`package/@基础/回合.lua`：改成直接取内核建的区，并去掉为此写的 `assert(...)` 一类防御（三处都去掉了）；验证：`--test rule.draw`、`--test rule.judge`、`--test rule.turn` 通过
- [x] 4.3 删除 `package/@基础/收尾.lua`（职责已被内核接管，proposal 里已列明）；验证：`--test rule.slash`、`--test rule.trick`、`--test rule.judge` 里「用过的牌 / 打出的杀 / 判定牌进了弃牌」仍通过

## 5. 用例跟上

- [x] 5.1 `server/test/core/**`（`can-use` / `effect.ask*` / `effect.draw` / `effect.play` / `game` / `player` / `zone`）里约 25 处 `game:createZone('弃牌' | '抽牌' | '手牌')`、`player:addZone('手牌' | '装备' | '判定')` 改成取内核建的区；验证：`--test core` 全绿
- [x] 5.2 `server/test/core/game.lua`、`server/test/core/zone.lua` 里「建同名区」的用例换成别的名字（例如 `'备牌'` / `'手牌区'`），保留它们原本要测的语义；验证：`--test core.game`、`--test core.zone`、`--test core.player` 通过
- [x] 5.3 新增：撞名再建报错 —— `game:createZone('弃牌')`、`player:addZone('手牌')` 都报错（包作者照旧写法会当场失败而不是静默覆盖）；验证：新增用例通过

## 6. 回归与文档

- [x] 6.1 全量回归：`server/bin/moe-kill.exe --test` ⇒ **496 用例 0 失败**（基线 490，本变更新增 6 条）
- [x] 6.2 复核行为等价四处（`inherit-temp-zone` 核对过的那四处）：打出的【闪】在该目标那次生效结束进弃牌、判定牌在该次判定结束进弃牌、【五谷丰登】亮出的牌在整次用牌结束进弃牌、顶层 `game:damage` 里打出的牌在该次伤害结束进弃牌 —— `rule.*` 里对应断言**不改一行**仍通过
- [x] 6.3 区名契约落成 `game.lua` / `player.lua` 里 `getZone` 的 `@overload`（这五个名字取出来是非空类型，内容侧不用再 `assert`），并在 `env-meta.lua` 头部补一行「五个基础区名由内核保证存在、包不得重建」；验证：问题面板 0 问题、`--test` 通过
- [x] 6.4 `references/architecture.md`：改掉「内核不预设任何区名 / 内核不知道弃牌堆叫什么」的表述（第 9 / 10 / 12 节与 `Draw` 的注释），写清新口径「**内核认这五个基础区名、认结算的默认收尾**，其余区名仍由内容侧定、其余时机仍只发信号」；第 12 节的机制表补 `game:drawCards` 一行；`references/progress.md` §1 补本变更、§2 / §3 相关条目同步
- [x] 6.5 问题面板 information 及以上清到 0（工作区级检查；不刷新就先跑 `lua.startServer`）

## 7. 收尾

- [x] 7.1 `openspec validate kernel-base-zones --strict` 通过
- [x] 7.2 `tasks.md` 全部勾选后归档：`openspec archive kernel-base-zones --yes`
