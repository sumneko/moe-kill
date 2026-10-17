# player-settings Specification

## Purpose
玩家设置的对外形状与生命周期：有哪些设置（内容侧声明）、某个人的取值是什么（默认值兜底）、客户端怎么改（协议）、它跟着谁走（**名字**：跨重开与断线重连都保留）。

设置是**人的偏好**，不是牌局规则：同一名玩家换座位、重开一局都该带着；一台服务器上不同连接各自独立。

## Requirements

### Requirement: 设置的定义由内容侧声明

内核 SHALL 提供 `Game:defineSetting(定义)`，定义 SHALL 是 `{ name, default, describe? }`；`name` 是**内容词**（如「无懈可击不响应自己的锦囊」），`default` 是该设置的默认值（`boolean` / `number` / `string`）。

同一局里重复声明同名设置 MUST 以后声明的为准（与其它定义项一致）。内核 MUST NOT 预设任何设置条目。

`Game:listSettings()` SHALL 给出这一局全部定义（按声明顺序），`Game:getSettingDefault(name)` SHALL 给出某个设置的默认值（没定义就给 `nil`）。

#### Scenario: 内容侧声明一条设置

- **WHEN** 内容包在 `'游戏-开始'` 里 `game:defineSetting { name = '无懈可击不响应自己的锦囊', default = true }`
- **THEN** `game:listSettings()` 里出现这一条，`game:getSettingDefault('无懈可击不响应自己的锦囊')` 是 `true`

#### Scenario: 内核不预设条目

- **WHEN** 没有任何内容包声明设置
- **THEN** `game:listSettings()` 是空表

### Requirement: 设置挂在人身上，跨重开与重连保留

设置 SHALL 属于**人**（以玩家名为身份），MUST NOT 属于座位（`Player`）或某一条连接（`Client`）。

`User:getSetting(name)` SHALL 返回这名玩家的当前取值：改过的就返回改过的值，否则返回该设置的默认值（没定义就给 `nil`）。同一名字的玩家 SHALL 共用同一份设置袋 —— 重开一局（换了 `Player` / `User` / 连接）后仍是原来那份；不同名字各有各的一份。

没有名字的对象（测试夹具）SHALL 自持一份（不共享）。

`Player:getSetting(name)` SHALL 转给 `self.user`；这名玩家没有连接时 SHALL 返回默认值。

#### Scenario: 没改过就是默认值

- **WHEN** 某设置默认是 `true`，玩家从没改过
- **THEN** `user:getSetting(名字)` 与 `player:getSetting(名字)` 都是 `true`

#### Scenario: 重开一局后设置还在

- **WHEN** 玩家把某项设置改成 `false`，然后这一局结束、发 `Game.Restart`
- **THEN** 新一局里 `player:getSetting(名字)` 仍是 `false`

#### Scenario: 断线重连后设置还在

- **WHEN** 同名的玩家断开又连回来（新 `Player` / 新 `User` / 新连接）
- **THEN** 他的设置仍是断开前那份（快照里带回来）

#### Scenario: 不同的人互不影响

- **WHEN** 甲把某项设置改成 `false`，乙从没改过
- **THEN** 乙读到的仍是默认值

### Requirement: 设置上行

客户端 SHALL 通过 `Settings.Change` 修改自己的设置，参数 SHALL 是 `{ settings: Record<名字, 值> }`（只改带上来的键，没带的不动），结果 SHALL 是这名玩家的全量 `Proto.Setting[]`。

服务端 MUST 只接受 `game:listSettings()` 里声明过的键：出现未知键 SHALL 回 `-32602`（`INVALID_PARAMS`）并**一个都不改**（整包拒收，不做部分生效）。

值 MUST NOT 被内核解释或校验类型（内容侧声明的 `default` 只用来兜底）。

#### Scenario: 改一项

- **WHEN** 客户端发 `Settings.Change { settings = { ['无懈可击不响应自己的锦囊'] = false } }`
- **THEN** 结果里那一条的 `value` 是 `false`，之后 `player:getSetting(名字)` 也是 `false`

#### Scenario: 未知键整包拒收

- **WHEN** 客户端发 `Settings.Change { settings = { ['不存在的设置'] = true } }`
- **THEN** 回 `-32602`，任何一项设置都没有变（结果里也不带被接受的部分）

### Requirement: 设置下行与快照

`Proto.Setting` SHALL 是 `{ name, value, default, describe? }` —— `value` 是这名玩家当前取值，`default` 是内容侧声明的默认值，`describe` 是给用户看的说明。

`Proto.SnapShot.settings` SHALL 是**本人**的全量 `Proto.Setting[]`（入座 / 重连 / 重开都靠它重建）。

设置变了 SHALL 发一条 `Proto.Notify.Settings.Update { settings: Proto.Setting[] }`，**只发给本人**（其它连接 MUST NOT 收到）。

设置 MUST NOT 出现在任何「按视角裁的公共数据」里（别人的设置不属于你）。

#### Scenario: 快照带自己的设置

- **WHEN** 客户端发 `Game.Join` 或 `Game.SnapShot`
- **THEN** 快照的 `settings` 里是这一局全部定义，每条带 `value` / `default`

#### Scenario: 改了会推给自己

- **WHEN** 一名玩家改了设置
- **THEN** 他自己收到一条 `Settings.Update`，其他人收不到

### Requirement: 客户端本地存档与重连重传

服务器 MUST 只在**进程内**记设置（不落盘）：进程重启、或这个人的袋子还没建起来时，读到的是默认值。

客户端 SHALL 在本地（浏览器存档）留一份，并在**每次拿到快照之后**把它与服务器不一致的项**一次**重传上去（`Settings.Change` 可一次带多条）；与服务器一致的项 MUST NOT 重传。

服务器回包 / `Settings.Update` 到达后，客户端 SHALL 用服务器那份覆盖本地存档（服务器是权威）。

客户端本地存档 MUST NOT 影响别人：它只描述「我自己」的偏好。

#### Scenario: 重连后把本地设置重传上去

- **WHEN** 客户端本地存着某项设置（`false`），重连后的快照里它是默认值（`true`）
- **THEN** 客户端发一条 `Settings.Change` 带上这一项，之后服务器读到的就是 `false`

#### Scenario: 一致就不重传

- **WHEN** 本地存档与快照里的值相同
- **THEN** 客户端不发 `Settings.Change`

### Requirement: 【无懈可击】不响应自己的锦囊（内容侧）

`@基础/设置.lua` SHALL 声明设置 `无懈可击不响应自己的锦囊`，默认值 `true`。

【无懈可击】问一圈时，若当前被问的玩家**正是这颗锦囊的使用者**且其该设置取值为真，服务端 SHALL 跳过问他（MUST NOT 给他发这条询问）；取值为假时 SHALL 照常问。

别的玩家 MUST 照常被问（这条设置只管「自己」）。

#### Scenario: 开启时自己的锦囊不问自己

- **WHEN** 一号位对二号位用【过河拆桥】，一号位的该设置是 `true`（默认）
- **THEN** 一号位收不到「打出一张【无懈可击】」的询问，二号位照常收到

#### Scenario: 关闭后照问自己

- **WHEN** 一号位把该设置改成 `false`，然后对自己用【无中生有】
- **THEN** 一号位自己也会被问「打出一张【无懈可击】」

#### Scenario: 别人的锦囊不受影响

- **WHEN** 二号位对一号位用锦囊，二号位开着该设置
- **THEN** 一号位仍被问（该设置只跳过自己那颗锦囊的使用者本人）
