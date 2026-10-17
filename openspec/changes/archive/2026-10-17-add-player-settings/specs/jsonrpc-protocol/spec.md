# jsonrpc-protocol Specification（增量）

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
| `Settings.Change` | `{ settings: Proto.Settings }` | `{ settings: Proto.Setting[] }` |

**询问的答复** SHALL 走**反向请求**（服务端发、客户端回结果）：`Ask.Select` / `Ask.Choice` / `Ask.Use` / `Ask.UseSkill` / `Ask.Hero` / `Ask.Panel` —— 形状各自在 `proto.d.lua` 里（`Proto.Request.Ask.*` / `Proto.Result.Ask.*`）。

**响应类询问** SHALL 通过 `Proto.ResponseTo` 把「这次响应冲哪次使用去的」一并交代（被响应的牌名 + 那次使用的使用者 + 目标），客户端据此能写出「打出一张 *X* → *Y*（A → B）」；不是响应的询问 MUST NOT 给这个字段。**多目标结算时**（如【南蛮入侵】【桃园结义】逐个目标生效）SHALL 另给 `target`（= 正在生效的那个人）—— 客户端用 `target` 代替整张牌的目标列表，提示里只拼「使用者 → 当前目标」；`targets` 仍是一整份，供需要全貌的客户端使用。

**玩家设置** SHALL 通过 `Settings.Change` 修改，参数 `Proto.Settings` 是「名字 → 值」的自由表（只改带上去的键）。服务端 MUST 只接受已声明的键：出现未知键 SHALL 回 `-32602` 并且**整包不生效**。结果 SHALL 是这名玩家的全量 `Proto.Setting[]`。

**状态快照 SHALL 走请求的 `result`**，MUST NOT 走通知那条路（唯一的例外是 `Game.Restarted`：重开不是谁问出来的，见「下行通知清单」）。

#### Scenario: 入座时拿到一份快照

- **WHEN** 客户端发 `Game.Join`
- **THEN** 结果是一份 `Proto.SnapShot`（局面 + 他看得见的牌 + 技能 + 面板 + 展示用文本 + 他自己的设置）

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

#### Scenario: 改设置会被拒收未知键

- **WHEN** 客户端发 `Settings.Change`，里面带了一个这一局没声明过的名字
- **THEN** 回 `-32602`，且任何一项设置都没有变

### Requirement: 下行通知清单

服务端 SHALL 用通知下发变化：`Room.Update`、`Player.Update`、`Player.UpdateCustom`、`Player.UpdateAttribute`、`Card.Create`、`Card.Update`、`Card.Remove`、`Card.Move`、`Skill.Update`、`Skill.Remove`、`Panel.Create`、`Panel.Update`、`Panel.Remove`、`Settings.Update`、`Turn.Begin`、`Turn.End`、`Phase.Begin`、`Phase.End`、`Game.Over`、`Game.Restarted`、`Cancel`。

**玩家基础信息**（`Proto.Player.Base`）SHALL 带 `id` / `userName` / `seat` / `alive`。`alive` 是**存活状态**（阵亡后为 `false`）—— 客户端 MUST 用它判「阵亡」，MUST NOT 拿「体力 ≤ 0」代替：濒死（体力已归零、正在求桃）与阵亡是两回事，前者仍是 `alive = true`。存活状态变了 SHALL 走 `Player.Update`。

**玩家设置**（`Settings.Update`）SHALL **只发给设置变了的那个人**：载荷是这名玩家的全量 `Proto.Setting[]`；别的连接 MUST NOT 收到。

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

#### Scenario: 设置变化只推给本人

- **WHEN** 一名玩家改了设置
- **THEN** 他自己收到一条 `Settings.Update`（全量 `Proto.Setting[]`），同一局的其他连接收不到
