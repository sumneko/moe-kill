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

---@class Proto.Skill
---@field name string # 技能名
---@field id integer # 唯一ID
---@field player integer # 在哪个英雄身上
---@field auto? boolean # 是否是自动技能以及自动技能开关状态
---@field tag? string[] # 标签
---@field disabled? boolean # 是否被禁用

---@class Proto.Notify.skill.Update
---@field skill Proto.Skill # 被更新的技能

---@class Proto.Notify.Skill.Remove
---@field id integer # 被移除的技能ID

---@class Proto.Request.Skill.ChangeAuto
---@field id integer # 要改变自动状态的技能ID
---@field auto boolean # 新的自动状态

---@class Proto.Result.Skill.ChangeAuto
---@field auto? boolean # 新的自动状态

---@class Proto.Plan.Player
---@field ids integer[] # 候选玩家ID列表
---@field min integer # 最少需要的玩家数量
---@field max integer # 最多允许的玩家数量

---@class Proto.Plan.Card
---@field ids integer[] # 候选卡牌ID列表
---@field min integer # 最少需要的卡牌数量
---@field max integer # 最多允许的卡牌数量

---@class Proto.CardWithPlan: Proto.Plan.Player
---@field id integer # 卡牌ID

--- 要求客户端选择卡牌和玩家（可能是多选）
---@class Proto.Request.Ask.Select: Proto.Cancelable
---@field reason      string
---@field cancelable? boolean # 是否可以主动取消
---@field player?     Proto.Plan.Player
---@field card?       Proto.Plan.Card

---@class Proto.Result.Ask.Select
---@field player? integer[] # 被选中的玩家ID列表
---@field card?   integer[] # 被选中的卡牌ID列表

---@class Proto.Request.Ask.Choice: Proto.Cancelable
---@field reason string # 这次确认的原因
---@field options string[] # 可选项列表
---@field cancelable? boolean # 是否可以主动取消

---@class Proto.Result.Ask.Choice
---@field choice integer # 客户端选择的索引，对应 `options` 中的位置

---@class Proto.ViewAs
---@field name string # 要视为的卡牌
---@field sourceCard? integer # 提供这个视为技的卡牌。和 sourceSkill 互斥
---@field sourceSkill? integer # 提供这个视为技的技能名。和 sourceCard 互斥
---@field card? Proto.Plan.Card # 作为素材的卡牌
---@field target? Proto.Plan.Player # 作为目标的玩家

---@class Proto.Request.Ask.Use: Proto.Cancelable
---@field reason string # 这次使用的原因
---@field cancelable? boolean # 是否可以主动取消
---@field card   Proto.CardWithPlan[] # 被使用的卡牌列表
---@field viewAs Proto.ViewAs[] # 可用的视为技列表

---@class Proto.Result.Ask.Use
---@field usedCard? integer # 被使用的卡牌ID
---@field usedViewAs? integer # 使用了第几个viewAs效果。和 card 互斥。
---@field targets? integer[] # 被选中的目标玩家ID列表
---@field cards? integer[] # 被使用的卡牌ID列表。只有 useViewAs 时才有可能有值
