---@class Proto.Player.Base
---@field id integer # 唯一ID
---@field userName string # 用户名
---@field seat integer # 座位号

--- 自定义数据：字段由各包自己的 meta.lua 补（内核只认「有这么一张自由表」）
---@class Proto.Custom

---@class Proto.Player : Proto.Player.Base
---@field custom Proto.Custom # 自定义数据，由 package 组装

---@class Proto.SnapShot
---@field players Proto.Player[] # 玩家列表

---@class Proto.S2C.Notify.Player.Update
---@field players Proto.Player.Base[] # 基础信息变了的玩家

---@class Proto.Player.Custom
---@field id integer # 玩家ID
---@field custom Proto.Custom # 他的自定义数据（全量）

--- 一次下发的打包（内核按视角组装好交给 User；基础信息合成一条、custom 一人一条）
---@class Proto.Update
---@field base? Proto.Player.Base[] # 基础信息变了的那些玩家
---@field custom? Proto.Player.Custom[] # custom 变了的那些玩家
