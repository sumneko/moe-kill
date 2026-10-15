# 任务

## 1 协议声明

- [x] 1.1 `server/proto.d.lua`：加 `Proto.Request.Game.Restart`（无字段）与 `Proto.Notify.Game.Restarted`（`Proto.SnapShot`）
- [x] 1.2 重生成前端类型：`server/bin/moe-kill.exe --gen-proto`，确认 `client/src/proto.d.ts` 有这两个类型
- [x] 1.3 `server/test/proto-type.lua` 补一条钉住新类型（形状与 `Game.Join` 的回包同源）

## 2 宿主：重开一局

- [x] 2.1 `server/room.lua`：`open` 时把实际用的 `seed` 记进 `moe.room._seed`
- [x] 2.2 从 `join` 里抽出「造人 + 坐 + attach」为局部函数 `seatPlayer(game, index, client, name)`，`join` 改用它（行为不变）
- [x] 2.3 新增 `moe.room.restart()`：校验（有局 + 已终局）→ 读旧局的班底与配置 → `open { seed = 上一局 + 1 }` → 原班人马重坐 → `roomSync.broadcast` → 给每个连接推 `Game.Restarted`（带他那份快照）→ **原班人马都坐上就自动开局**（延后一笔调度）
- [x] 2.4 注册 `Game.Restart` 处理器（没开局 / 没终局各回 `-32600` 带说明）

## 3 前端

- [x] 3.1 `client/src/agent.ts`：`restart()`（发 `Game.Restart`）+ `onNotify('Game.Restarted', …)` 按整份重建处理（清掉 `over` 与在途询问）
- [x] 3.2 `client/src/ui.ts`：终局横幅旁加「再来一局」按钮
- [x] 3.3 `client/src/robot.ts`：局终后自动发一次重开（小延时），并记一条日志

## 4 用例

（4.1~4.4 写在同一条用例里，它一次跑完：班底 / 配置 / 种子 + 新局能跑）

- [x] 4.1 `server/test/room.lua`：重开后**座位号与名字保持**
- [x] 4.2 同上：**配置与包沿用**（座位数 / 包清单 / 来源）
- [x] 4.3 同上：**种子另取**（上一局 + 1）
- [x] 4.4 同上：新局**能正常跑**（开局、回合、终局）
- [x] 4.5 同上：**没终局就重开 ⇒ 回错且什么都没改**（旧局还在、座位没动）
- [x] 4.6 `server/test/user/*`：每个连接各收到一条 `Game.Restarted`，params 是按他视角裁过的快照（写在 `test/room.lua` 里，用 `moe.client.register` 拦通知）
- [x] 4.7 反向验证：去掉「没终局」守卫 ⇒ 4.5 红；不推快照 ⇒ 4.6 红

## 5 规格与文档

- [x] 5.1 `openspec validate add-game-restart --strict` 通过
- [x] 5.2 `architecture.md` §17（协议入口）补 `Game.Restart` / `Game.Restarted` 与「换局即回收」的口径
- [x] 5.3 `progress.md`：§1 新条、§2 候选表（「会话 / 协议」那行去掉本项）、交接状态

## 6 收尾

- [x] 6.1 全量测试 0 失败、问题面板 information+ 清到 0
- [x] 6.2 真链：4 个机器玩家**连跑 ≥3 局**（座位与名字保持、无报错、内存不涨）—— `service.log` 实证连跑 4 局（种子 2 / 3 / 4），内存看护全程无告警
- [x] 6.3 `openspec validate --all --strict` 全绿
