---@class JSONRPC.Notify
---@field jsonrpc '2.0'
---@field method string
---@field params table

---@class JSONRPC.Request
---@field jsonrpc '2.0'
---@field method string
---@field id integer
---@field params table

---@class JSONRPC.Result
---@field jsonrpc '2.0'
---@field id integer
---@field result table

---@class JSONRPC.Error
---@field jsonrpc '2.0'
---@field id integer
---@field error { code: integer, message: string, data?: table }

--- 可取消请求的基类
---@class Proto.Cancelable
---@field cancelid integer

---@class Proto.Notify.Cancel
---@field cancelid integer

---@class Proto.Player.Base
---@field id integer # 唯一ID
---@field userName string # 用户名
---@field seat integer # 座位号

--- 自定义数据：字段由各包自己的 meta.lua 补（内核只认「有这么一张自由表」）
---@class Proto.Custom

---@class Proto.Player
---@field base Proto.Player.Base
---@field custom Proto.Custom # 自定义数据，由 package 组装

---@class Proto.SnapShot
---@field players Proto.Player[] # 玩家列表
---@field cards Proto.Card[] # 局上所有的卡牌列表

---@class Proto.Player.Custom
---@field id integer # 玩家ID
---@field custom Proto.Custom # 他的自定义数据（全量）

--- 基础信息变了（一条里带一批玩家）
---@class Proto.Notify.Player.Update
---@field players Proto.Player.Base[] # 基础信息变了的那些玩家

--- custom 变了（一条里带一批玩家）
---@class Proto.Notify.Player.UpdateCustom
---@field players Proto.Player.Custom[] # custom 变了的那些玩家

---@class Proto.Zone
---@field name? string # 没有名字的是临时区
---@field player? integer # 玩家ID，没有的话说明是公共区

---@class Proto.CardTemplate
---@field name? string # 卡牌名称，没有说明是背面朝上
---@field suit? '黑桃' | '红桃' | '梅花' | '方块' # 花色
---@field point? integer # 卡牌点数

---@class Proto.Card
---@field id integer # 卡牌当前ID，每当进入区域会分配一个新的，离开区域会销毁
---@field template? Proto.CardTemplate # 原始牌信息，如果没有说明是背面朝上
---@field modifier? Proto.CardTemplate # 转化牌信息
---@field zone? Proto.Zone # 卡牌所在的区域，没有说明在临时区

---@class Proto.Notify.Card.Update
---@field cards Proto.Card[] # 被更新的卡牌列表

---@class Proto.Notify.Card.Remove
---@field ids integer[] # 被移除的卡牌ID列表

---@class Proto.Notify.Card.Create
---@field cards Proto.Card[] # 被创建的卡牌列表

---@class Proto.MovingCard
---@field id? integer # 移动的卡牌ID，方便播放动画确定起始位置
---@field template? Proto.CardTemplate # 移动的卡牌模板信息，没有说明是背面朝上

--- 仅仅是用于播放移动动画，会确保在 `Card.Remove` 之前通知
---@class Proto.Notify.Card.Move
---@field cards Proto.MovingCard[]
---@field from Proto.Zone # 来源区域
---@field to Proto.Zone # 目标区域
