# Proposal

## Why

客户端需要能表达**自己的行为偏好**（不是牌局规则、也不是技能开关）：第一批就是「无懈可击不响应自己的锦囊」—— 自己用出去的锦囊，默认不必再问自己要不要拿【无懈可击】去抵消。

现在协议里没有任何「客户端 → 服务器」的配置通道：`Player.Custom` 是**内容侧**自由数据（客户端改不了），`Skill.ChangeAuto` 只针对单个技能的自动开关。这类偏好还应当是**人的**属性：同一个人换座位、重开一局都该带着，而不该跟着某一局的座位走。

## What Changes

- 新概念「**玩家设置**」：内核只做机制（定义表 + 取值 + 协议），条目由**内容侧声明**（以后别的包也能加自己的设置）。
- 设置挂在 `User`（连接级）：同一个连接重开一局后**沿用原来那份**（底层存连接上，`User` 只是门面）；`Player:getSetting(名字)` 提供只读转发，内容侧不必认识 `User`。
- 协议新增三条（对外契约）：
  - `Proto.Setting = { name, value, default, describe? }`；快照里带 `settings: Proto.Setting[]`（本人全量）。
  - 上行 `Settings.Change { settings: Record<名字, 值> }` ⇒ `{ settings: Proto.Setting[] }`：只收**已定义**的键（未知键 `-32602` 拒收），只改本人。
  - 下行 `Settings.Update { settings: Proto.Setting[] }`：只发给本人。
- 内容侧新增 `package/@基础/设置.lua`，声明第一条：`无懈可击不响应自己的锦囊`（默认**启用**）。
- 【无懈可击】的询问窗口按这条设置跳过自己：使用者本人不再被问「要不要无懈自己的锦囊」。
- 前端：顶栏保留，「重新同步」「调试抽屉」在**非调试模式**隐藏（按快照的 `debug`），顶栏放一个「设置」按钮，点开一张小卡片逐条勾选，改完立即 `Settings.Change`。

## Capabilities

### New Capabilities

- `player-settings`: 玩家设置的对外形状（定义 / 取值 / 默认值）与协议（快照、上行、下行），以及「挂在人身上、跨重开保留」的口径。

### Modified Capabilities

- `jsonrpc-protocol`: 上行方法清单、下行通知清单各加一条（`Settings.Change` / `Settings.Update`），并说明快照里的 `settings`。

## Impact

- **改动**：`server/core/game.lua`（`defineSetting` / `getSettingDefault` / `listSettings`）、`server/core/player.lua`（`getSetting` 转发）、`server/user/user.lua`（设置袋 + `getSetting` / `updateSettings`）、`server/user/settings-sync.lua`（新增：上行处理器 + 下发）、`server/user/snapshot.lua`（快照带 `settings`）、`server/proto.d.lua`、`package/@基础/设置.lua`（新增）、`package/@基础/卡牌/无懈可击.lua`。
- **前端**：`client/src/state/agent.ts`（设置状态 + `changeSettings`）、`client/src/view/App.ts`（顶栏：设置按钮 + 调试按钮按 `debug` 隐藏）、设置卡片组件。
- **对外契约**：这是 JSON-RPC 协议的新增（外部前端按它对接）⇒ 本变更写 `specs/` 增量，**不设** `skip_specs`。
- **测试**：内核（定义 / 默认值 / 未知键 / 未定义取值）、协议（快照带全量、上行只改本人、未知键拒收）、规则（设置开启时自己的锦囊不问自己；关闭时照问）。
