## MODIFIED Requirements

### Requirement: 上行方法清单

客户端 SHALL 能发这些请求：

| 方法 | 参数 | 结果 |
| --- | --- | --- |
| `Game.Join` | `{ name? }` | `Proto.SnapShot` |
| `Game.SnapShot` | 无 | `Proto.SnapShot` |
| `Game.Restart` | 无 | `{}`（只是收条：重建走 `Game.Restarted` 通知） |
| `Panel.Move` | `{ id, card, row, col }` | `{ success }` |
| `Skill.ChangeAuto` | `{ id, auto }` | `{ auto }` |

**询问的答复** SHALL 走**反向请求**（服务端发、客户端回结果）：`Ask.Select` / `Ask.Choice` / `Ask.Use` / `Ask.UseSkill` / `Ask.Hero` / `Ask.Panel` —— 形状各自在 `proto.d.lua` 里（`Proto.Request.Ask.*` / `Proto.Result.Ask.*`）。

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

服务端 SHALL 用通知下发变化：`Room.Update`、`Player.Update`、`Player.UpdateCustom`、`Player.UpdateAttribute`、`Card.Create`、`Card.Update`、`Card.Remove`、`Card.Move`、`Skill.Update`、`Skill.Remove`、`Panel.Create`、`Panel.Update`、`Panel.Remove`、`Turn.Begin`、`Turn.End`、`Phase.Begin`、`Phase.End`、`Game.Over`、`Game.Restarted`、`Cancel`。

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
