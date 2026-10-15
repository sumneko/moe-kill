# Tasks

## 1. 协议类型面

- [x] 1.1 `server/proto.d.lua`：`Proto.Attribute`（`{ name, value }`）、`Proto.Player.attributes`、`Proto.Player.Attribute`（`{ id, attributes }`）、`Proto.Notify.Player.UpdateAttribute`（`{ players }`，一条带一批）。验证：`server/core/player.lua` 的 `visibleAttributesTo` 不再报「未定义的类型 `Proto.Attribute`」
- [x] 1.2 `server/bin/moe-kill.exe --gen-proto` 重新生成 `client/src/proto.d.ts`。验证：生成文件里出现 `Attribute` 与 `UpdateAttribute`

## 2. 下行接线

- [x] 2.1 `server/user/player-sync.lua`：flush 多一路属性（按收件人视角用 `visibleAttributesTo` 裁；一个都看不见就跳过；没有 `user` 的玩家不发）。验证：用例「属性变了收到 Player.UpdateAttribute」「一条带一批」
- [x] 2.2 `server/user/snapshot.lua`：`toPlayer` 带 `attributes`。验证：用例「快照带上看得见的属性」

## 3. 内容侧

- [x] 3.1 `package/@基础/体力.lua`：`体力` / `体力上限` 声明公开（必须写在写值之前）。验证：真实开局的快照里每个玩家都带这两条

## 4. 客户端

- [x] 4.1 `client/src/agent.ts`：接 `Player.UpdateAttribute`（按 `id` 更新 `player.attributes`）
- [x] 4.2 `client/src/ui.ts`：席位体力 / 体力上限从 `player.attributes` 读（不再从 `custom` 捞）。验证：与 `--gen-proto` 生成的 `Proto.Player.attributes` / `Proto.Notify.Player.UpdateAttribute` 逐处对照（**本机没装前端依赖，`tsc` 没跑**）

## 5. 用例

- [x] 5.1 内核 `server/test/core/player.lua`：默认谁都不见 / 声明后按名单 / 值变化报脏 / 未声明的变化不报脏 / 可见性变化也报脏
- [x] 5.2 `server/test/user/client-user.lua`：通知形状（一条带一批 / 按视角裁 / 没 User 不发）
- [x] 5.3 `server/test/user/snapshot.lua`：快照带属性、看不见的不出现

## 6. 收尾

- [x] 6.1 全量验收：`server/bin/moe-kill.exe --test` 全绿（报出基线数）
- [x] 6.2 问题面板 information 及以上 0
- [x] 6.3 文档：`references/architecture.md`（§15 容器那段 + 下行表）、`references/progress.md`（§1 / §3 与基线）、`sanguosha-rules`（体力是公开信息的口径）
