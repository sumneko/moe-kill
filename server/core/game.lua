--- 一张牌的目标条件（`targets()` 声明归一后的形状；filter 是列表 —— 多次声明叠加、逐条都要过）
---@class CardDef.TargetCondition
---@field min? integer # 至少几个目标（省略 = 1）
---@field max? integer # 至多几个目标（省略 = min；事实不限写 1000）
---@field filter (fun(player: Player, plan: CardDef.TargetPlan): boolean)[] # 逐角色谓词（空 = 全部存活角色）

--- 目标条件的上下文：谁在用、哪张牌、打算打谁、这次使用的选项（谓词收它）
---@class CardDef.TargetPlan
---@field user Player # 使用者
---@field card Card # 要用的牌
---@field targets? Player[] # 期望的目标（没给目标就是空）
---@field useOptions? Game.UseOptions # 这次使用的选项

--- 一张牌的「对牌目标」条件（`cardTargets()` 声明归一后的形状；filter 是列表 —— 多次声明叠加、逐条都要过）
---@class CardDef.CardTargetCondition
---@field filter (fun(card: Card, plan: CardDef.CardTargetPlan): boolean)[] # 逐候选牌谓词（空 = 不筛、全认）

--- 对牌目标条件的上下文：谁在用、哪张牌、发起方要对的那批牌（谓词收它）
---@class CardDef.CardTargetPlan
---@field user Player # 使用者
---@field card Card # 要用的牌
---@field targets Card[] # 发起方要对的那批牌

--- 一次「订阅时机」的声明（`: event(…)` / `: globalEvent(…)` 的形状）：时机到就把载荷原样转给回调（第一参补上这张牌）
---@class CardDef.EventDecl
---@field name string # 时机名
---@field handler fun(card: Card, ...: any): any # 回调（返回值照原样交回发时机的那个 `fire`）

---@class CardDef
---@field name string # 裸名
---@field public package string # 所属包名（显式写 public：否则 package 会被当成访问修饰符）
---@field fullName string # 完整名（包名.名字）
---@field source string # 声明它的文件（逻辑路径）
---@field private game Game # 所属的局（`extends` 按名字取基类时要用）
---@field private handlers table<string, function[]>
---@field private limits table<string, integer> # 每个阶段最多用几次
---@field private kinds string[] # 分类（可多条，按声明顺序）
---@field private kindSet table<string, true> # 分类去重用
---@field private values table<string, any> # 这张牌自带的数据
---@field private viewAsList ViewAs.Decl[] # 声明过的「视为」（`viewAs()` 声明）
---@field private events CardDef.EventDecl[] # 订在主人头上的时机（`event()` 声明）
---@field private globalEvents CardDef.EventDecl[] # 订在局上的时机（`globalEvent()` 声明）
---@field targetCondition? CardDef.TargetCondition # 目标条件（`targets()` 声明；不声明 = 没有「对角色使用」这一支）
---@field cardTargetCondition? CardDef.CardTargetCondition # 对牌目标条件（`cardTargets()` 声明；不声明 = 进不了「对牌使用」那一支）
---@field private useZone? string # 必须从哪个牌区用（没声明 = 使用者任一牌区都行）
---@field skipsEffect? boolean # 使用后不进入「生效」（声明过 `skipEffect`）
local CardDef = Class 'CardDef'

---@type integer # 没声明限额时的兜底：事实上的「不限次数」
local DEFAULT_LIMIT = 1000

---@param game Game
---@param name string
---@param owner string
---@param source string
function CardDef:__init(game, name, owner, source)
    self.game     = game
    self.name     = name
    self.package  = owner
    self.fullName = owner .. '.' .. name
    self.source   = source
    self.handlers     = {}
    self.limits       = {}
    self.kinds        = {}
    self.kindSet      = {}
    self.values       = {}
    self.viewAsList   = {}
    self.events       = {}
    self.globalEvents = {}
end

--- 登记这张牌的一个钩子
---@param event string
---@param handler function
---@return CardDef
function CardDef:on(event, handler)
    local list = self.handlers[event]
    if not list then
        list = {}
        self.handlers[event] = list
    end
    list[#list+1] = handler
    return self
end

---@param event string
---@return function[] # 这个钩子上的所有回调（快照）
function CardDef:getHandlers(event)
    local list = self.handlers[event]
    if not list then
        return {}
    end
    return moe.util.copy(list)
end

--- 这张牌使用后不进入「生效」（用别的场合再让它生效）
---@return CardDef
function CardDef:skipEffect()
    self.skipsEffect = true
    return self
end

--- 声明这个阶段里最多用几次（可以多次调；同一个阶段重复写，后写的为准）
---@param phase string # 阶段名（取值由你定）
---@param count integer
---@return CardDef
function CardDef:limit(phase, count)
    self.limits[phase] = count
    return self
end

--- 这个阶段里最多用几次
---@param phase string
---@return integer # 没声明过就是 1000（事实上不限次数）
function CardDef:getLimit(phase)
    return self.limits[phase] or DEFAULT_LIMIT
end

--- 声明这张牌的分类（一次调用就把分类定下来；重复调以后写的为准；要多个就给一张列表）
---@param name string|string[] # 分类名（取值由你定）
---@return CardDef
function CardDef:kind(name)
    ---@type string[]
    local list
    if type(name) == 'table' then
        ---@cast name string[]
        list = name
    else
        ---@cast name string
        list = { name }
    end
    self.kinds   = {}
    self.kindSet = {}
    for _, item in ipairs(list) do
        if not self.kindSet[item] then
            self.kindSet[item] = true
            self.kinds[#self.kinds + 1] = item
        end
    end
    return self
end

--- 这张牌是不是这个分类
---@param name string
---@return boolean
function CardDef:isKind(name)
    return self.kindSet[name] == true
end

--- 追加分类（不覆盖已经声明过的）
---@param name string|string[] # 分类名（取值由你定）
---@return CardDef
function CardDef:addKind(name)
    ---@type string[]
    local list
    if type(name) == 'table' then
        ---@cast name string[]
        list = name
    else
        ---@cast name string
        list = { name }
    end
    for _, item in ipairs(list) do
        if not self.kindSet[item] then
            self.kindSet[item] = true
            self.kinds[#self.kinds + 1] = item
        end
    end
    return self
end

---@return string[] # 分类列表（快照，按声明顺序）
function CardDef:getKinds()
    return moe.util.copy(self.kinds)
end

--- 声明这张牌上的一条数据（名字与取值都由写牌的人定；同一个名字重复写，后写的为准）
---@param name string # 数据的名字
---@param value any # 数据本身
---@return CardDef
function CardDef:value(name, value)
    self.values[name] = value
    return self
end

--- 读这张牌上的一条数据
---@param name string # 数据的名字
---@return any # 没声明过就是「不存在」
function CardDef:getValue(name)
    return self.values[name]
end

--- 声明「这次使用要的目标」：个数区间 + 逐角色谓词（不声明整条 = 这张牌没有「对角色使用」这一支）
--- `filter` 不写 = 全部存活角色；多次调：filter 叠加（逐条都要过）、`min` / `max` 后写覆盖
---@param condition { min?: integer, max?: integer, filter?: fun(player: Player, plan: CardDef.TargetPlan): boolean } # 目标条件
---@return CardDef
function CardDef:targets(condition)
    local current = self.targetCondition
    if not current then
        current = { filter = {} }
        self.targetCondition = current
    end
    if condition.min ~= nil then
        current.min = condition.min
    end
    if condition.max ~= nil then
        current.max = condition.max
    end
    if condition.filter then
        current.filter[#current.filter + 1] = condition.filter
    end
    return self
end

--- 声明「这张牌能对哪些牌使用」：逐候选牌谓词（不声明整条 = 这张牌进不了「对牌使用」那一支）
--- 多次调：filter 叠加（逐条都要过）；候选由发起方给定，没有个数区间
---@param condition { filter?: fun(card: Card, plan: CardDef.CardTargetPlan): boolean } # 对牌目标条件
---@return CardDef
function CardDef:cardTargets(condition)
    local current = self.cardTargetCondition
    if not current then
        current = { filter = {} }
        self.cardTargetCondition = current
    end
    if condition.filter then
        current.filter[#current.filter + 1] = condition.filter
    end
    return self
end

--- 一次能指定几个目标（`min` 省略 = 1、`max` 省略 = `min`；没声明也是 1、1）
---@return integer # 最少几个
---@return integer # 最多几个
function CardDef:getTargetCount()
    local condition = self.targetCondition
    if condition then
        local min = condition.min or 1
        return min, condition.max or min
    end
    return 1, 1
end

--- 声明一份「视为」（可多次调）：被动启用时内核照它建 `ViewAs` 挂在持有者身上，停用自动撤
---@param name string # 视为哪张牌
---@param options? ViewAs.Options # 这份声明的选项（素材条件、要不要先问一句）
---@param on? fun(ask: AskCard, source: Card): (boolean|Card|Card[]?) # 发动回调（不填 = 直接成立）
---@return CardDef
function CardDef:viewAs(name, options, on)
    self.viewAsList[#self.viewAsList + 1] = { name = name, options = options, on = on }
    return self
end

---@return ViewAs.Decl[] # 声明过的「视为」（快照，按声明顺序）
function CardDef:getViewAsList()
    return moe.util.copy(self.viewAsList)
end

--- 订阅一个时机（可多次调）：被动启用时内核把它挂在**这张牌的主人头上**（所在区的 `owner`），停用 / 离场 / 换主人自动跟
--- 只做订阅与生命周期；**要不要发动（`card:cast(…)`）由回调自己写**（时机到就调，内核不替它问）
---@param name string # 时机名
---@param handler fun(card: Card, ...: any): any # 时机到的回调（载荷原样给，返回值也原样交回）
---@return CardDef
function CardDef:event(name, handler)
    self.events[#self.events + 1] = { name = name, handler = handler }
    return self
end

--- 订阅一个**局上**的时机（可多次调）：形状与 `event` 一样，只是挂在局上（`game:on`）
---@param name string # 时机名
---@param handler fun(card: Card, ...: any): any # 时机到的回调（载荷原样给，返回值也原样交回）
---@return CardDef
function CardDef:globalEvent(name, handler)
    self.globalEvents[#self.globalEvents + 1] = { name = name, handler = handler }
    return self
end

---@return CardDef.EventDecl[] # 订在主人头上的时机（快照，按声明顺序）
function CardDef:getEventList()
    return moe.util.copy(self.events)
end

---@return CardDef.EventDecl[] # 订在局上的时机（快照，按声明顺序）
function CardDef:getGlobalEventList()
    return moe.util.copy(self.globalEvents)
end

--- 声明这张牌必须从哪个牌区用（重复调以后写的为准）
---@param zone string # 牌区名（由内容侧定）
---@return CardDef
function CardDef:zone(zone)
    self.useZone = zone
    return self
end

--- 这张牌必须从哪个牌区用
---@return string? # 没声明就是空（使用者的任一牌区都行）
function CardDef:getZone()
    return self.useZone
end

--- 把另一个定义的钩子与字段抄过来（基类的钩子跑在前面；抄完就与基类脱钩）
---@param name string # 基类定义的名字（支持限定名）
---@return CardDef
function CardDef:extends(name)
    local base = self.game:getCard(name)
    if not base then
        error('找不到要继承的定义「{}」' % { name }, 2)
    end
    for event, list in pairs(base.handlers) do
        local own = self.handlers[event]
        ---@type function[]
        local merged = moe.util.copy(list)
        if own then
            moe.util.arrayMerge(merged, own)
        end
        self.handlers[event] = merged
    end
    if #base.kinds > 0 then
        self:kind(base.kinds)
    end
    if base.useZone then
        self.useZone = base.useZone
    end
    for phase, count in pairs(base.limits) do
        self.limits[phase] = count
    end
    for name, value in pairs(base.values) do
        self.values[name] = value
    end
    local baseCondition = base.targetCondition
    if baseCondition then
        local own = self.targetCondition
        ---@type CardDef.TargetCondition
        local merged = {
            min    = baseCondition.min,
            max    = baseCondition.max,
            filter = moe.util.copy(baseCondition.filter),
        }
        if own then
            if own.min ~= nil then
                merged.min = own.min
            end
            if own.max ~= nil then
                merged.max = own.max
            end
            moe.util.arrayMerge(merged.filter, own.filter)
        end
        self.targetCondition = merged
    end
    local baseCardCondition = base.cardTargetCondition
    if baseCardCondition then
        local own = self.cardTargetCondition
        ---@type CardDef.CardTargetCondition
        local merged = { filter = moe.util.copy(baseCardCondition.filter) }
        if own then
            moe.util.arrayMerge(merged.filter, own.filter)
        end
        self.cardTargetCondition = merged
    end
    if base.skipsEffect then
        self.skipsEffect = true
    end
    if #base.viewAsList > 0 then
        moe.util.arrayMerge(self.viewAsList, base.viewAsList)
    end
    return self
end
---@param name string
---@param level integer
local function checkSimpleName(name, level)
    if type(name) ~= 'string' or name == '' then
        error('规则名必须是非空字符串', level)
    end
    if name:find('.', 1, true) then
        error('规则名里不能含 "."（完整名由装载器拼接）：{}' % { name }, level)
    end
end

---@param name string
---@return string? # 包名（限定名才有）
---@return string # 条目名
local function splitName(name)
    if type(name) ~= 'string' or name == '' then
        error('规则名必须是非空字符串', 3)
    end
    local owner, entry = name:match '^([^%.]+)%.(.+)$'
    if owner then
        return owner, entry
    end
    return nil, name
end

---@param meta Loader.PackageMeta
---@return Loader.PackageMeta
local function copyMeta(meta)
    ---@type Loader.PackageMeta
    local copy = {
        name     = meta.name,
        depends  = moe.util.copy(meta.depends),
        excludes = moe.util.copy(meta.excludes),
        entries  = moe.util.copy(meta.entries),
        files    = {},
    }
    for i, file in ipairs(meta.files) do
        ---@type Loader.MetaFile
        local copied = {
            logical = file.logical,
            source  = file.source,
            ok      = file.ok,
            err     = file.err,
            entries = moe.util.copy(file.entries),
        }
        copy.files[i] = copied
    end
    return copy
end

---@class Game.CreateOptions
---@field seats integer # 座位数（桌子由局自己建）
---@field random Random
---@field sources? string[] # 包来源（省略时用默认来源）
---@field packages? string[] # 加载清单（省略时只装默认加载的包）
--- 一局的结果
---@class Game.Result
---@field side string # 胜方阵营：主公方 / 反贼 / 内奸 / 平局
---@field reason string # 胜负依据（中文短句，给人看 / 前端可直接显示）

--- 这次使用的可用目标与数量区间（`canUse` 成功时给出；「不指定目标」的牌是 legal 空表、min / max 都是 0）
---@class Game.UsableTargets
---@field legal Player[] # 合法目标
---@field min integer # 最少几个
---@field max integer # 最多几个（已与合法目标数取小）

--- 这次使用的选项：给这一次使用开的几条特殊通道（都不填 = 照常；由发起方给，**使用过程中内容侧也可以追** —— 见 `UseCard:addUseOptions`）
--- 这里只列**内核自己要读**的几条：其余名字由读它的那个包自己声明类型（如 `ignoreDistance` 声明在 `@基础/距离.lua`）+ 自己消费
---@class Game.UseOptions
---@field ignoreUseLimit? boolean # 无视使用次数上限（不检查「本阶段用过没」）
---@field notCounted? boolean # 不计入使用次数（不写 `useCount`）
---@field extraTargets? integer # 最多能多指定几个目标（加在上限上，可负；多份选项累加；最终仍与合法目标数取小）
---@field unrespondable? Player[] # 这些目标不能对此牌做出响应（写入收四种写法、见 `Game.UseOptionsInput`；**读用 `UseCard:isResponseBanned`**）

--- 追加使用选项时可给的形状（`Game.UseOptions` 的宽松版：`unrespondable` 收四种写法，写入时归一）
---@class Game.UseOptionsInput
---@field ignoreUseLimit? boolean
---@field notCounted? boolean
---@field extraTargets? integer # 最多能多指定几个目标（可负；多份选项累加）
---@field unrespondable? Player|Player[]|true|fun(player: Player): boolean # 一个角色 / 一串角色 / `true` = 谁都拦 / 谓词（这些目标不能对此牌做出响应）

---@class Game
---@field list string[] # 上一次用的加载清单
---@field private cards table<string, table<string, CardDef>> # 规则表：包名 → 裸名 → 定义
---@field private packages string[] # 包的加载顺序（首次出现的顺序）
---@field private buffs table<string, table<string, BuffDef>> # 状态表：包名 → 裸名 → 定义
---@field private buffPackages string[] # 声明过状态的包（首次出现的顺序）
---@field private heroes table<string, table<string, HeroDef>> # 武将表：包名 → 裸名 → 定义
---@field private heroPackages string[] # 声明过武将的包（首次出现的顺序）
---@field private skills table<string, table<string, SkillDef>> # 技能表：包名 → 裸名 → 定义
---@field private skillPackages string[] # 声明过技能的包（首次出现的顺序）
---@field meta table<string, Loader.PackageMeta> # 包元信息（装载器每次装完写入）
---@field private values table<string, any> # 规则数值（按加载顺序后者覆盖前者）
---@field loadedFiles string[] # 上一次实际执行过的文件（按执行完成顺序）
---@field loading? Loader.Context # 装载期上下文（装载器写、查询读；装完置空）
---@field turnPlayer? Player # 当前回合角色（由流程维护；挪牌按名字找牌区时先找它身上）
---@field lastTurnPlayer? Player # 上一个回合角色（回合结束后留作顺序锚点）
---@field private attributeSystem? AttributeSystem
---@field private zoneList Zone[]
---@field private zoneMap table<string, Zone>
---@field private effects Effect[] # 记牌器：发起过的根效果（只增）
---@field private events Event # 时机表（内容侧用 game:on / game:fire；每次装载会清空）
---@field private idCounter integer # 发号器（牌与将来的技能共用；重装内容也不重置）
---@field phase? Phase # 当前阶段（没进阶段就是空）
---@field private phaseStack Phase[] # 阶段栈（阶段可以嵌套：将来的「额外的一个出牌阶段」）
---@field private flow? fun(): any # 这一局的流程本体（内容登记，装配侧启动）
---@field private flowTask? Task # 流程任务（`endGame` 靠它把流程就地收掉）
---@field private result? Game.Result # 这一局的结果（有值就是已经结束了）
---@field private dirty? table<Player, table<string, boolean>> # 还没下发的脏玩家（下一笔调度统一发）
local M = Class 'Game'

---@param seats integer
---@param random Random
function M:__init(seats, random)
    self.desk     = moe.desk.create(self, seats)
    self.random   = random
    self.events   = moe.event.create()
    self.zoneList = {}
    self.zoneMap  = {}
    self.effects  = {}
    self.sources  = moe.loader.DEFAULT_SOURCES
    self.list     = {}
    self.idCounter = 0
    self.phaseStack = {}
    self:createZone('抽牌', true)
    self:createZone('弃牌')
    self:resetContent()
end

--- 把一个玩家的某类数据标脏（第一次标脏时登记一次 flush，下一笔调度统一发）
---@param player Player
---@param kind Player.DirtyKind
function M:markDirty(player, kind)
    local dirty = self.dirty
    if not dirty then
        dirty = {}
        self.dirty = dirty
        moe.await.wake(function ()
            self:flushDirty()
        end)
    end
    local kinds = dirty[player]
    if not kinds then
        kinds = {}
        dirty[player] = kinds
    end
    kinds[kind] = true
end

--- 把攒着的脏玩家统一下发
---@private
function M:flushDirty()
    local dirty = self.dirty
    if not dirty then
        return
    end
    self.dirty = nil
    moe.player.sendUpdates(self, dirty)
end

--- 清空这一局的规则内容（重装规则集时用）
function M:resetContent()
    self.cards       = {}
    self.packages    = {}
    self.buffs       = {}
    self.buffPackages = {}
    self.heroes      = {}
    self.heroPackages = {}
    self.skills      = {}
    self.skillPackages = {}
    self.meta        = {}
    self.values      = {}
    self.rule        = {}
    self.loadedFiles = {}
    self.flow        = nil
    self.turnPlayer  = nil
    self.lastTurnPlayer = nil
    self.attributeSystem = nil
    self.events:clear()
end

---@return AttributeSystem # 这一局的属性系统（没建过就现建）
function M:getAttributeSystem()
    self.attributeSystem = self.attributeSystem or moe.attribute.create()
    return self.attributeSystem
end

--- 设一条规则数值
---@param name string
---@param value any
function M:setValue(name, value)
    if type(name) ~= 'string' or name == '' then
        error('规则数值的名字必须是非空字符串', 2)
    end
    self.values[name] = value
end

--- 一次设一批规则数值
---@param values table<string, any>
function M:setValues(values)
    if type(values) ~= 'table' then
        error('规则数值必须是一张名字到值的表', 2)
    end
    for name, value in pairs(values) do
        self:setValue(name, value)
    end
end

--- 读一条规则数值
---@param name string
---@return any # 没设置过就是「不存在」
function M:getValue(name)
    if type(name) ~= 'string' or name == '' then
        error('规则数值的名字必须是非空字符串', 2)
    end
    return self.values[name]
end

---@return table<string, any> # 规则数值快照
function M:getValues()
    ---@type table<string, any>
    local result = {}
    for name, value in pairs(self.values) do
        result[name] = value
    end
    return result
end

--- 订阅一个时机
---@param name string
---@param callback fun(context: table): any
---@return function # 撤销这次注册
function M:on(name, callback)
    if type(name) ~= 'string' or name == '' then
        error('时机名必须是非空字符串', 2)
    end
    if type(callback) ~= 'function' then
        error('时机回调必须是函数', 2)
    end
    return self.events:on(name, callback)
end

--- 触发一个时机
---@param name string
---@param ... any
---@return any # 第一个回调明确给出的返回值（快速返回）；没人给就是空
function M:fire(name, ...)
    if type(name) ~= 'string' or name == '' then
        error('时机名必须是非空字符串', 2)
    end
    return self.events:fire(name, ...)
end

--- 触发一个时机并收集所有回调的返回值（修正链类用它；是非问 / 通知用 fire）
---@param name string
---@param ... any
---@return any[] # 每个回调的第一个返回值（没有 / 报错的不收）
function M:collect(name, ...)
    if type(name) ~= 'string' or name == '' then
        error('时机名必须是非空字符串', 2)
    end
    return self.events:collect(name, ...)
end

--- 进入一个回合阶段（返回的阶段可以当 `<close>` 用：作用域结束就离开；先发「开始」（只通知，技能在这里改「摸牌数」这类参数）再发「生效」（这个阶段的业务））
---@param player Player # 这个阶段属于谁
---@param name string # 阶段名（取值由你定）
---@return Phase
function M:enterPhase(player, name)
    if type(name) ~= 'string' or name == '' then
        error('阶段名必须是非空字符串', 2)
    end
    local phase = New 'Phase' (self, player, name)
    self.phaseStack[#self.phaseStack + 1] = phase
    self.phase = phase
    self:fire('阶段-开始', phase)
    player:fire('阶段-开始', phase)
    self:fire('阶段-生效', phase)
    player:fire('阶段-生效', phase)
    return phase
end

--- 离开这个阶段（阶段自己用：`<close>` 或 `Delete(阶段)`）
---@param phase Phase
function M:leavePhase(phase)
    if self.phase ~= phase then
        error('阶段只能按嵌套顺序离开', 2)
    end
    self:fire('阶段-结束', phase)
    phase.player:fire('阶段-结束', phase)
    self.phaseStack[#self.phaseStack] = nil
    self.phase = self.phaseStack[#self.phaseStack]
end

--- 这次使用要记在哪个阶段上（只在自己的阶段里记，别人的阶段里不记）
---@param user Player
---@return Phase? # 要记账的阶段（不记就是空）
function M:getUsePhase(user)
    local phase = self.phase
    if phase and phase.player == user then
        return phase
    end
end

--- 声明一张牌（只能写在加载期加载的那个包里）
---@param name string
---@return CardDef
function M:declareCard(name)
    local ctx = self.loading
    if not ctx then
        error('规则定义只能在加载规则集时声明', 2)
    end
    local owner = ctx.package
    if not owner then
        error('规则定义只能写在包目录里的文件里', 2)
    end
    checkSimpleName(name, 2)
    local cards = self.cards[owner]
    if not cards then
        cards = {}
        self.cards[owner] = cards
        self.packages[#self.packages+1] = owner
    end
    local existing = cards[name]
    if existing then
        error('同一个包里重复声明了 {}：{} 与 {}' % { name, existing.source, ctx.current }, 2)
    end
    local def = New 'CardDef' (self, name, owner, ctx.current)
    cards[name] = def
    return def
end

---@param name string
---@return CardDef? # 按名字找内容定义
function M:getCard(name)
    local owner, entry = splitName(name)
    if owner then
        local cards = self.cards[owner]
        return cards and cards[entry] or nil
    end
    local ctx  = self.loading
    local mine = ctx and ctx.package
    if mine then
        local cards = self.cards[mine]
        local found = cards and cards[entry]
        if found then
            return found
        end
    end
    for _, package in ipairs(self.packages) do
        local cards = self.cards[package]
        local found = cards and cards[entry]
        if found then
            return found
        end
    end
    return nil
end

--- 声明一只状态（只能写在加载期加载的那个包里）
---@param name string
---@return BuffDef
function M:declareBuff(name)
    local ctx = self.loading
    if not ctx then
        error('规则定义只能在加载规则集时声明', 2)
    end
    local owner = ctx.package
    if not owner then
        error('规则定义只能写在包目录里的文件里', 2)
    end
    checkSimpleName(name, 2)
    local buffs = self.buffs[owner]
    if not buffs then
        buffs = {}
        self.buffs[owner] = buffs
        self.buffPackages[#self.buffPackages + 1] = owner
    end
    local existing = buffs[name]
    if existing then
        error('同一个包里重复声明了 {}：{} 与 {}' % { name, existing.source, ctx.current }, 2)
    end
    local def = moe.buff.declare(name, owner, ctx.current)
    buffs[name] = def
    return def
end

---@param name string
---@return BuffDef? # 按名字找内容定义
function M:getBuff(name)
    local owner, entry = splitName(name)
    if owner then
        local buffs = self.buffs[owner]
        return buffs and buffs[entry] or nil
    end
    local ctx  = self.loading
    local mine = ctx and ctx.package
    if mine then
        local buffs = self.buffs[mine]
        local found = buffs and buffs[entry]
        if found then
            return found
        end
    end
    for _, package in ipairs(self.buffPackages) do
        local buffs = self.buffs[package]
        local found = buffs and buffs[entry]
        if found then
            return found
        end
    end
    return nil
end

--- 声明一个武将（只能写在加载期加载的那个包里）
---@param name string
---@return HeroDef
function M:declareHero(name)
    local ctx = self.loading
    if not ctx then
        error('规则定义只能在加载规则集时声明', 2)
    end
    local owner = ctx.package
    if not owner then
        error('规则定义只能写在包目录里的文件里', 2)
    end
    checkSimpleName(name, 2)
    local heroes = self.heroes[owner]
    if not heroes then
        heroes = {}
        self.heroes[owner] = heroes
        self.heroPackages[#self.heroPackages + 1] = owner
    end
    local existing = heroes[name]
    if existing then
        error('同一个包里重复声明了 {}：{} 与 {}' % { name, existing.source, ctx.current }, 2)
    end
    local def = New 'HeroDef' (self, name, owner, ctx.current)
    heroes[name] = def
    return def
end

---@param name string
---@return HeroDef? # 按名字找武将定义
function M:getHero(name)
    local owner, entry = splitName(name)
    if owner then
        local heroes = self.heroes[owner]
        return heroes and heroes[entry] or nil
    end
    local ctx  = self.loading
    local mine = ctx and ctx.package
    if mine then
        local heroes = self.heroes[mine]
        local found = heroes and heroes[entry]
        if found then
            return found
        end
    end
    for _, package in ipairs(self.heroPackages) do
        local heroes = self.heroes[package]
        local found = heroes and heroes[entry]
        if found then
            return found
        end
    end
    return nil
end

--- 这一局装了哪些武将（**按完整名排序** ⇒ 顺序稳定，同一个随机源可复现）
---@return HeroDef[] # 快照
function M:getHeroes()
    ---@type HeroDef[]
    local list = {}
    for _, package in ipairs(self.heroPackages) do
        for _, def in pairs(self.heroes[package]) do
            list[#list + 1] = def
        end
    end
    table.sort(list, function (a, b) return a.fullName < b.fullName end)
    return list
end

--- 声明一个技能（只能写在加载期加载的那个包里）
---@param name string
---@return SkillDef
function M:declareSkill(name)
    local ctx = self.loading
    if not ctx then
        error('规则定义只能在加载规则集时声明', 2)
    end
    local owner = ctx.package
    if not owner then
        error('规则定义只能写在包目录里的文件里', 2)
    end
    checkSimpleName(name, 2)
    local skills = self.skills[owner]
    if not skills then
        skills = {}
        self.skills[owner] = skills
        self.skillPackages[#self.skillPackages + 1] = owner
    end
    local existing = skills[name]
    if existing then
        error('同一个包里重复声明了 {}：{} 与 {}' % { name, existing.source, ctx.current }, 2)
    end
    local def = New 'SkillDef' (self, name, owner, ctx.current)
    skills[name] = def
    return def
end

---@param name string
---@return SkillDef? # 按名字找技能定义
function M:getSkill(name)
    local owner, entry = splitName(name)
    if owner then
        local skills = self.skills[owner]
        return skills and skills[entry] or nil
    end
    local ctx  = self.loading
    local mine = ctx and ctx.package
    if mine then
        local skills = self.skills[mine]
        local found = skills and skills[entry]
        if found then
            return found
        end
    end
    for _, package in ipairs(self.skillPackages) do
        local skills = self.skills[package]
        local found = skills and skills[entry]
        if found then
            return found
        end
    end
    return nil
end

---@param name string
---@return Loader.PackageMeta? # 这个包的元信息
function M:getPackageMeta(name)
    local meta = self.meta[name]
    if not meta then
        return nil
    end
    return copyMeta(meta)
end

---@return table<string, Loader.PackageMeta> # 所有包的元信息
function M:getMetas()
    ---@type table<string, Loader.PackageMeta>
    local result = {}
    for name, meta in pairs(self.meta) do
        result[name] = copyMeta(meta)
    end
    return result
end

--- 局上再建一个公共牌区
---@overload fun(self: Game, name: string, ordered: true): OrderedZone
---@param name string
---@param ordered? boolean # 需要有顺序能力（抽牌 / 弃牌之类）时传 true
---@return Zone
function M:createZone(name, ordered)
    if type(name) ~= 'string' or name == '' then
        error('牌区必须有个非空名字', 2)
    end
    if self.zoneMap[name] then
        error('局上已经有叫 {} 的牌区了' % { name }, 2)
    end
    local zone = ordered and New 'OrderedZone' (self, self.random) or New 'Zone' (self)
    zone:bindName(name)
    self.zoneMap[name] = zone
    self.zoneList[#self.zoneList+1] = zone
    return zone
end

--- 局上的公共牌区（`抽牌` / `弃牌` 由内核建好，包不得重建）
---@overload fun(self: Game, name: '抽牌'): OrderedZone
---@overload fun(self: Game, name: '弃牌'): Zone
---@param name string
---@return Zone?
function M:getZone(name)
    return self.zoneMap[name]
end

---@return Zone[] # 按创建顺序
function M:getZones()
    return moe.util.copy(self.zoneList)
end

--- 发一个新 ID（这一局内不重复；牌与将来的技能共用同一串号）
---@return integer
function M:nextId()
    self.idCounter = self.idCounter + 1
    return self.idCounter
end

--- 按牌名建一张牌（号由这一局发；花色与点数由调用方给）
---@param name string
---@param suit? string # 花色
---@param point? integer # 点数
---@return Card
function M:createCard(name, suit, point)
    if type(name) ~= 'string' or name == '' then
        error('牌名必须是非空字符串', 2)
    end
    return moe.card.create(self, name, self:nextId(), suit, point)
end

--- 按牌名建一张虚拟牌（原始牌可给一或多张；花色与点数默认：一张 ⇒ 抄它，其余 ⇒ 无）
---@param name string
---@param subcards? Card|Card[] # 对应的实体牌（可以不给、可以多张）
---@return Card
function M:createVirtualCard(name, subcards)
    if type(name) ~= 'string' or name == '' then
        error('牌名必须是非空字符串', 2)
    end
    return moe.card.createVirtual(self, name, self:nextId(), subcards)
end

--- 要一张牌
---@param to Player # 被问者
---@param reason? string # 这次为什么问（内容由发起方定；原样带到应答方）
---@param condition? AskCard.Condition # 要什么样的牌（省略 = 不做限制）
---@return AskCard # 这次询问（已经结完：答复读 `.card`（第一张）/ `.cards`（全部）/ `.targets`，失败读 `.err`）
---@async
function M:askCard(to, reason, condition)
    local ask = moe.askCard.create {
        game      = self,
        to        = to,
        reason    = reason,
        condition = condition,
    }
    ask:apply():await()
    return ask
end

--- 要一张牌（要一次给出：一批牌 + 接收它们的角色）
---@param to Player # 被问者
---@param reason? string # 这次为什么问（内容由发起方定；原样带到应答方）
---@param conditions? AskCardWithTarget.Conditions # 两半条件（牌那半 `card`、目标那半 `target`；省略 = 都不做限制）
---@return AskCardWithTarget # 这次询问（已经结完：答复读 `.cards`（全部）/ `.target`（第一个目标）、`.targets`（全部目标），失败读 `.err`）
---@async
function M:askCardWithTarget(to, reason, conditions)
    local ask = moe.askCardWithTarget.create {
        game       = self,
        to         = to,
        reason     = reason,
        conditions = conditions,
    }
    ask:apply():await()
    return ask
end

--- 起一次「要一张牌并使用」的询问：**只到 apply** —— 不等它、也不替你用出去
---@param to Player # 被问者
---@param reason? string # 这次为什么问（内容由发起方定；原样带到应答方）
---@param condition? AskUseCard.Condition # 要什么样的牌（比 `askCard` 多一条 `target`；省略 = 不做限制）
---@param useOptions? Game.UseOptions # 这次使用的选项（候选收集与用出去都带上）
---@return AskUseCard # 这次询问（还没结完：等它用 `:await()`，用出去用 `:use()`）
function M:startAskUseCard(to, reason, condition, useOptions)
    local ask = moe.askUseCard.create {
        game       = self,
        to         = to,
        reason     = reason,
        condition  = condition,
        useOptions = useOptions,
    }
    ask:apply()
    return ask
end

--- 要一张牌（要一次使用：能用的牌 + 目标）—— 答复到手后**直接把它用出去**（结果读 `ask.useCard`）
---@async
---@param to Player # 被问者
---@param reason? string # 这次为什么问（内容由发起方定；原样带到应答方）
---@param condition? AskUseCard.Condition # 要什么样的牌（比 `askCard` 多一条 `target`；省略 = 不做限制）
---@param useOptions? Game.UseOptions # 这次使用的选项（候选收集与用出去都带上）
---@return AskUseCard # 这次询问（已经结完：答复读 `.card` / `.targets`，那次使用读 `.useCard`，失败读 `.err`）
function M:askUseCard(to, reason, condition, useOptions)
    local ask = self:startAskUseCard(to, reason, condition, useOptions)
    ask:await()
    ask:use()
    return ask
end

--- 起一次「要一个技能发动」的询问：**只到 apply** —— 不等它、也不替你发动出去
---@param to Player # 被问者
---@param reason? string # 这次为什么问（内容由发起方定；原样带到应答方）
---@return AskUseSkill # 这次询问（还没结完：等它用 `:await()`，发动用 `:use()`）
function M:startAskUseSkill(to, reason)
    local ask = moe.askUseSkill.create {
        game   = self,
        to     = to,
        reason = reason,
    }
    ask:apply()
    return ask
end

--- 要一个技能发动（候选 = 他身上的主动技）—— 答复到手后**直接发动它**（结果读 `ask.cast`）
---@async
---@param to Player # 被问者
---@param reason? string # 这次为什么问（内容由发起方定；原样带到应答方）
---@return AskUseSkill # 这次询问（已经结完：答复读 `.skill`，那次发动读 `.cast`，失败读 `.err`）
function M:askUseSkill(to, reason)
    local ask = self:startAskUseSkill(to, reason)
    ask:await()
    ask:use()
    return ask
end

--- 要一张牌（要一次「对一张牌的使用」：能对目标牌使用的牌才进选项）—— 答复到手后**直接把它用出去**（结果读 `ask.useCardToCard`）
---@async
---@param to Player # 被问者
---@param reason? string # 这次为什么问（内容由发起方定；原样带到应答方）
---@param condition AskUseCardToCard.Condition # 要什么样的牌（`target` = 要用在哪张牌上）
---@return AskUseCardToCard # 这次询问（已经结完：答复读 `.card`，那次使用读 `.useCardToCard`，失败读 `.err`）
function M:askUseCardToCard(to, reason, condition)
    local ask = moe.askUseCardToCard.create {
        game      = self,
        to        = to,
        reason    = reason,
        condition = condition,
    }
    ask:apply():await()
    ask:use()
    return ask
end

--- 要一张打出的牌（答复的牌当场交出来，进发起这次结算的临时处理区）
--- 给了 `responseTo` = 一次**响应**：没答上就是「取消」；答复到手就算这次响应成立（发「被响应」两段时机）
---@async
---@param to Player # 被问者
---@param reason? string # 这次为什么问（内容由发起方定；原样带到应答方）
---@param condition? AskCard.Condition # 要什么样的牌（省略 = 不做限制）
---@param responseOptions? AskCard.ResponseOptions # 这次询问的额外交代（如「这次响应冲哪次使用」）
---@return AskPlayCard # 这次询问（已经结完：答复读 `.card`，**响应成立吗读 `.success`**，失败读 `.err`）
function M:askPlayCard(to, reason, condition, responseOptions)
    local ask = moe.askPlayCard.create {
        game            = self,
        to              = to,
        reason          = reason,
        condition       = condition,
        responseOptions = responseOptions,
    }
    ask:apply():await()
    return ask
end

--- 要一名角色（候选名单由内核摆好，答复必须是里面的一个）
---@async
---@param to Player # 被问者
---@param reason? string # 这次为什么问（内容由发起方定；原样带到应答方）
---@param condition? AskPlayer.Condition # 要什么样的角色（候选名单 + `min` / `max` 个数区间；省略 = 不做限制、正好一名）
---@return AskPlayer # 这次询问（已经结完：答复读 `.player` / `.players`，失败读 `.err`）
function M:askPlayer(to, reason, condition)
    local ask = moe.askPlayer.create {
        game      = self,
        to        = to,
        reason    = reason,
        condition = condition,
    }
    ask:apply():await()
    return ask
end

--- 要一个决策（问什么、答什么都由发起方解释）
---@async
---@param to Player # 被问者
---@param reason? string # 这次为什么问（内容由发起方定；原样带到应答方）
---@param question any # 问什么（内容由发起方定，应答方自己解释）
---@return Ask # 这次询问（已经结完：答复读 `.reply`，失败读 `.err`）
function M:ask(to, reason, question)
    local ask = moe.ask.create {
        game     = self,
        to       = to,
        reason   = reason,
        question = question,
    }
    ask:apply():await()
    return ask
end

--- 要他在若干选项里挑一个（选项由发起方给，答复必须是其中之一）
---@async
---@param to Player # 被问者
---@param reason? string # 这次为什么问（内容由发起方定；原样带到应答方）
---@param options string[] # 有哪些可选项（内容由发起方定，应答方自己解释）
---@return AskChoice # 这次询问（已经结完：结果读 `.result`，失败读 `.err`）
function M:askChoice(to, reason, options)
    local ask = moe.askChoice.create {
        game    = self,
        to      = to,
        reason  = reason,
        options = options,
    }
    ask:apply():await()
    return ask
end

--- 要他在一块面板上摆 / 挑（`{ moveable = true }` 才允许移动牌）—— 一次询问**开着**到点「确定」为止，中间可以来回很多次
---@async
---@param to Player # 被问者
---@param reason? string # 这次为什么问（内容由发起方定；原样带到应答方）
---@param panel Panel # 摆在哪块面板上（内容侧用 `createPanel` 建）
---@return AskPanel # 这次询问（已经结完：各行读 `.rows`、选中的牌读 `.card` / `.cards`，失败读 `.err`）
function M:askPanel(to, reason, panel)
    local ask = moe.askPanel.create {
        game   = self,
        to     = to,
        reason = reason,
        panel  = panel,
    }
    ask:apply():await()
    return ask
end

--- 要他在若干武将里挑（候选名单由发起方给；左慈那类「挑别人的武将」也用它）
---@async
---@param to Player # 被问者
---@param reason? string # 这次为什么问（内容由发起方定；原样带到应答方）
---@param condition? AskHero.Condition # 要什么样的武将（省略 = 不做限制）
---@return AskHero # 这次询问（已经结完：答复读 `.hero` / `.heroes`，失败读 `.err`）
function M:askHero(to, reason, condition)
    local ask = moe.askHero.create {
        game      = self,
        to        = to,
        reason    = reason,
        condition = condition,
    }
    ask:apply():await()
    return ask
end

--- 一次「几路取先」的赢家
---@class Game.AnyWinner
---@field win integer # 赢家编号
---@field effect Effect # 赢家那一路

--- 等这几路，**第一个「算数」的算赢、其余当场取消**
---@async
---@param effects Effect[] # 已经起好的几路（`start` 系列入口的产物）
---@param accept? fun(effect: Effect): boolean # 这一路算不算数（省略 = 结完就算）；不算数的路接着等别的路
---@return Game.AnyWinner? # 赢家（都结完还没一路算数 = nil）
function M:effectRace(effects, accept)
    local count = #effects
    local win = moe.await.yield(function (resume)
        local alive = count
        local function done()
            alive = alive - 1
            if alive == 0 then
                resume(nil)
            end
        end
        for i = 1, count do
            local effect = effects[i]
            local task   = effect.task
            assert(task, '这一路还没有起（先用 start 系列入口起好）')
            task:onResolved(function ()
                if not accept or accept(effect) then
                    resume(i)
                else
                    done()
                end
            end)
            task:onRejected(done)
        end
    end)
    if not win then
        return nil
    end
    for i = 1, count do
        if i ~= win then
            effects[i]:cancel()
        end
    end
    return {
        win    = win,
        effect = effects[win],
    }
end

--- 造一次撑牌、驱动并等它结完
---@async
---@param game Game
---@param cards Card[]
---@param zone? string|Zone
---@param visible? Visibility
---@return MoveCard
local function runMoveCard(game, cards, zone, visible)
    local effect = moe.moveCard.create {
        game    = game,
        cards   = cards,
        zone    = zone,
        visible = visible,
    }
    effect:apply():await()
    return effect
end

--- 把牌挪到某个牌区
---@async
---@param card Card|Card[] # 要挪的牌（单张或一批）
---@param zone? string|Zone # 目标牌区：名字或牌区对象（名字先在当前回合角色身上找；不给 = 这次挪牌失败）
---@param visible? Visibility # 这次搬动对谁可见（不给 = 源区可见 or 目标区可见，由读的人算）
---@return MoveCard # 这次挪牌（已经结完：失败读 `.err`）
function M:moveCard(card, zone, visible)
    return runMoveCard(self, moe.util.toList(card), zone, visible)
end

--- 抽牌：从抽牌堆顶抽 count 张（省略去向 = 抽进这个玩家的手牌；给了就用它，例如抽到某块处理区）
---@async
---@param player Player # 谁抽
---@param count integer # 抽几张
---@param to? Zone # 抽到哪个牌区（省略 = 该玩家的手牌区）
---@return Card[] # 实际抽到的牌（牌堆不够时可能少于 count）
function M:drawCards(player, count, to)
    local cards = self:getZone('抽牌'):draw(count)
    if #cards > 0 then
        self:moveCard(cards, to or player:getZone('手牌'))
    end
    return cards
end

---@param game Game
---@param def CardDef
---@param user Player
---@param card Card
---@param targets? Player[] # 期望的目标
---@param useOptions? Game.UseOptions # 这次使用的选项（放进上下文给谓词）
---@return Player[]? # 合法目标（逐角色过全部 filter）
---@return string? # 不成立的原因
local function collectLegalTargets(game, def, user, card, targets, useOptions)
    local condition = def.targetCondition
    if not condition then
        return nil, '「{}」没有声明目标条件，现在用不了' % { def.fullName }
    end
    ---@type CardDef.TargetPlan
    local plan = {
        user       = user,
        card       = card,
        targets    = targets,
        useOptions = useOptions,
    }
    ---@type Player[]
    local legal = {}
    for _, player in ipairs(game.desk.alivePlayers) do
        local ok = true
        for _, filter in ipairs(condition.filter) do
            if not filter(player, plan) then
                ok = false
                break
            end
        end
        if ok then
            -- 候选者自己也能否决（「不能成为目标」类技能；返回非空就是不能指定他）
            if player:fire('卡牌-目标-能否指定', plan) == nil then
                legal[#legal + 1] = player
            end
        end
    end
    if #legal == 0 then
        return nil, '「{}」现在没有合法目标' % { def.fullName }
    end
    return legal
end

--- 目标那半：筛出合法目标 +（给了目标时）校验个数与归属
---@param game Game
---@param def CardDef
---@param user Player
---@param card Card
---@param targets? Player[] # 要校验的目标（省略 = 不判目标那一条）
---@param useOptions? Game.UseOptions
---@return boolean # 这块成立吗
---@return any # 不成立的原因
---@return Game.UsableTargets? # 成立时的可用目标与数量区间
local function checkTargets(game, def, user, card, targets, useOptions)
    local min, max = card:getTargetCount(useOptions)
    if min == 0 and max == 0 then
        if targets and #targets > 0 then
            return false, '「{}」不需要指定目标' % { def.fullName }
        end
        return true, nil, { legal = {}, min = min, max = max }
    end
    local legal, reason = collectLegalTargets(game, def, user, card, targets, useOptions)
    if not legal then
        return false, reason
    end
    max = math.min(max, #legal)
    if targets then
        if #targets < min then
            return false, '「{}」至少要指定 {} 个目标' % { def.fullName, min }
        end
        if #targets > max then
            return false, '「{}」至多指定 {} 个目标' % { def.fullName, max }
        end
        ---@type Player[]
        local wanted = {}
        for _, player in ipairs(targets) do
            if not moe.util.arrayHas(legal, player) then
                return false, '「{}」不能以这个角色为目标' % { def.fullName }
            end
            if moe.util.arrayHas(wanted, player) then
                return false, '「{}」不能重复指定同一个目标' % { def.fullName }
            end
            wanted[#wanted + 1] = player
        end
        legal = wanted
    end
    return true, nil, { legal = legal, min = min, max = max }
end

--- 牌本身能不能用（两条入口共用）：在使用者身上 / 所在区没被禁用 / 在声明的牌区 / 次数（虚拟牌不进牌区，前三条跳过）
---@param game Game
---@param user Player
---@param card Card
---@param useOptions? Game.UseOptions # 这次使用的选项（`ignoreUseLimit` 跳过次数检查）
---@return CardDef? # 能用时给出定义
---@return any # 不能时的原因
local function checkCardItself(game, user, card, useOptions)
    local name = card.name
    local def  = card.def
    if not card.virtual then
        local zone = user:findCard(card)
        if not zone then
            return nil, '使用者手上没有这张牌'
        end
        if not zone:isEnabled() then
            return nil, '「{}」在的牌区被禁用了，用不了' % { name }
        end
        local useZone = def:getZone()
        if useZone and zone ~= user:getZone(useZone) then
            return nil, '「{}」只能从「{}」里用' % { def.fullName, useZone }
        end
    end
    local phase = game:getUsePhase(user)
    if phase and not useOptions?.ignoreUseLimit then
        local limit = def:getLimit(phase.name) + user:getLimitDelta(name, phase.name)
        if phase:getUseCount(name) >= limit then
            return nil, '本阶段已经用过「{}」了' % { name }
        end
    end
    return def, nil
end

--- 把内容侧给这次使用加的选项并进 `base`（全局 + 使用者各问一份；返回新表）
---@param user Player
---@param card Card
---@param base? Game.UseOptions # 调用方已有的选项（并入结果）
---@param targets? Player[] # 这次使用的目标（内容侧若给 `true` / 谓词，按它解算）
---@return Game.UseOptions
function M:mergeUseOptions(user, card, base, targets)
    local check = { user = user, card = card }
    local parts = self:collect('卡牌-使用选项', check)
    moe.util.arrayMerge(parts, user:collect('卡牌-来源-使用选项', check))
    local result = base
    for _, part in ipairs(parts) do
        if type(part) == 'table' then
            result = moe.useCard.mergeOptions(result, part, targets)
        end
    end
    return result or {}
end

--- 这张牌此刻的全量合法目标（跑牌的 filter + 问候选者「能不能被指定」；**不合并选项、不判「能不能用」**）
--- 选项由调用方自己给（要叠加就自己叠好再传）—— 改目标 / 「也成为目标」类效果用它：先拿到全量，再自己交叉
---@param user Player # 使用者
---@param card Card # 要用（或已在用）的牌
---@param useOptions? Game.UseOptions # 这次使用的选项
---@return Player[] # 合法目标（一个都没有 / 牌没声明目标条件 = 空表）
function M:getLegalTargets(user, card, useOptions)
    return collectLegalTargets(self, card.def, user, card, nil, useOptions) or {}
end

---@param user Player # 使用者
---@param card Card # 要用的牌
---@param target? Player|Player[] # 要校验的目标（省略 = 不判目标那一条）
---@param useOptions? Game.UseOptions # 这次使用的选项（见 `Game.UseOptions`）
---@return boolean # 能这样用吗
---@return any # 不能的原因
---@return Game.UsableTargets? # 能用时的可用目标与数量区间（「不指定目标」的牌是 legal 空表、0、0）
function M:canUse(user, card, target, useOptions)
    ---@type Player[]?
    local targets = target and moe.util.toList(target)
    -- 内容侧可以给这次使用加选项（【奇才】这类）：校验与候选收集都按合并后的来
    useOptions = self:mergeUseOptions(user, card, useOptions, targets)

    local def, problem = checkCardItself(self, user, card, useOptions)
    if not def then
        return false, problem
    end

    local ok, reason, plan = checkTargets(self, def, user, card, targets, useOptions)
    if not ok then
        return false, reason
    end

    -- 内容侧有没有异议
    local refusal = self:fire('卡牌-能否使用', {
        user = user,
        card = card,
        targets = targets
    })
    if refusal ~= nil then
        if refusal == false then
            refusal = '这张牌现在不能使用'
        end
        return false, refusal
    end
    return true, nil, plan
end

--- 这张牌此刻能不能「对一张牌使用」（合法性由 `cardTargets` 条件给出；目标牌由发起方给定）
---@param user Player # 使用者
---@param card Card # 要用的牌
---@param targetCard? Card # 要用在哪张牌上（省略 = 只判「这类牌能不能对牌使用」）
---@return boolean # 能这样用吗
---@return any # 不能的原因
function M:canUseToCard(user, card, targetCard)
    local def, problem = checkCardItself(self, user, card)
    if not def then
        return false, problem
    end
    local condition = def.cardTargetCondition
    if not condition then
        return false, '「{}」没有声明对牌目标条件，不能对牌使用' % { def.fullName }
    end
    if targetCard then
        ---@type CardDef.CardTargetPlan
        local plan = { user = user, card = card, targets = { targetCard } }
        local accepted = true
        for _, filter in ipairs(condition.filter) do
            if not filter(targetCard, plan) then
                accepted = false
                break
            end
        end
        if not accepted then
            return false, '「{}」不能对这张牌使用' % { def.fullName }
        end
    end

    -- 内容侧有没有异议
    local refusal = self:fire('卡牌-能否使用', { user = user, card = card, target = targetCard })
    if refusal ~= nil then
        if refusal == false then
            refusal = '这张牌现在不能使用'
        end
        return false, refusal
    end
    return true, nil
end

---@async
---@param user Player # 使用者
---@param card Card # 被使用的牌
---@param targets? Player|Player[] # 目标：单个或列表（无目标牌给空表或省略）
---@param useOptions? Game.UseOptions # 这次使用的选项（放行 / 记账用；见 `Game.UseOptions`）
---@return UseCard # 这次用牌（已经结完：结果读 `.result`，失败读 `.err`）
function M:useCard(user, card, targets, useOptions)
    local effect = moe.useCard.create {
        game       = self,
        user       = user,
        card       = card,
        targets    = moe.util.toList(targets),
        useOptions = useOptions,
    }
    effect:apply():await()
    return effect
end

---@async
---@param user Player # 使用者
---@param card Card # 被使用的牌
---@param targetCard Card # 目标：一张牌（例如【无懈可击】要对的那张锦囊）
---@return UseCardToCard # 这次用牌（已经结完：结果读 `.result`，失败读 `.err`）
function M:useCardToCard(user, card, targetCard)
    local effect = moe.useCardToCard.create {
        game       = self,
        user       = user,
        card       = card,
        targetCard = targetCard,
    }
    effect:apply():await()
    return effect
end

--- 记一条根效果（只有内核自己用）
---@param effect Effect
function M:addEffect(effect)
    self.effects[#self.effects + 1] = effect
end

---@return Effect? # 最近发起过的那个根效果
function M:getEffect()
    return self.effects[#self.effects]
end

---@return Effect[] # 记牌器快照：发起过的根效果（按发起顺序）
function M:getEffects()
    return moe.util.copy(self.effects)
end

--- 登记这一局的流程（加载期由内容登记，每局只能一个）
---@param handler fun(): any # 流程本体
function M:registerFlow(handler)
    if not self.loading then
        error('流程登记只能在加载规则集时声明', 2)
    end
    if type(handler) ~= 'function' then
        error('流程必须是一个函数', 2)
    end
    if self.flow then
        error('这一局已经登记过流程了', 2)
    end
    self.flow = handler
end

--- 跑这一局的流程：返回任务（等它跑完用 `:await()`，要停它用 `:cancel()`）
---@return Task
function M:runFlow()
    local handler = self.flow
    if not handler then
        error('这一局没有登记流程', 2)
    end
    local task    = moe.task.create { game = self }
    self.flowTask = task
    task:executeSync(function ()
        return handler()
    end)
    return task
end

--- 这一局的结果（还没结束就是「不存在」）
---@return Game.Result?
function M:getResult()
    return self.result
end

--- 结束这一局：记下结果、触发「游戏-结束」、把流程就地收掉（只认第一次）
---@param result Game.Result
function M:endGame(result)
    if self.result then
        return
    end
    self.result = result
    self:fire('游戏-结束', result)
    self.flowTask?:cancel()
end

---@class Game.API
moe.game = {}

--- 建一局（建完就把规则集装好）
---@param options Game.CreateOptions
---@return Game
function moe.game.create(options)
    if not options or not options.seats or not options.random then
        error('建局需要一个座位数与一个随机源', 2)
    end
    local game = New 'Game' (options.seats, options.random)
    moe.loader.install(game, {
        sources  = options.sources,
        packages = options.packages,
    })
    return game
end
