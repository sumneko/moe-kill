# Proposal

## Why

客户端要能「看到别人的体力」。玩家身上现在只有两路下行：基础信息（`Player.Update`）与自由数据（`Player.UpdateCustom`）；**属性（体力 / 体力上限）既没有可见性声明、也没有任何下行** —— 前端 `ui.ts` 只能从 `custom['体力']` 里捞，而 `custom` 的定位是「内容侧临时数据」。

属性与 `custom` 是两种东西：属性**有名字、有初值、内核自己在读**（体力参与濒死判定），取值由属性系统（`Attributes`）维护、变化自带事件。把它塞进 `custom` 等于让内容侧自己抄一份，还得自己记得同步。

## What Changes

- **属性单开一路下行**（与 `custom` 对称、互不影响）：
  - 玩家侧读法：`Player:setAttrVisible(name, options)` / `isAttrVisibleTo(name, viewer)` / `visibleAttributesTo(viewer)` —— **已落地**（另一台电脑 2026-10-15 的「暂存一下」），本变更只把它接完。
  - 协议：`Proto.Attribute = { name, value }`；`Proto.Player.attributes: Proto.Attribute[]`；通知 `Proto.Notify.Player.UpdateAttribute`（载荷 `{ players: Proto.Player.Attribute[] }`，每项 `{ id, attributes }`）—— **一条带一批玩家**，与 `Player.Update` / `Player.UpdateCustom` 同形（用户 2026-10-15 定）。
  - **数组不用 Record**（用户 2026-10-15 定）。
- **fail-closed**：没声明过可见性的属性一律不下发 —— **连本人也不见**（与 `custom` 同一口径）。
- **报脏**：首次 `setAttrVisible` 时顺手订上该属性的变更事件（值变了就报脏）；**可见性变化本身也算「这份数据变了」**（改完谁看得见之后线下得重发）。
- 组装沿用既有那套：按收件人视角裁、一个都看不见的玩家跳过、没有 `user` 的玩家不下发。
- 内容侧：`@基础/体力.lua` 把 `体力` / `体力上限` 声明成公开（三国杀里体力是公开信息）；前端席位改读 `player.attributes`。

## Capabilities

### New Capabilities

- `player-attributes`: 玩家属性的对外形状与下行 —— 逐属性可见性、`Proto.Attribute` 数组、`Player.UpdateAttribute` 通知、快照里的属性。

### Modified Capabilities

（无。）

## Impact

- **改动**：`server/proto.d.lua`（类型面）、`server/user/player-sync.lua`（flush 多一路）、`server/user/snapshot.lua`（快照带属性）、`client/src/{agent,ui}.ts`、`package/@基础/体力.lua`。
- **新增**（归档后）：`openspec/specs/player-attributes/`。
- **已就位**：`server/core/player.lua` 的 `setAttrVisible` / `isAttrVisibleTo` / `visibleAttributesTo`、`Player.DirtyKind` 的 `'attribute'`、`markDirty`。
- **测试**：内核（默认谁都不见 / 按名单 / 报脏）、通知（一条带一批 / 按视角裁 / 没 User 不发）、快照（带属性）。
- **对外契约**：这是 JSON-RPC 协议的新增（外部前端按它对接）⇒ 本变更写 `specs/` 增量，**不设** `skip_specs`。
