# jsonrpc-protocol Specification

## Purpose
后端与客户端之间那条线：怎么分帧、消息长什么样、方法有哪些、错了怎么回、时限与取消怎么表达。这是本项目**唯一对外承诺的接口面** —— 前端、将来的 AI 客户端与其它前端实现都按它对接。

数据形状的**唯一声明处**是 `server/proto.d.lua`（`server/bin/moe-kill.exe --gen-proto` 由它生成前端类型产物）；本规格只写外部必须知道的那部分，字段表以声明为准。

## Requirements

### Requirement: 分帧与传输

每条连接 SHALL 是一条**字节流**，消息按「**4 字节大端无符号长度头 + 正文**」分帧，长度**不含**头本身；正文 SHALL 是一条 JSON-RPC 2.0 报文（UTF-8）。

传输 SHALL 与分帧解耦：当前有纯 TCP 与 WebSocket 两种，WebSocket 那条在**帧里套同样的「长度头 + 正文」**（因此浏览器端 SHALL 发二进制帧）。

#### Scenario: 半包与粘包都接得住

- **WHEN** 一次读到的字节不够一条消息，或一次读到两条黏在一起
- **THEN** 前者继续等、后者各解一条，不丢也不串

#### Scenario: 长度头是大端 4 字节

- **WHEN** 正文长 70000 字节
- **THEN** 头是按 `>I4` 编的 70000，正文紧随其后

### Requirement: 四种消息

线上 SHALL 只有四种形状（与 JSON-RPC 2.0 一致），靠字段区分：**请求**（`jsonrpc` / `id` / `method` / `params`）、**通知**（`jsonrpc` / `method` / `params`）、**结果**（`jsonrpc` / `id` / `result`）、**错误**（`jsonrpc` / `id` / `error`，其中 `error` = `{ code, message, data? }`）。

`jsonrpc` SHALL 是字符串 `'2.0'`。带 `id` 的 SHALL 收到一条带同一个 `id` 的响应。

**双向都适用**：服务端也可以向客户端**发请求**（询问就是这条），客户端照同样形状回。

#### Scenario: 按有没有 `id` 区分请求与通知

- **WHEN** 一条报文带 `method` 且带 `id`
- **THEN** 按请求处理并回响应；不带 `id` 的按通知处理、不回响应

#### Scenario: 服务端反向请求

- **WHEN** 服务端要问客户端一件事
- **THEN** 它发一条带 `id` 的请求，客户端回一条带同一个 `id` 的结果或错误

#### Scenario: 结果必带 `result`

- **WHEN** 处理器的返回值是空
- **THEN** 响应里仍带 `result`（编成 `null`）

### Requirement: 参数形状校验

上行请求的 `params` SHALL 是表；形状 SHALL 由**声明推** —— `proto.d.lua` 里的 `Proto.Request.<方法名>`（声明里没有这个方法就不校验）。不合法时 SHALL 以 `-32602` 回绝、原因写进 `message`；**处理器 MUST NOT 收到不合形状的参数**。

#### Scenario: 形状不对在门口挡下

- **WHEN** 客户端发的 `params` 少字段 / 类型不对
- **THEN** 回 `-32602`，处理器根本没跑

#### Scenario: 认不出的号也是 `-32602`

- **WHEN** 请求里的牌号 / 面板号 / 技能号在服务端不存在
- **THEN** 回 `-32602`（原因写在 `message` 里）

### Requirement: 错误码

错误 SHALL 用标准 JSON-RPC 码 + 本项目自定义码：

| 码 | 含义 |
| --- | --- |
| `-32700` | 报文解析不了 |
| `-32600` | 这条请求现在做不了（还没开局 / 这条连接还没入座 / 那块面板现在没开着询问 …） |
| `-32601` | 没有这个方法 |
| `-32602` | 参数形状不对 / 号认不出 |
| `-32603` | 处理这条请求时出错 |
| `-1` | `request canceled` —— 这条请求被取消了 |
| `-2` | `canceled` —— 客户端自己不想答（它直接回这个错误） |
| `-3` | `timeout` —— 这次请求等超时了 |

处理器「做不了」SHALL 通过返回错误表达，MUST NOT 抛错（抛错一律算 `-32603`）。

#### Scenario: 方法不存在

- **WHEN** 客户端请求一个没注册的方法
- **THEN** 回 `-32601`，`message` 里带上方法名

#### Scenario: 还没开局就发请求

- **WHEN** 客户端在服务器还没开局时发 `Game.SnapShot`
- **THEN** 回 `-32600`，`message` 说明原因

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

### Requirement: 时限与取消

可取消的请求 SHALL 在参数里带 `cancelToken`（**由服务端发号**，见 `Proto.Cancelable`）。

**服务端 → 客户端**：服务端 SHALL 能在两种场合发 **`Cancel { cancelToken }`** 通知 —— ① 这次请求的**宿主被收掉**（那次结算结束 / 被取消），② **等超时**。收到它的客户端应停止这次应答（以 `REQUEST_CANCELED` 收尾）；服务端本地那次等待同样以「取消」结束（`-1`）。

**客户端 → 服务端**：客户端「不想答」SHALL 用**回一条错误 `-2`** 表达（`Proto.Error.CANCELED`）；当前服务端**没有**注册 `Cancel` 处理器 ⇒ 客户端 MUST NOT 靠发 `Cancel` 去取消服务端的请求。

带 `timeLimit`（秒）的请求 SHALL 有时限；服务端 SHALL 比 `timeLimit` **多等 1 秒**（宽松）才判超时，到点 SHALL 记 `-3`（`timeout`）并按「取消」收尾（对询问而言等价于「没人表态」）。

#### Scenario: 到点收掉并通知

- **WHEN** 一条询问带 `timeLimit = 10`，客户端 11 秒内没回
- **THEN** 这次询问按「取消」继续（记 `-3`），客户端收到 `Cancel`（带那个 `cancelToken`）

#### Scenario: 客户端主动不答

- **WHEN** 客户端回 `-2`
- **THEN** 这次询问按「没人表态」处理

#### Scenario: 宿主没了就叫人别答了

- **WHEN** 这次请求挂着的宿主（那次结算 / 技能发动 …）被删掉
- **THEN** 服务端发 `Cancel` 通知，本地那次等待以 `-1` 结束

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

### Requirement: WebSocket 握手

页面那条路走 WebSocket 时，服务端 SHALL 认 RFC 6455 握手：只接受 `GET`（否则 400）、必须带 `Sec-WebSocket-Key`（否则 400）、`Sec-WebSocket-Version` 必须是 `13`（否则 426 并带上 `Sec-WebSocket-Version: 13`）；请求头超过 8KB SHALL 直接回 400（半截头不撑爆缓冲）。

握手成功后**跟着一起来的字节**（客户端可以不等 101 就发帧）SHALL 交给解帧器，不丢。

#### Scenario: 版本不对回 426

- **WHEN** 客户端带 `Sec-WebSocket-Version: 8`
- **THEN** 服务端回 426，并带上 `Sec-WebSocket-Version: 13`

#### Scenario: 半截头不撑爆缓冲

- **WHEN** 请求头超过 8KB
- **THEN** 直接回 400

#### Scenario: 101 之前发的帧不丢

- **WHEN** 客户端在收到 101 之前就把帧发过来
- **THEN** 那些字节照常交给解帧器
