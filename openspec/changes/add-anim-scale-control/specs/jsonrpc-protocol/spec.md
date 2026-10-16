# Spec Delta

## MODIFIED Requirements

### Requirement: 上行方法清单

客户端 SHALL 能发这些请求：

| 方法 | 参数 | 结果 |
| --- | --- | --- |
| `Game.Join` | `{ name? }` | `Proto.SnapShot` |
| `Game.SnapShot` | 无 | `Proto.SnapShot` |
| `Game.Restart` | 无 | `{}`（只是收条：重建走 `Game.Restarted` 通知） |
| `Game.SetAnimScale` | `{ scale }` | `{}`（**只有调试模式**下允许，见「调试模式与动画倍率」） |
| `Panel.Move` | `{ id, card, row, col }` | `{ success }` |
| `Skill.ChangeAuto` | `{ id, auto }` | `{ auto }` |

**询问的答复** SHALL 走**反向请求**（服务端发、客户端回结果）：`Ask.Select` / `Ask.Choice` / `Ask.Use` / `Ask.UseSkill` / `Ask.Hero` / `Ask.Panel` —— 形状各自在 `proto.d.lua` 里（`Proto.Request.Ask.*` / `Proto.Result.Ask.*`）。

**响应类询问** SHALL 通过 `Proto.ResponseTo` 把「这次响应冲哪次使用去的」一并交代（被响应的牌名 + 那次使用的使用者 + 目标），客户端据此能写出「打出一张 *X* → *Y*（A → B）」；不是响应的询问 MUST NOT 给这个字段。

**状态快照 SHALL 走请求的 `result`**，MUST NOT 走通知那条路（唯一的例外是 `Game.Restarted`：重开不是谁问出来的，见「下行通知清单」）。

#### Scenario: 入座时拿到一份快照

- **WHEN** 客户端发 `Game.Join`
- **THEN** 结果是一份 `Proto.SnapShot`（局面 + 他看得见的牌 + 技能 + 面板 + 展示用文本）

#### Scenario: 重连要一份全量

- **WHEN** 客户端发 `Game.SnapShot`
- **THEN** 同样拿回一份快照；客户端 SHALL 整份重建（不是叠加）

#### Scenario: 一条请求认出「谁在问」

- **WHEN** 一条请求到达，而这条连接已经入座
- **THEN** 服务端的处理器能拿到「这条连接是谁」（没开局 / 没入座则回 `-32600`）

#### Scenario: 重开后原班人马重坐

- **WHEN** 任一连接在**已经终局**的情况下发 `Game.Restart`
- **THEN** 服务端 SHALL 建新的一局（座位数 / 包清单 / 包来源沿用这一局、随机种子另取），让原先每个座位的人（同一条连接、同一个名字、同一个座位号）重新坐下，并给每个连接推一条 `Game.Restarted`
- **AND** 原班人马都坐上之后 SHALL **自动开局**（与「坐满就开局」同义）；原先一个座位都没人坐着时则不开局（新局停在等人齐）
- **AND** 这一局还没结束时发它 SHALL 回错（`-32600`，`message` 说明「这一局还没结束」），不做任何改动

### Requirement: 下行通知清单

服务端 SHALL 用通知下发变化：`Room.Update`、`Player.Update`、`Player.UpdateCustom`、`Player.UpdateAttribute`、`Card.Create`、`Card.Update`、`Card.Remove`、`Card.Move`、`Skill.Update`、`Skill.Remove`、`Panel.Create`、`Panel.Update`、`Panel.Remove`、`Turn.Begin`、`Turn.End`、`Phase.Begin`、`Phase.End`、`Game.Over`、`Game.Restarted`、`Game.AnimScale`、`Cancel`。

**一类数据一条通知**：同一笔调度里攒下的变化 SHALL 合并成一条（`Card.Create` 的亮出 / 背面各按区域成组、`Card.Update` 带一批牌 …），MUST NOT 一人一条或一牌一条。

**与视角无关的「时刻」SHALL 即时发**（`Turn.Begin` / `Turn.End` / `Phase.Begin` / `Phase.End` / `Game.Over` / `Game.Restarted`）—— 攒批会把两次切换压成一条，客户端就播不出节奏。

**看不见的东西不下发**：背面牌只给号不给面；没声明可见性的属性 / `custom` 字段谁也不发（连本人也不发）。

#### Scenario: 一批变化合并成一条

- **WHEN** 一批玩家的属性在同一笔调度里变了
- **THEN** 每个收件人各收到**一条** `Player.UpdateAttribute`（带着这批玩家）

#### Scenario: 时刻不攒批

- **WHEN** 一个回合结束、紧接着下一个回合开始
- **THEN** 客户端收到 `Turn.End` 与 `Turn.Begin` 两条，而不是合成一条

#### Scenario: 暗牌只有号

- **WHEN** 一张牌进了某个连接看不见内容的区
- **THEN** 那个连接收到它的号（能数得出区里有几张），但收不到牌面

#### Scenario: 重开时人人各拿一份新快照

- **WHEN** 一局结束、有人发了 `Game.Restart`
- **THEN** **每个连接**（含发起的那个）各收到一条 `Game.Restarted`，params 是一份**按他视角裁过的完整快照**（`Proto.SnapShot`，与 `Game.Join` 的回包同形状）；客户端 SHALL 据此整份重建界面（不是叠加）

## ADDED Requirements

### Requirement: 调试模式与动画倍率

服务端 SHALL 有一个**调试模式**：`--single` 启动时自动打开，`--debug` SHALL 也能显式打开（其余情况为关）。它 SHALL 作为门面字段（`moe.debug`）供服务端内部判断，MUST NOT 由协议或客户端指定。

内容侧的动画节拍走 `game:animSleep(秒)`，服务端 SHALL 按门面字段**动画倍率**（默认 `1`）缩放等待时长 —— 倍率是**时长乘数**（等 `秒 × 倍率`）：`0` SHALL 表示「没有动画」（当场返回，连一次调度都不让出），`1` = 按内容侧写的秒数，`2` = 等两倍久（更慢），`0.5` = 减半（更快）。

客户端 SHALL 能用 **`Game.SetAnimScale { scale }`** 请求改这个倍率；**只有调试模式**下 SHALL 允许（其它情况回 `-32600` 并在 `message` 里说明原因，且 MUST NOT 改动任何状态、MUST NOT 发通知）。允许时服务端 SHALL 把倍率记下来，并给**在座的每条连接**各推一条 **`Game.AnimScale { scale }`**。

快照（`Proto.SnapShot`）SHALL 带上「是不是调试模式」与「当前倍率」，客户端据此决定要不要给出调节入口；客户端据此**只影响界面**，MUST NOT 被当作服务端校验的依据。

#### Scenario: 只有调试模式能改

- **WHEN** 服务端不是调试模式，客户端发 `Game.SetAnimScale { scale = 0 }`
- **THEN** 服务端回 `-32600` 且 `message` 说明原因
- **AND** 倍率一点不动：后续的 `game:animSleep(秒)` 照旧按原倍率等待，也不发任何 `Game.AnimScale`

#### Scenario: 调试模式下改了就全体一致

- **WHEN** 服务端是调试模式（`--single` 或 `--debug`），客户端发 `Game.SetAnimScale { scale = 0.5 }`
- **THEN** 服务端把倍率记成 `0.5`，并给**在座的每条连接**各推一条 `Game.AnimScale`（`{ scale = 0.5 }`）
- **AND** 之后内容侧每次 `game:animSleep(秒)` 只等 `秒 × 0.5`

#### Scenario: 倍率 0 等于没有动画

- **WHEN** 倍率是 `0`，内容侧调 `game:animSleep(任意秒)`
- **THEN** 它当场返回（时钟一点不动）

#### Scenario: 入座就知道是不是调试模式

- **WHEN** 客户端发 `Game.Join`（或重连发 `Game.SnapShot`）
- **THEN** 快照里带着「是不是调试模式」与「当前倍率」

#### Scenario: 倍率不能是负数

- **WHEN** 客户端发 `Game.SetAnimScale { scale = -1 }`（即使在调试模式下）
- **THEN** 服务端回 `-32600`，倍率不变、也不广播
