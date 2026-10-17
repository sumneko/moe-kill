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

--- 这次请求等超时了（服务端比时限多等 1 秒，客户端还没回）
---@class Proto.Error.TIMEOUT
---@field code -3
---@field message 'timeout'

--- 这条请求现在做不了（处理器返回它 —— 失败的原因写在 `message` 里：还没开局 / 这条连接还没入座 / 这块面板现在没开着询问 …）
---@class Proto.Error.INVALID_REQUEST
---@field code -32600
---@field message string

--- 请求里带了认不出的号（牌号 / 面板号 …）
---@class Proto.Error.INVALID_PARAMS
---@field code -32602
---@field message string

--- 可取消请求的基类
---@class Proto.Cancelable
---@field cancelToken? integer

--- 有时限的请求的基类（不给 `timeLimit` 就是不限时）
---@class Proto.Timelimit
---@field timeLimit? number # 秒（服务端多等 1 秒才判超时）

--- 取消一个请求。取消后那个请求应当返回： error: Proto.Error.REQUEST_CANCELED
---@class Proto.Notify.Cancel
---@field cancelToken integer

---@class Proto.Player.Base
---@field id integer # 唯一ID
---@field userName string # 用户名
---@field seat integer # 座位号
---@field alive boolean # 还活着吗（濒死时仍是 true，阵亡后才是 false）

--- 一条属性：名字 + 当前值
---@class Proto.Attribute
---@field name string # 属性名（内容侧起的名字）
---@field value number # 当前值

--- 自定义数据：字段由各包自己的 meta.lua 补（内核只认「有这么一张自由表」）
---@class Proto.Custom

---@class Proto.Player
---@field base Proto.Player.Base
---@field custom Proto.Custom # 自定义数据，由 package 组装
---@field attributes Proto.Attribute[] # 按收件人视角裁过的属性（没声明过可见性的不下发）

---@class Proto.SnapShot
---@field me? integer # 这条连接控制的是谁（还没入座就是空）
---@field players Proto.Player[] # 玩家列表
---@field cards Proto.Card[] # 局上所有的卡牌列表
---@field skills? Proto.Skill[] # 场上所有技能（重连用）
---@field panels? Proto.Panel[] # 场上现存的每块面板（重连用）
---@field turnPlayer? integer # 当前回合角色（没人在回合就是空）
---@field phase? string # 当前阶段名（不在阶段里就是空）
---@field texts Proto.Text[] # 展示用文本（牌与技能各按裸名收一份）
---@field settings Proto.Setting[] # 他的设置（本人全量：定义 + 当前值）
---@field debug boolean # 服务器是不是调试模式
---@field animScale number # 动画等待的倍率（0 = 完全不等）

---@class Proto.Player.Custom
---@field id integer # 玩家ID
---@field custom Proto.Custom # 他的自定义数据（全量）

---@class Proto.Player.Attribute
---@field id integer # 玩家ID
---@field attributes Proto.Attribute[] # 他这次可见的属性（按名字排序）

--- 基础信息变了（一条里带一批玩家）
---@class Proto.Notify.Player.Update
---@field players Proto.Player.Base[] # 基础信息变了的那些玩家

--- custom 变了（一条里带一批玩家）
---@class Proto.Notify.Player.UpdateCustom
---@field players Proto.Player.Custom[] # custom 变了的那些玩家

--- 属性变了（一条里带一批玩家）
---@class Proto.Notify.Player.UpdateAttribute
---@field players Proto.Player.Attribute[] # 属性变了的那些玩家

--- 房间状态（谁进来了 / 还差几个人）：开局之前每次有人入座都发一次
---@class Proto.Notify.Room.Update
---@field seats integer # 这一局一共几个座
---@field players Proto.Player.Base[] # 已经坐下的人（按座位号排）

---@class Proto.CardFace
---@field name? string # 卡牌名称，没有说明是背面朝上
---@field suit? '黑桃' | '红桃' | '梅花' | '方块' # 花色
---@field point? integer # 卡牌点数

---@class Proto.Card
---@field id integer # 卡牌当前ID，每当进入区域会分配一个新的，离开区域会销毁
---@field face? Proto.CardFace # 原始牌信息，如果没有说明是背面朝上
---@field modifier? Proto.CardFace # 转化牌信息
---@field zone? string # 卡牌所在的区域（`名字#玩家号`；玩家号 0 = 无主）

---@class Proto.Notify.Card.Update
---@field cards Proto.Card[] # 被更新的卡牌列表

---@class Proto.Notify.Card.Remove
---@field ids integer[] # 被移除的卡牌ID列表

---@class Proto.Notify.Card.Create
---@field show? { zone: string, cards: Proto.Card[] }[] # 正面朝上的部分，按区域划分
---@field hide? { zone: string, cards: integer[]    }[] # 背面朝上的部分，按区域划分

---@class Proto.CardMove
---@field id? integer # 移动的卡牌ID，方便播放动画确定起始位置
---@field face? Proto.CardFace # 移动的卡牌模板信息，没有说明是背面朝上
---@field from string # 来源区域（`名字#玩家号`）
---@field to string # 目标区域（`名字#玩家号`）

--- 仅仅是用于播放移动动画，会确保在 `Card.Remove` 之前通知
---@class Proto.Notify.Card.Move
---@field moves Proto.CardMove[]

---@class Proto.Skill
---@field name string # 技能名
---@field id integer # 唯一ID
---@field player integer # 在哪个英雄身上
---@field auto? boolean # 三态：true = 自动同意 / false = 每次问 / 不带 = 这个技能没有自动开关（主动技）
---@field tag? string[] # 标签
---@field disabled? boolean # 是否被禁用

---@class Proto.Text
---@field name string # 裸名（牌名 / 技能名）
---@field text string # 要显示的文本

---@class Proto.Notify.Skill.Update
---@field skill Proto.Skill # 被更新的技能

---@class Proto.Notify.Skill.Remove
---@field id integer # 被移除的技能ID

---@class Proto.Request.Skill.ChangeAuto
---@field id integer # 要改变自动状态的技能ID
---@field auto boolean # 新的自动状态

---@class Proto.Result.Skill.ChangeAuto
---@field auto? boolean # 新的自动状态

--- 一条玩家设置：名字 + 这个人当前的值 + 默认值 + 说明
---@class Proto.Setting
---@field name string # 设置名（内容词，如「无懈可击不响应自己的锦囊」）
---@field value any # 这个人当前的值（类型由定义决定：布尔开关 / 数字 / 文本）
---@field default any # 内容侧声明的默认值
---@field describe? string # 给用户看的说明

--- 一条要改的设置（只带名字与新值）
---@class Proto.Setting.Change
---@field name string # 设置名
---@field value any # 新值（与默认值同类型）

--- 改自己的设置（只改带上去的键；出现没声明过的名字就整包拒收）
---@class Proto.Request.Settings.Change
---@field settings Proto.Setting.Change[]

---@class Proto.Result.Settings.Change
---@field settings Proto.Setting[] # 改完之后的全量

--- 设置变了（只发给本人）
---@class Proto.Notify.Settings.Update
---@field settings Proto.Setting[] # 全量

--- 轮到他开始回合了
---@class Proto.Notify.Turn.Begin
---@field player integer # 哪个角色

--- 他的回合结束了
---@class Proto.Notify.Turn.End
---@field player integer # 哪个角色

--- 进了一个阶段
---@class Proto.Notify.Phase.Begin
---@field player integer # 谁的阶段
---@field name string # 阶段名（准备 / 判定 / 摸牌 / 出牌 / 弃牌 / 结束）

--- 这个阶段结束了
---@class Proto.Notify.Phase.End
---@field player integer # 谁的阶段
---@field name string # 阶段名

--- 这一局结束了（**收到它就是终局**：此后不会再来回合 / 阶段）
---@class Proto.Notify.Game.Over
---@field side string # 胜方阵营：主公方 / 反贼 / 内奸 / 平局
---@field reason string # 胜负依据（中文短句，前端可直接显示）

--- 这一局重开了（**收到它就是新的一局**）：params 是一份按你视角裁过的完整快照
---@class Proto.Notify.Game.Restarted: Proto.SnapShot

--- 动画等待的倍率被改了（发给所有连接）
---@class Proto.Notify.Game.AnimScale
---@field scale number # 现在的倍率（0 = 完全不等）

--- 一条连接坐进来（座位由服务端分配；坐满就开局）
---@class Proto.Request.Game.Join
---@field name? string # 玩家名

--- 要一份当前局面的全量快照（重连用；没有参数）
---@class Proto.Request.Game.SnapShot

--- 把已经终了的这一局放下、原班人马重开一局（没有参数；重建走 `Game.Restarted`）
---@class Proto.Request.Game.Restart

--- 改动画等待的倍率（**只有调试模式**下允许；`0` = 完全不等）
---@class Proto.Request.Game.SetAnimScale
---@field scale number # 新的倍率（不能是负数）

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

--- 这次响应冲哪次使用去的（只在「响应类询问」上给）
---@class Proto.ResponseTo
---@field card    string    # 被响应的那张牌的牌名
---@field player  integer   # 那次使用的使用者
---@field targets integer[] # 那次使用的目标
---@field target? integer   # 这次生效的当前目标（多目标结算时才是它，`targets` 是整张牌的目标）

--- 要求客户端选择卡牌和玩家（可能是多选）
---@class Proto.Request.Ask.Select: Proto.Cancelable, Proto.Timelimit
---@field reason      string # 给用户看的提示文本（可带格式，见 `jsonrpc-protocol` 规格）
---@field cancelable? boolean # 是否可以主动取消
---@field player?     Proto.Plan.Player
---@field card?       Proto.Plan.Card
---@field responseTo? Proto.ResponseTo # 这次响应冲哪次使用去的（不是响应就不给）

---@class Proto.Result.Ask.Select
---@field player? integer[] # 被选中的玩家ID列表
---@field card?   integer[] # 被选中的卡牌ID列表

---@class Proto.Request.Ask.Choice: Proto.Cancelable, Proto.Timelimit
---@field reason string # 给用户看的提示文本（可带格式，见 `jsonrpc-protocol` 规格）
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

--- 一个可发动的技能：技能ID + 这次能挑的牌 / 目标（技能没声明就缺哪半）
---@class Proto.SkillPlan
---@field id integer # 技能ID
---@field cards? Proto.Plan.Card
---@field targets? Proto.Plan.Player

--- 要一次行动：能用的牌（含视为）与能发动的技能是**三组可选分量**，各自可缺 —— 给一组就是问那一类、给多组就是一次问清
---@class Proto.Request.Ask.Use: Proto.Cancelable, Proto.Timelimit
---@field reason string # 给用户看的提示文本（可带格式，见 `jsonrpc-protocol` 规格）
---@field cancelable? boolean # 是否可以主动取消
---@field card?   Proto.CardWithPlan[] # 能用的牌（不问牌就不给）
---@field viewAs? Proto.ViewAs[] # 可用的视为技列表（同上）
---@field skill?  Proto.SkillPlan[] # 能发动的技能（同上）

--- 一次答复：给了哪个 `used*` 就是哪一种（三者互斥）
---@class Proto.Result.Ask.Use
---@field usedCard? integer # 用了哪张牌
---@field usedViewAs? integer # 用了第几个viewAs效果
---@field usedSkill? integer # 发动哪个技能（ID）
---@field targets? integer[] # 被选中的目标玩家ID列表
---@field cards? integer[] # 这次带的素材牌（视为 / 技能用；`usedCard` 时不带）

--- 要在若干武将里挑：候选是一份武将全名（`包名.定义名`；不给 = 不做限制）
---@class Proto.Request.Ask.Hero: Proto.Cancelable, Proto.Timelimit
---@field reason string # 给用户看的提示文本（可带格式，见 `jsonrpc-protocol` 规格）
---@field heroes? string[] # 候选武将全名（`包名.定义名`；不给 = 不做限制）
---@field min integer # 最少选几个
---@field max integer # 最多选几个

---@class Proto.Result.Ask.Hero
---@field heroes? string[] # 选中的武将全名（缺 = 取消）

--- 面板上的一行（行内有序）
---@class Proto.PanelRow
---@field title? string # 给客户端排版用的行标题
---@field cards integer[] # 这一行的卡牌ID（按顺序）

--- 一位牌挂着的一条展示用标记
---@class Proto.PanelMark
---@field card integer # 卡牌ID
---@field mark string # 挂着的那条标记（一张牌挂多条就发多份）

--- 一块面板（创建与更新都发整块；属性按卡牌ID索引）
---@class Proto.Panel
---@field id integer # 面板ID（客户端靠它指认这块面板）
---@field name string # 面板名（内容侧定）
---@field moveable boolean # 允不允许移动牌
---@field min integer # 确定时至少要选中几张
---@field max integer # 确定时至多选中几张
---@field rows Proto.PanelRow[]
---@field disabled integer[] # 被禁用的卡牌ID
---@field marks Proto.PanelMark[] # 挂标记的那些牌（没标记的不列）

--- 一块面板出现了（发给所有人；此后它只是展示，不能操作）
---@class Proto.Notify.Panel.Create
---@field panel Proto.Panel

--- 一行变了的完整新状态
---@class Proto.PanelRowUpdate
---@field row integer # 第几行（1 起）
---@field cards integer[] # 这一行的完整新形状

--- 一块面板的增量变化（只发这次动到的部分）
---@class Proto.PanelUpdate
---@field id integer # 哪块面板
---@field rows? Proto.PanelRowUpdate[] # 变了的行（完整新状态）
---@field disabled? integer[] # 新被禁用的卡牌ID
---@field enabled? integer[] # 被恢复的卡牌ID
---@field addMark? Proto.PanelMark[] # 新挂上的标记
---@field removeMark? Proto.PanelMark[] # 被摘掉的标记

--- 面板变了（增量）
---@class Proto.Notify.Panel.Update
---@field panel Proto.PanelUpdate

---@class Proto.Notify.Panel.Remove
---@field id integer # 拆掉的面板ID

--- 要他在某块面板上操作（面板的形状与能怎么操作早在 `Panel.Create` / `Update` 里给过）
---@class Proto.Request.Ask.Panel: Proto.Cancelable, Proto.Timelimit
---@field reason string # 给用户看的提示文本（可带格式，见 `jsonrpc-protocol` 规格）
---@field cancelable? boolean # 是否可以主动取消
---@field id integer # 在哪块面板上操作

---@class Proto.Result.Ask.Panel
---@field card? integer[] # 选中的卡牌ID（缺 = 没选）

--- 客户端要把一张牌挪到某行的某个位置（一次一张；实际形状由随后的 `Panel.Update` 广播）
---@class Proto.Request.Panel.Move
---@field id integer # 面板ID
---@field card integer # 要挪的卡牌ID
---@field row integer # 放到第几行（1 起）
---@field col integer # 放到这一行的第几个位置（1 起）

---@class Proto.Result.Panel.Move
---@field success boolean # 挪成了没有
