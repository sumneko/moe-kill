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
---@field error Proto.Error

---@class Proto.Error
---@field code integer
---@field message string
---@field data? table

--- 请求方取消了请求
---@class Proto.Error.REQUEST_CANCELED
---@field code -1
---@field message 'request canceled'

--- 客户端自己不想答（它直接回这个错误）
---@class Proto.Error.CANCELED
---@field code -2
---@field message 'canceled'

--- 可取消请求的基类
---@class Proto.Cancelable
---@field cancelToken? integer

--- 取消一个请求。取消后那个请求应当返回： error: Proto.Error.REQUEST_CANCELED
---@class Proto.Notify.Cancel
---@field cancelToken integer

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

---@class Proto.CardFace
---@field name? string # 卡牌名称，没有说明是背面朝上
---@field suit? '黑桃' | '红桃' | '梅花' | '方块' # 花色
---@field point? integer # 卡牌点数

---@class Proto.Card
---@field id integer # 卡牌当前ID，每当进入区域会分配一个新的，离开区域会销毁
---@field face? Proto.CardFace # 原始牌信息，如果没有说明是背面朝上
---@field modifier? Proto.CardFace # 转化牌信息
---@field zone? Proto.Zone # 卡牌所在的区域，没有说明在临时区

---@class Proto.Notify.Card.Update
---@field cards Proto.Card[] # 被更新的卡牌列表

---@class Proto.Notify.Card.Remove
---@field ids integer[] # 被移除的卡牌ID列表

---@class Proto.Notify.Card.Create
---@field cards Proto.Card[] # 被创建的卡牌列表

---@class Proto.CardMove
---@field id? integer # 移动的卡牌ID，方便播放动画确定起始位置
---@field face? Proto.CardFace # 移动的卡牌模板信息，没有说明是背面朝上
---@field from Proto.Zone # 来源区域
---@field to Proto.Zone # 目标区域

--- 仅仅是用于播放移动动画，会确保在 `Card.Remove` 之前通知
---@class Proto.Notify.Card.Move
---@field moves Proto.CardMove[]

---@class Proto.Request.Ask.Player: Proto.Cancelable
---@field reason string
---@field players integer[] # 候选玩家ID列表
---@field min integer # 最少需要的玩家数量
---@field max integer # 最多允许的玩家数量
---@field cancelable? boolean # 是否可以主动取消

---@class Proto.Result.Ask.Player
---@field players integer[] # 被选中的玩家ID列表
