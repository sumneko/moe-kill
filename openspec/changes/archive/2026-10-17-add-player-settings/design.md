# Design

## 1 为什么是「设置」而不是别的现成通道

| 现成通道 | 为什么不用 |
| --- | --- |
| `Player.Custom` | 那是**内容侧**自由数据（服务器写、客户端只读），客户端改不进去 |
| `Skill.ChangeAuto` | 只管单个技能的自动开关，粒度是技能而不是「人的偏好」 |
| 座位上的字段 | 偏好应当**跟着人**：换座位、重开一局都要带着（用户 2026-10-17 定「挂 User」） |

## 2 归属：跟着**名字**走，`User` 做门面

`User` 会在 `Game.Restart` 时整个重建（`moe.room.restart()` 重新 `seatPlayer` 出一批新 `Player` / 新 `User`），**断线重连也会**（新 `Client` + 新 `User`）。所以袋子不能挂在 `User` / `Client` 的字段上，否则重开或刷新就丢。做法：

- 门面表 `moe.settingsSync._bags` 是「名字 → 设置袋」的台账（进程内，不落盘）；
- `User:settingsBag()` 按 `self.player:getName()` 取袋（没有就用一份私有的，给无名字的夹具）；`User:getSetting` / `User:updateSettings` 都通过它；
- 于是：重开一局 ✓、断线重连 ✓、换座位 ✓；同名视为同一个人（与 `moe.room.join` 的「同名接管座位」口径一致）。

> 用名字当身份是既有口径：`findOffline` 就是靠名字把断线的座位接回去。
>
> 已知限制：设置只在**服务器进程内**（不落盘），服务器重启就回到默认值。

## 3 定义与取值：内核机制 + 内容声明

- 内核（`server/core/game.lua`）：`defineSetting { name, default, describe? }` / `getSettingDefault(name)` / `listSettings()`。内核**不预设任何条目**，也不解释值。
- 内容侧（`package/@基础/设置.lua`）在**装载时**（包文件顶层，比开局早 —— 客户端入座那刻的快照就要带出来）声明：

  ```lua
  game:defineSetting {
      name = '无懈可击不响应自己的锦囊',
      default = true,
      describe = '你自己的锦囊生效前，不问你要不要用【无懈可击】',
  }
  ```

- 名字用中文：它是**内容词**（与 `'体力'` / `'杀'` 同类，见项目约定「中文只留给难翻译的内容名」），且作为数据取值跨协议传输。

## 4 协议形状

```lua
---@class Proto.Setting
---@field name string        # 设置名（内容词）
---@field value boolean|number|string # 这个人当前的值
---@field default boolean|number|string # 内容侧声明的默认值
---@field describe? string  # 给用户看的说明

--- 上行
---@class Proto.Request.Settings.Change
---@field settings Proto.Settings # 只改带上去的键

--- 下行（只发给本人）
---@class Proto.Notify.Settings.Update
---@field settings Proto.Setting[] # 全量
```

- **数组不用 Record**（沿用 `player-attributes` 的决议）：`Proto.Setting[]` 自带 `default` / `describe`，前端一次拿全，不必再查定义。
- 上行用 `Proto.Settings`（Record）是因为「只改变化项」更自然；回包给数组，前端直接整份替换。
- 命名：上行 `Settings.Change`（动词，照 `Skill.ChangeAuto`），下行 `Settings.Update`（照 `Player.Update`）。
- **未知键 ⇒ 整包 `-32602`**：协议 / 前端数据是外部输入，不能部分生效（部分生效会让客户端以为改成功了）。

## 5 生效点：`nullified` 一圈里跳过自己

`package/标准/卡牌/无懈可击.lua`：

```lua
for player in game.desk:actionOrder() do
    if useCard == nil or player ~= useCard.user or not player:getSetting('无懈可击不响应自己的锦囊') then
        -- 照常问
    end
end
```

- 只在**有使用者**的场合（`useCard` 非空）才可能跳过；【无懈可击】抵消另一张【无懈可击】那一支（`CardEffectToCard`）没有使用者，照旧问。
- 判定读**被问的那个人**的设置（`player:getSetting`），所以「别人开不开」互不影响。

## 6 前端

- 顶栏保留。「重新同步」「调试抽屉」属于调试入口 ⇒ 按快照里的 `debug`（`agent.debug`）决定是否渲染。
- 「设置」按钮放顶栏（正式功能）：点开一张小卡片，逐条列出 `Proto.Setting`，`checkbox`（`boolean`）/ 输入（`number` / `string`）即时提交 `Settings.Change`，用回包替换本地状态。
- 状态落 `Agent.settings`（`Map<name, Proto.Setting>`），快照与 `Settings.Update` 都整份替换。

## 6.5 本地存档与重连重传（2026-10-17 用户定）

服务器不落盘 ⇒ 进程重启后设置回到默认值；而「我的偏好」本来就在客户端手里。于是：

- 客户端把当前设置写进 `localStorage`，key = `moe-kill:settings:<服务器地址>|<用户名>`（同一台服务器上的同一个人共用一个）；
- **每次拿到快照之后**（`Game.Join` / `Game.SnapShot` / `Game.Restarted`）比对本地存档，把**不一致的项**一次 `Settings.Change` 推上去 —— 与「服务器发快照」对称：服务器给局面，客户端给自己的偏好；
- 服务器回包 / `Settings.Update` 到达后写回本地（**服务器是权威**：它拒收 / 规整过就以它为准）；
- 一致就不发，避免每次重连都白推一次。

## 7 不做的事

- 不做「服务端保存到磁盘」：设置只活在服务器进程内（连接断掉即丢）。以后要持久化是另一件事。
- 不做「按房间」的设置作用域：只有玩家级。
- 不给设置加「可见性」：别人的设置不下发，也不该有。
