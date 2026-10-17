# Proposal

## Why

动画节拍（`game:animSleep(秒)` + 门面字段 `moe.animScale`）是 2026-10-15 落的，用来给客户端留出播动画的时间。当时的结论是**「前端不需要任何新消息（服务器只是慢一点）⇒ 不涉及对外契约」**，倍率只能由宿主 / 测试在启动时写死（`server/test.lua` 设 0）。

实际调试时的痛点是：想看一整局的节奏（1 秒的打出节拍、0.1 秒的阶段切换）就得**从头看着它慢慢跑**；想让 AI 自己快速跑一遍，只能重启进程改代码。缺的是**运行期可调**。

另一头：这样的开关**不能让普通玩家用**（对局中加速 = 作弊级的体验差异），所以它必须挂在「服务器现在是不是调试模式」上 —— 而这个概念目前**根本不存在**（`args.lua` 只有 `SINGLE`，`main.lua` 拿它守在「现在只支持单局模式」那行）。

## What Changes

- **服务器加「调试模式」**：`args.lua` 推导出 `Args.DEBUG` —— `--single` 启动时**自动为真**，另外 `--debug` 可显式打开（将来 lobby 模式也能开）。落到门面字段 `moe.debug`（与 `moe.animScale` 同一种挂法：内核级、跨局、不参与重载）。
- **协议加两条方法**（这是本批的对外契约部分）：
  - `Game.SetAnimScale { scale }` ⇒ 回 `{}`。**只有调试模式**下才允许（否则回 `-32600`，`message` 说明原因，倍率一点不动、也不广播）；合法则把 `moe.animScale` 改成 `scale`。
  - `Game.AnimScale { scale }` ⇒ 服务端**广播**给所有连接。`moe.animScale` 是**服务器全局一份**（一个 VM 一局），一个客户端改了全体节奏都变，各客户端的界面得跟着知道。
- **快照带上两个字段**：`Proto.SnapShot` 加 `debug: boolean` 与 `animScale: number` —— 入座与重连一次拿到，客户端据此决定要不要给调节入口、当前是多少。
- **前端接线**：`agent` 存 `animScale`（初值来自快照，之后跟 `Game.AnimScale` 走）；调试抽屉（`client/src/debug/Drawer.ts`）里加一个调节入口（`0` / `0.5` / `1` / `2` / `4`），**非调试模式不显示**。
- **前端动画时长不跟着缩**：`anim.ts` 的 `FLY_MS` / `App.ts` 的 `420` / `Hand.ts` 的 `MOVE_MS` 一行不改 —— 既定口径是「服务器只是慢一点」，倍率调小 ⇒ 服务器等得短、动画被下一批动作打断，这正是调试想要的。

## Capabilities

### New Capabilities

（无）

### Modified Capabilities

- `jsonrpc-protocol`:
  - 「上行方法清单」加 `Game.SetAnimScale`（并写明它只在调试模式下可用）；
  - 「下行通知清单」加 `Game.AnimScale`；
  - 新增一条 requirement「调试模式与动画倍率」（怎么判定、快照怎么带、非调试模式怎么拒、倍率 0 的语义）。

## Impact

- **启动与门面**：`server/args.lua`（`Args.DEBUG` + `M.current` 的推导）、`server/moe-kill.lua`（`moe.debug`）。
- **协议**：`server/proto.d.lua`（`Proto.Request.Game.SetAnimScale` / `Proto.Notify.Game.AnimScale` / `Proto.SnapShot` 两个字段）⇒ **要重跑 `--gen-proto`**，`client/src/proto.d.ts` 重生成。
- **下行层**：`server/room.lua`（注册 `Game.SetAnimScale` + 广播）、`server/user/snapshot.lua`（快照塞两个字段）。
- **前端**：`client/src/state/agent.ts`（存倍率 + 收通知）、`client/src/debug/Drawer.ts`（调试抽屉里的入口）。
- **测试**：`server/test/room.lua` 补协议层用例（非调试模式拒 / 调试模式生效并广播 / 快照字段）；`server/test/proto-type.lua` 补断言。
- **文档**：`architecture.md` §（动画节拍那条）要把「不涉及对外契约」改口；`progress.md` §1 记一条。
- **不在本次范围**：不做「按客户端分别记倍率」（一份全局值就够）；不动内容侧的节奏点与数字；不给倍率设上限（只拒负数与非数字）。
