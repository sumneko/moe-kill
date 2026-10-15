# 设计与取舍

## 形状

```
moe.room.restart()
 ├─ 校验：有局 且 已经终局（否则回错：还没开局 / 这一局还没结束）
 ├─ 从**旧局**读出班底与配置（不另存一份状态）
 │    座位号 = 1..desk:getCount()；名字 = player.name；连接 = player.user.client
 │    seats = desk:getCount()；packages = game.list；sources = game.sources；seed = 上一局 seed + 1
 ├─ moe.room.open { … }                    ← 建新局（已有入口，内部还会 moe.snapshot.attach）
 ├─ 原班人马重坐：新 Player + 新 ClientUser(同一连接) → sit → setUser → attach()
 ├─ moe.roomSync.broadcast(game)           ← 座位表
 └─ 每个连接推一条 Game.Restarted（带他那份快照）
```

## 关键决策

**D1 「换局」而不是「重置局」。** 沿用 2026-09-21 定的口径（`add-game-over` 的 D7）：再开一局 = 建新的 `Game` 实例。于是**不需要任何「清理旧局」的代码** —— 所有下行账要么挂在局上（`game.cardSync` 这份账本本身是局上的 `package` 字段），要么挂在 per-user 的 View 上，旧局一没人引用就整坨回收。

**D2 班底与配置从旧局读，不另存。** `moe.room` 不再多存一份 `_options`：座位数在 `desk`、名字在 `player`、连接在 `player.user.client`、包清单在 `game.list`、来源在 `game.sources`。唯一没处放的是 `seed` ⇒ 单独存一个 `moe.room._seed`（`open` 时记下实际用的那个）。

**D3 种子 +1（不是沿用）。** 沿用同种子会让每一局**完全一样**（单局模式本来就是固定种子 ⇒ robot 冒烟可复现），玩第二遍毫无意义；另取（+1）既保持「同配置同包」，又能让牌局不同，同时**仍然可复现**（想看第 N 局就 `seed = 初始种子 + N - 1`）。

**D4 重建走通知，不走回包。** 触发者只有一个人，可重开影响的是**每个连接**（都要整份重建）。所以：`Game.Restart` 的回包只表示「指令收到」（`{}`），重建一律走 `Game.Restarted` 通知（含触发者自己那份）—— 一条路径，不因「谁点的」而分叉。通知可能先于回包到达，两边互不依赖。

**D5 从 `join` 里抽出「造人 + 坐」。** `join` 现在是「找空座 → 造 Player/ClientUser → sit → setUser → attach → （坐满）开局」。重开要的是同一段逻辑（只是座位已经指定）⇒ 抽一个局部函数 `seatPlayer(game, index, client, name)`，两处共用。

**D6 前端「再入座」= 清状态 + 应用快照。** `applySnapshot` 目前是「整份重建」的语义（2026-10-10 定）⇒ 收到 `Game.Restarted` 直接复用它（但要把 `over` 清掉、询问清空，这些 `applySnapshot` 是否已经做，实施时核实）。

## 影响面

| 面 | 改动 |
| --- | --- |
| 协议 | `proto.d.lua` 加 `Proto.Request.Game.Restart` 与 `Proto.Notify.Game.Restarted`（**对外契约** ⇒ 本变更写 specs 增量、不设 `skip_specs`） |
| 宿主 | `server/room.lua`（`restart` + `seatPlayer` + `_seed`） |
| 前端 | `client/src/agent.ts`（`restart()` + 处理 `Game.Restarted`）、`client/src/ui.ts`（按钮）、`client/src/robot.ts`（局终自动重开） |
| 类型产物 | `server/bin/moe-kill.exe --gen-proto` 重生成 `client/src/proto.d.ts`（`server/test/proto-type.lua` 钉一致性） |
| 用例 | `server/test/room.lua`（重开：座位与名字保持 / 配置与包沿用 / 种子上一次 +1 / 新局能跑 / 没终局就回错）、`server/test/user/*`（通知发出 + 快照形状） |
| 文档 | `architecture.md` §17、活规格 `openspec/specs/jsonrpc-protocol/spec.md`（归档时合入）、`progress.md` |

## 验证

- 无头用例全绿（新增 + 既有）。
- **反向验证**：把「没终局就回错」的守卫去掉 ⇒ 对应用例该红；把快照推送去掉 ⇒ 对应用例该红。
- **真链**：4 个机器玩家**连跑多局**（≥3 局）—— 每局结束自动重开、座位与名字保持、无报错、内存不涨。
