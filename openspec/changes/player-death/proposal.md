# 玩家存活与死亡时机 + 桌子的属性式读取

## Why

「杀」已经能造成伤害，但**伤害之外什么都不会发生**：没有「谁还活着」这个概念（伤害可以把体力打成负数而无人过问），规则包也没法知道有人死了（奖惩、胜负判定、以「存活角色」为范围的牌都缺个落脚点）。同时桌子的座位列表是个 getter 方法（`desk:getPlayers()`），与「局上只认字段」的口径（`game.desk` / `game.random`）不一致。

## What Changes

- **玩家有存活状态**：`player:isAlive()`（默认活着）与 `player:setAlive(值)`。**从活变死**时触发局的 **`'玩家-死亡'` 时机**（上下文 = 这个玩家）；重复置死不再触发，复活之后可以再死一次。
- **玩家与桌子知道自己的局**：局建立时把局交给桌子（`desk:bindGame(game)`），桌子转交给座位上已有的玩家；**局建立之后再入座**的玩家同样在入座时拿到。⇒ 规则包与流程在任何时候都能靠玩家的状态发出死亡时机。
- **桌子提供两个列表字段**：`desk.players`（按座位号升序，含不参与行动者）与 `desk.alivePlayers`（按座位号升序，只含还活着的角色）。**每次读取现算、不缓存** ⇒ 死亡之后立刻反映；原 `desk:getPlayers()` 删除。
- **本批不做**：濒死流程（体力归零 → 求桃 → 才判定死亡）、死亡结算 / 奖惩 / 胜负判定、死亡与「参与行动」标记的联动（`isActing` 仍由调用方处置）。

## Capabilities

### Modified Capabilities

- `core-desk`: 座位列表改成**属性式读取**（`desk.players`）；新增**存活角色列表** `desk.alivePlayers`（现算、不缓存）
- `core-player`: 新增**存活状态**（`isAlive` / `setAlive`）与**死亡时机**的触发口径，以及「玩家在入座或局建立时获得所属局」

## Impact

- **内核**：`server/core/player.lua`（`alive` 字段 + `isAlive` / `setAlive` / `bindGame`）、`server/core/desk.lua`（`__getter` 的两个列表 + `bindGame` + 删除 `getPlayers`）、`server/core/game.lua`（建局时 `desk:bindGame(self)`）、`server/core/loader/env-meta.lua`（`'玩家-死亡'` 的重载）。
- **规则包**：`package/@基础/{体力,攻击范围,牌堆}.lua`、`package/身份场/开局.lua` 改读 `game.desk.players`；`package/标准/卡牌/杀.lua` 改读 `desk.alivePlayers`。
- **测试**：`server/test/core/{desk,player,game,play}.lua`、`server/test/rule/setup.lua`。
- **文档**：`architecture.md`（§12 的例子、§10 的「内核侧订阅不能用 `game:on`」）、`sanguosha-rules` §7/§9.2。
