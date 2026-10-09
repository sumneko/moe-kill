# Design

## Context

- 前后端已经能收发：`Client`（JSON-RPC 端点）+ `Link`（字节通道）+ 4 字节长度头的帧；`User`（座位控制者）骨架也在，11 个方法默认空实现。
- 还没有任何业务协议；`server/proto.d.lua` 已经写了形状（`Proto.Player` / `Proto.Custom` / `Proto.S2C.Notify.Player.Update`）。
- 内核现在**不认识**协议与连接（`architecture.md` §1 的硬约束），广播只能由**内核触发、传输层执行**。

## Goals / Non-Goals

**Goals**

- 内容侧能"把数据挂到玩家身上、指定给谁看"，且**一行协议都不写**。
- 这类变化最终以 `Player.Update` 下发到各客户端（每人一份，按视角裁剪）。
- 内核与传输层不互相依赖：内核只认 `player.user` 这个鸭子类型。

**Non-Goals**

- 增量更新（**客户端自己对比**；用户 2026-10-09 定，以后有优化需求再做）。
- 全量快照 / 重连（`Proto.SnapShot` 留着）。
- 选将等「要客户端输入」的协议。
- 超时。

## Decisions

### D1. 容器：`player.custom`

形状（用户 2026-10-09 给）：

```lua
local custom = moe.custom.create(player)   -- 建容器要玩家对象：默认可见性是「只有自己」
custom.proxy                                -- 内容侧读写的那张表（写它就进 raw + 标脏）
custom.raw                                  -- 真实数据
custom.hook = function (key, value) end     -- 变更监听（可选）
custom:setVisible(key, options)             -- 逐键可见性（Visibility：boolean | Player | Player[] | 谓词）
custom:isVisible(key, player)               -- 某玩家看不看得见这个键
custom:allVisibles(player)                  -- 某玩家看得见的所有键（组装协议用）
```

- 读写走 `proxy`（元表转发到 `raw`）；**写任何键**都：写 raw → 调 `hook` → 把 owner（玩家）**标脏**。
- 可见性**默认只有自己可见**（fail-closed：忘了设 = 不外泄）—— 与 `Zone:setVisible` 默认 `true` 不同（区是"人人可见的区"，容器是"默认私有的数据袋"）。
- 每次读写都过元表，代价可忽略（`cpu 瓶颈不会在这`，用户 2026-10-09）。

### D2. 置脏 + 一次调度合并（不引「帧」）

我们的内核没有「帧」，但有 `moe.await.wake(fn)`（登记到**下一笔调度**）：

- 改字段 ⇒ `player:markDirty()`：**第一次**标脏时 `moe.await.wake(flush)`，后续标脏只置标记；
- `flush()` ⇒ 收集所有脏玩家 ⇒ 组装并下发 ⇒ 清脏。

- **两类脏分开记**（用户 2026-10-10 定）：**基础信息**（`id` / `userName` / `seat`，由 `desk:sit` 这类内核动作标）与 **custom**（容器写键时标）；flush 时**各有脏才各发一条**。

⇒ 连改十个字段只发一条；同一个调度里改多个玩家也只发一条（一条消息里带多个玩家）。

### D3. 下发：`User:update(data)`

- 内核侧：`moe.player` 按**视角**组装（`id` / `userName` / `seat` 内核读，`custom` 走 `allVisibles(视角)`），交给 `player.user:update(data)`（`data.base?` / `data.custom?`）。
- `User:update` 基类**空实现**（不发），`ClientUser` 覆写成「有 `base` 发 `Player.Update`、有 `custom` 发 `Player.UpdateCustom`」。
- **没有 `user` 的玩家不回调**（AI / 未接线）；这正是「内容侧一行协议都不写」的落点：内核只认 `player.user`，不认识 `Client`。

### D4. 连接集合：`moe.clients`

`server/transport/clients.lua` 的 `Clients`：`add(client)`（返回 disposer）/ `remove` / 广播（`fun(client): params` ⇒ 每人一份）。门面 `moe.clients`。

- **内核不碰它**（`User` 才有 `client`）；本批里它主要给"将来接线"与测试用。
- 名字与 `moe.client`（单连接的门面）分开，不撞 `moe.server`（`session/` 那个待删的门面）。

### D5. 协议形状（`server/proto.d.lua`）

- **一类数据一条协议**（用户 2026-10-10 定）：`Player.Update` 管玩家**基础信息**（`id` / `userName` / `seat`），`Player.UpdateCustom` 管 `custom`（**全量**，客户端自己对比）；将来玩家身上再挂 Zone / Skill / Buff 时**各开一条**（`UpdateZone` / `UpdateSkill`…），别塞进同一条。
- `Proto.Player` 是**完整形状**（快照用：基础信息 + custom）；**更新类协议用更窄的形状** —— 建议在 `proto.d.lua` 里拆出 `Proto.Player.Base`（`Update` 用它、快照用 `Proto.Player`），待用户定。
- **`Proto.Custom` 在内核侧留空壳**，`heroName` / `heroSex` 这些**内容概念**由**包自己的 `meta.lua`** 补（「包自带 meta」机制，2026-09-21 定的）。
- 下发用 `Proto.S2C.Notify.Player.Update` / `…UpdateCustom`（都是**整份**、客户端自己对比）。
- 命名风格照用户给的：`S2C` / `Notify` / `点分名字`（与 `architecture.md` §3 里"域/动作"的旧写法不同，**以 `proto.d.lua` 为准**；§3 那句实现时顺手对齐）。

### D6. `Player.id`

建号用 `game:nextId()`（局内递增，与牌共用一个号源；`moe.player.create` 时给）。

### D7. 身份改住容器

`player.custom.identity`（可见性：自己 + 主公公开 ⇒ 由 `身份场` 设）+ 「坐下」时标脏。`身份场/{身份,胜负,选将}.lua` 跟着改读法（三处）。

## Risks / Trade-offs

- **全量下发**：每次变化推整份 `players`（含 custom），客户端自己对比 —— 简单、无状态；量大时再谈增量（已经预留 `Player.UpdateCustom` 的形状，本批不做）。
- **容器每次读写过元表**：可忽略；换来的是"内容侧写字段即同步"。
- **`moe.player` 组装协议**：内核开始认识 `Proto.*`（只是类型，不是方法）—— 这是「内核给出、传输层搬运」的必然；`Client` / `Link` 仍不被内核知道。

## Migration Plan

- 现有代码零破坏：`player.custom` 是新字段；身份从 `player.identity` 挪进容器（三处调用点一起改）。
- 新用例：容器（读写 / 可见性 / `allVisibles` / hook）、连接集合（登记 / 广播）、端到端（改字段 ⇒ 下一笔调度后对端收到 `Player.Update`，且**按视角裁剪**）。
- 后续批次：选将 `ask/hero`（第一条要输入的协议）、重连快照、增量。

## Open Questions

无 —— 用户 2026-10-09 已定：容器形状与默认可见性（fail-closed）/ 置脏 + 帧尾（一次调度）合并 / 不做增量 / 不做快照 / 广播只挂内核侧。
