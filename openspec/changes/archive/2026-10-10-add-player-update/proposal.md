# Proposal

## Why

`Client` 能收发消息了，但**还没有任何一条真正的协议**：客户端不知道自己是几号位、是谁、有哪些同伴。开局流程里这些信息（坐次 / 身份 / 武将）现在只存在于后端，得先有一条「把人看得见的信息推下去」的通路。

而「哪些信息给谁看」这件事，规则层最清楚（主公的身份公开、其余背面朝上）—— 所以做法是：**玩家身上挂一个容器**（`player.custom`），内容侧往里面写数据、给每个键设可见性；**字段一改就置脏，帧尾统一推一次** `Player.Update`（该玩家可见的那份 `players` 列表），客户端自己对比新旧。

广播接口**只在内核侧**（连接集合挂在 `moe.clients`），内容侧只碰 `player.custom` —— 规则代码里一行协议都不出现。

## What Changes

- **容器 `custom`**（内核，绑在玩家上）：`player.custom` 是内容侧读写的表（`proxy`），背后有 `raw` 数据、变更监听 `hook`、以及**逐键可见性**（`setVisible(key, options)` / `isVisible(key, player)` / `allVisibles(player)`）。**默认只有自己可见**（fail-closed）；可见性直接用内核已有的 `Visibility`（`boolean | Player | Player[] | fun(player): boolean`）。
- **置脏 + 帧尾合并**：改容器里的字段只把该玩家**标脏**；第一次标脏时登记一次 flush（`moe.await.wake` ⇒ 下一笔调度），flush 把所有脏玩家一起推掉、清脏 —— 连改十个字段只发一条，也不引入「毫秒 / 帧」概念。
- **连接集合**（`server/transport/clients.lua`）：登记 / 注销 / 广播（`fun(client): params` 形状 ⇒ 每人一份，各自裁剪）。门面 `moe.clients`。内核不认识它，只认 `player.user`。
- **下发走 `User:update(players)`**：基类空实现，`ClientUser` 覆写成 `client:notify('Player.Update', { players = … })` ⇒ 内核（`moe.player`）只认鸭子类型的 `user`，`Player` 上没有 `user` 的（AI / 未接线）**不回调**。
- **协议**（`server/proto.d.lua`）：**一类数据一条协议** —— `Player.Update` 发玩家**基础信息**（`id` / `userName` / `seat`）、`Player.UpdateCustom` 发 `custom` **全量**（客户端自己对比）；将来玩家身上再挂 Zone / Skill / Buff 时**各开一条**。`Proto.Custom` 在内核侧**只留空壳**，`heroName` / `heroSex` 这类内容概念由**包自己的 `meta.lua`** 补（「包自带 meta」机制）。
- **`Player` 加 `id`**：建号用 `game:nextId()`（与牌共用一个号源）。
- **身份改住容器**：`player.custom.identity`（+ 可见性），`身份场` 里那几处（`setIdentity` / `isIdentityVisibleTo` / 胜负 / 选将）跟着改读法；「坐下」时把那人标脏。
- **本批不做**：增量更新（客户端自己对比）、全量快照（`Proto.SnapShot` 留给重连那批）、选将询问（下一条协议）、超时。

## Capabilities

### New Capabilities

无。本变更属探索期的**决策记录**，不写规格增量（`.openspec.yaml` 设 `skip_specs: true`）。理由见 `AGENTS.md`「工作流」。将来 `Player.Update` 这条对外契约若要冻结，再单独开一次写规格。

### Modified Capabilities

无。`openspec/specs/` 已冻结，不回头改。

## Impact

- 内核：新增容器（`server/core/custom.lua`，`Player` 上挂 `custom` 字段 + `Player:markDirty()` / flush 入口）；`Player` 加 `id`；`moe.player` 侧组装 `Proto.Player`。
- 传输：新增 `server/transport/clients.lua`（连接集合）。
- 用户层：`User:update(players)`（基类空）；`ClientUser` 覆写（对接 `Client`）。
- 内容侧：`package/身份场/{身份,胜负,选将}.lua`（读法改成容器）；`package/标准/meta.lua`（补 `Proto.Custom` 的字段）。
- 协议：`server/proto.d.lua`（类型声明；`Proto.Custom` 收敛成空壳）。
- 测试：新增容器用例、连接集合用例、「改字段 ⇒ 下一笔调度收到 `Player.Update`」的端到端用例（两张内存 Link、一个假前端）。
- 文档：`references/architecture.md`（新增一节：容器与 `Player.Update`）、`references/progress.md`、`SKILL.md` 目录表（`server/proto.d.lua` / `clients`）。
