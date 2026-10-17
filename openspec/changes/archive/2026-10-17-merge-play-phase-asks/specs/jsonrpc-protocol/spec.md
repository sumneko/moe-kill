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
| `Settings.Change` | `{ settings: Proto.Settings }` | `{ settings: Proto.Setting[] }` |

**询问的答复** SHALL 走**反向请求**（服务端发、客户端回结果）：`Ask.Select` / `Ask.Choice` / `Ask.Use` / `Ask.Hero` / `Ask.Panel` —— 形状各自在 `proto.d.lua` 里（`Proto.Request.Ask.*` / `Proto.Result.Ask.*`）。

**`Ask.Use` SHALL 是「要一次行动」的唯一一条询问**：「能用的牌」「可用的视为」「能发动的技能」是它的三组**可选分量**（`card` / `viewAs` / `skill`），各自可缺 —— 只给一组就是问那一类（原先的「用牌」「用技能」两类询问都走它），给多组就是一次问清（出牌阶段）。答复 SHALL 只用**一份**结果形状表达，靠给了哪个 `used*`（`usedCard` / `usedViewAs` / `usedSkill`，三者互斥）判别。`Ask.UseSkill` 方法 MUST NOT 再出现。

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

#### Scenario: 一次询问同时问牌与技能

- **WHEN** 服务端要在一次询问里既给出候选牌、又给出可发动的技能
- **THEN** 它 SHALL 只发**一条** `Ask.Use`，`params` 里同时带 `card`（连同 `viewAs`）与 `skill`，客户端回一条结果即可
- **AND** 只问一类时（只有 `card` / `viewAs`，或只有 `skill`）SHALL 用**同一个方法**与同一份结果形状，MUST NOT 另开新方法
