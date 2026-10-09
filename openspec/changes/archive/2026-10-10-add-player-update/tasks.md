# Tasks

## 1. 容器（`player.custom`）

- [x] 1.1 `server/core/custom.lua`：`Custom`（`proxy` / `raw` / `hook` / `setVisible` / `isVisible` / `allVisibles`；写键 ⇒ 进 raw + 调 hook + 标脏）；门面 `moe.custom`
- [x] 1.2 `Player` 挂 `custom`（构造时建）+ `markDirty()` / 脏标记；可见性默认「只有自己」
- [x] 1.3 用例：读写走 proxy / 默认只有自己可见 / 逐键设可见性（名单 / 谓词）/ `allVisibles` / hook 收到 (key, value)

## 2. 置脏 + 下发

- [x] 2.1 内核记**两类脏**（基础信息 / custom），第一次标脏登记一次 flush（`moe.await.wake`）；flush 收集脏、组装、下发、清脏（各有脏才各发一条）
- [x] 2.2 `moe.player` 按视角组装（`id` / `userName` / `seat` 内核读，`custom` 走 `allVisibles`）
- [x] 2.3 `User:update(data)`（基类空）；`ClientUser` 覆写成「有 `base` 发 `Player.Update`、有 `custom` 发 `Player.UpdateCustom`」；没有 `user` 的玩家不回调
- [x] 2.4 用例：改字段 ⇒ 下一笔调度后收到 `Player.UpdateCustom`；连改多个字段只发一条；按视角裁剪（别人的私有键看不到）；坐下 ⇒ 收到 `Player.Update`

## 3. 连接集合

- [x] 3.1 `server/transport/clients.lua`：`add` / `remove` / 广播（`fun(client): params`）；门面 `moe.clients`
- [x] 3.2 用例：登记 / 注销 / 广播各发各的载荷

## 4. 协议与身份

- [x] 4.1 `Player` 加 `id`（`game:nextId()`，`moe.player.create` 时给）
- [x] 4.2 `server/proto.d.lua`：`Proto.Custom` 收敛成**空壳**（内容概念挪进包）；按「一类数据一条协议」整理（更新类用窄形状）
- [x] 4.3 身份改住容器：`package/身份场/{身份,胜负,选将}.lua` 改读法；「坐下」时标脏；`Proto.Custom` 的字段补在内容包（身份在 `身份场/meta.lua`、武将牌面在 `@基础/meta.lua`）
- [x] 4.4 用例：既有身份 / 选将 / 胜负用例跟着改并通过（读法保留 `player.identity`，靠 `__getter` 转发 ⇒ 零改动）

## 5. 文档与验收

- [x] 5.1 `references/architecture.md` 新增一节（容器与 `Player.Update`）、§3 的命名风格与 `proto.d.lua` 对齐
- [x] 5.2 `references/progress.md` §1 条目 + 基线
- [x] 5.3 `SKILL.md` 目录表补 `server/proto.d.lua` 与 `clients`
- [x] 5.4 `server/bin/moe-kill.exe --test` 全绿、问题面板 information 及以上为 0
