## 1 调试模式（启动与门面）

- [x] 1.1 `server/args.lua`：加 `---@field DEBUG? boolean`，`M.current` 里 `result.DEBUG = result.DEBUG == true or result.SINGLE == true`
- [x] 1.2 `server/moe-kill.lua`：门面加 `moe.debug`（照 `moe.animScale` 的挂法）
- [x] 1.3 用例：`--single` 自动为真、`--debug` 显式开、都不给时为假

## 2 协议（对外契约）

- [x] 2.1 `server/proto.d.lua`：`Proto.Request.Game.SetAnimScale`（`{ scale: number }`，结果 `{}`）+ `Proto.Notify.Game.AnimScale`（`{ scale: number }`）
- [x] 2.2 `server/proto.d.lua`：`Proto.SnapShot` 加 `debug: boolean` 与 `animScale: number`

## 3 下行层（实现）

- [x] 3.1 `server/user/snapshot.lua`：快照塞 `debug` 与 `animScale`
- [x] 3.2 `server/room.lua`：注册 `Game.SetAnimScale` —— 非调试模式回 `-32600`；`scale < 0` 回 `-32600`；合法则改 `moe.animScale` 并给在座的每条连接推 `Game.AnimScale`
- [x] 3.3 用例：非调试模式拒（倍率不动、无广播）/ 调试模式生效并广播 / `0` 合法 / 负数拒 / 快照带两个字段

## 4 前端

- [x] 4.1 `--gen-proto` 重生成 `client/src/proto.d.ts`
- [x] 4.2 `client/src/state/agent.ts`：存 `animScale` 与 `debug`（快照初值 + 收 `Game.AnimScale`，`reset` 里归默认），加一个发 `Game.SetAnimScale` 的方法
- [x] 4.3 `client/src/debug/Drawer.ts`：加调节入口（`0` / `0.5` / `1` / `2` / `4`），非调试模式不显示

## 5 文档与规格

- [x] 5.1 活规格增量：`specs/jsonrpc-protocol/spec.md`（上行清单 + 下行清单 + 新增 requirement）
- [x] 5.2 `architecture.md` 里「动画节拍」那条把「不涉及对外契约」改口
- [x] 5.3 `progress.md` §1 记一条

## 6 收尾

- [x] 6.1 后端测试全绿（**1325 用例 / 0 失败**）
- [x] 6.2 检查问题面板（information 及以上清零）
- [x] 6.3 浏览器真链路：调试模式下在抽屉里改倍率 ⇒ 按钮状态跟着广播变（`0.5×` 变 disabled、`1×` 变可点）、事件流出现「动画倍率改成 0.5」
