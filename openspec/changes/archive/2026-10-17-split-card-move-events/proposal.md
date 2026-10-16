# Proposal

## Why

一次搬牌在**内核**里是**一步到位**的（`Zone:takeIn` 里摘 + 插 + 绑，中间不留「无主」态）—— 也就是说**没有「在途」状态**；可表现上客户端要演三段：牌从源区撤下 → 飞过去 → 落进目标区。现在 `Zone:notifyMoved` 把这次搬动**汇总成一条** `'卡牌-批量移动'`（在两段区域事件都发完之后），于是：

1. **客户端只能自己编这三段**：接到一条带 `from` / `to` 的通知，自己拍一个时长（`FLY_MS = 1000`）飞完再落位 —— 它必须与内容侧的节拍（`BEAT.moveCard = 1`）**手工对齐**（`动画.lua` 的注释就写着「数字照前端的动画时长定」），改一边就穿帮。
2. **「通知」与「等待」挤在同一个时机里**：节拍（内容侧订 `'卡牌-批量移动'` 调的 `animSleep`，里面直接 `coroutine.yield()`）与通知（`card-sync` 订的**同一个**时机）都挂在这条事件上，而 `SimpleEvent:fire` 是**同步顺序**跑回调 ⇒ 节拍订阅者（包加载期注册）排在 `card-sync`（客户端接入时才注册）之前，那次 `yield` 把后面那条 `Card.Move` 一起挂住。
   **实测（`server/log/service.log`）**：

   ```
   03:45:21.706 [flow] 搬牌 2 张：（无归属） → 手牌（player）
   03:45:22.707 [rpc] 发 Card.Move        ← 改前：相差 1001 ms，每一笔都如此
   ```

   用户看到的就是「点确定之后要等 1 秒这些牌才会出去」—— **连动画也一起晚**，因为动画是收到通知才播的。

## What Changes

把 `'卡牌-批量移动'` 拆成**三个时机**，夹在「离开 / 进入」两段区域事件之间：

| 时机 | 位置 | 谁订、做什么 |
| --- | --- | --- |
| `'卡牌-批量移动前'` | 两端区域事件**都还没发** | 协议层：发 `Card.Move`（撤下 + 起飞）+ `Card.Remove`（旧号作废） |
| `'卡牌-批量移动时'` | **离开发完、进入没发** | 内容侧：`animSleep`（服务器让出时间，客户端才有机会把这一段播出来） |
| `'卡牌-批量移动后'` | 两端区域事件**都发完** | 协议层：发 `Card.Create`（落位） |

- **「通知」与「等待」由此结构上分开** —— 谁先谁后不再取决于订阅注册顺序。
- **落位时刻改由服务端说了算**（`Card.Create`）：`FLY_MS` 不必再跟 `BEAT.moveCard` 手工对齐（飞早了就悬停，落位先到就加速收尾）。
- **「进 / 出」两段不对称是有意的**（用户 2026-10-17 拍）：离开的钩子立刻跑（「牌离开手牌」当场生效），进入的钩子在节拍**之后**跑（**牌飞到了才算进区**）。
- **账跟着两头走**：`User` 上新增 `removeCards` / `createCards` 两条出口；搬牌路径**不再走** `markDirty` 那笔 `moe.await.wake`，`updateCards` 只留「没换区」与**兜底换区**（`Zone:remove` / `clear` 这类没有搬动通知的归属变化）两类。
- **前端退掉一个补丁**：`client/src/state/agent.ts` 原先在 `Card.Move` 到场时自己删旧号（那是为了应付「`Card.Remove` 要等一秒」），现在 `Card.Remove` 紧跟着同一 tick 到，前端不必自己猜。

## Capabilities

### New Capabilities

无。

### Modified Capabilities

无。**时机 / 事件清单**虽属「对外契约」层，但 `openspec/specs/` 里**没有写它的活规格**（那批是探索期的历史快照），因此按项目先例（`add-judge` / `add-zhouyu` 改时机时同样只同步文档）设 `skip_specs: true`：可执行契约由用例承担（本例新增两条），文档同步写在 `moe-kill-dev/references/architecture.md` §16 与 `references/progress.md`。

## Impact

- 内核：`server/core/zone.lua`（`notifyMoved` 拆时机）、`server/core/loader/env-meta.lua`（时机声明换成三条）
- 协议层：`server/user/card-sync.lua`（拆订阅、加「在途」闸门、出口拆成 `sendRemoves` / `sendCreates`）、`server/user/user.lua` 与 `client-user.lua`（两条新出口）
- 内容侧：`package/@基础/动画.lua`（节拍改订「时」）
- 前端：`client/src/state/agent.ts`（退补丁）
- 用例：`server/test/core/zone.lua`（三时机顺序）、`server/test/user/card-sync.lua`（撤离在节拍之前 / 落位在节拍之后）
- 文档：`references/architecture.md` §16 与 §12 的 `accept` 一条、`references/progress.md`
- **破坏性（仅对内）**：订 `'卡牌-批量移动'` 的地方都要改到新名字上 —— 仓内只有 `card-sync` 与 `动画.lua` 两处，内容包目前没有别的消费者。
