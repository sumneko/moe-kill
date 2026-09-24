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
---@field private noTargetFlag? boolean # 不指定目标
---@field private useZone? string # 必须从哪个牌区用（没声明 = 使用者任一牌区都行）
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
    self.handlers = {}
    self.limits   = {}
    self.kinds    = {}
    self.kindSet  = {}
    self.values   = {}
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
    ---@type function[]
    local snapshot = {}
    local list = self.handlers[event]
    if list then
        table.move(list, 1, #list, 1, snapshot)
    end
    return snapshot
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
    ---@type string[]
    local snapshot = {}
    table.move(self.kinds, 1, #self.kinds, 1, snapshot)
    return snapshot
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

--- 声明这张牌不指定目标（装备牌这类）：用牌时不再要求给目标
---@return CardDef
function CardDef:noTarget()
    self.noTargetFlag = true
    return self
end

--- 这张牌是不是不指定目标
---@return boolean
function CardDef:isNoTarget()
    return self.noTargetFlag == true
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

--- 把另一个定义的钩子与字段抖过来（基类的钩子跑在前面；抖完就与基类脱钩）
---@param name string # 基类定义的名字（支持限定名）
---@return CardDef
function CardDef:extends(name)
    local base = self.game:getCard(name)
    if not base then
        error('找不到要继承的定义「{}」' % { name }, 2)
    end
    for event, list in pairs(base.handlers) do
        ---@type function[]
        local merged = {}
        table.move(list, 1, #list, 1, merged)
        local own = self.handlers[event]
        if own then
            table.move(own, 1, #own, #merged + 1, merged)
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
    if base.noTargetFlag then
        self.noTargetFlag = true
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
        depends  = {},
        excludes = {},
        entries  = {},
        files    = {},
    }
    table.move(meta.depends, 1, #meta.depends, 1, copy.depends)
    table.move(meta.excludes, 1, #meta.excludes, 1, copy.excludes)
    table.move(meta.entries, 1, #meta.entries, 1, copy.entries)
    for i, file in ipairs(meta.files) do
        ---@type Loader.MetaFile
        local copied = {
            logical = file.logical,
            source  = file.source,
            ok      = file.ok,
            err     = file.err,
            entries = {},
        }
        table.move(file.entries, 1, #file.entries, 1, copied.entries)
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
---@class Game
---@field list string[] # 上一次用的加载清单
---@field private cards table<string, table<string, CardDef>> # 规则表：包名 → 裸名 → 定义
---@field private packages string[] # 包的加载顺序（首次出现的顺序）
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
---@field private dyingMap table<Player, Dying> # 每个玩家当前那次濒死（1:1：一次只有一个濒死状态）
---@field private flow? fun(): any # 这一局的流程本体（内容登记，装配侧启动）
---@field private flowTask? Task # 流程任务（`endGame` 靠它把流程就地收掉）
---@field private result? Game.Result # 这一局的结果（有值就是已经结束了）
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
    self.dyingMap = {}
    self:createZone('抽牌', true)
    self:createZone('弃牌')
    self:resetContent()
end

--- 清空这一局的规则内容（重装规则集时用）
function M:resetContent()
    self.cards       = {}
    self.packages    = {}
    self.meta        = {}
    self.values      = {}
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
---@param callback fun(context: table)
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

--- 进入一个回合阶段（返回的阶段可以当 `<close>` 用：作用域结束就离开）
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
    return phase
end

--- 离开这个阶段（阶段自己用：`<close>` 或 `Delete(阶段)`）
---@param phase Phase
function M:leavePhase(phase)
    if self.phase ~= phase then
        error('阶段只能按嵌套顺序离开', 2)
    end
    self:fire('阶段-结束', phase)
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
    ---@type Zone[]
    local snapshot = {}
    table.move(self.zoneList, 1, #self.zoneList, 1, snapshot)
    return snapshot
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

--- 要一张牌
---@param to Player # 被问者
---@param reason? string # 这次为什么问（内容由发起方定；原样带到应答方）
---@param condition? AskCard.Condition # 要什么样的牌（省略 = 不做限制）
---@return AskCard # 这次询问（已经结完：答复读 `.card` / `.targets`，失败读 `.err`）
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

--- 要一张牌（要一次使用：能用的牌 + 目标）—— 答复到手后**直接把它用出去**（结果读 `ask.useCard`）
---@async
---@param to Player # 被问者
---@param reason? string # 这次为什么问（内容由发起方定；原样带到应答方）
---@param condition? AskUseCard.Condition # 要什么样的牌（比 `askCard` 多一条 `target`；省略 = 不做限制）
---@return AskUseCard # 这次询问（已经结完：答复读 `.card` / `.targets`，那次使用读 `.useCard`，失败读 `.err`）
function M:askUseCard(to, reason, condition)
    local ask = moe.askUseCard.create {
        game      = self,
        to        = to,
        reason    = reason,
        condition = condition,
    }
    ask:apply():await()
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
---@async
---@param to Player # 被问者
---@param reason? string # 这次为什么问（内容由发起方定；原样带到应答方）
---@param condition? AskCard.Condition # 要什么样的牌（省略 = 不做限制）
---@return AskPlayCard # 这次询问（已经结完：答复读 `.card`，失败读 `.err`）
function M:askPlayCard(to, reason, condition)
    local ask = moe.askPlayCard.create {
        game      = self,
        to        = to,
        reason    = reason,
        condition = condition,
    }
    ask:apply():await()
    return ask
end

--- 要一名角色（候选名单由内核摆好，答复必须是里面的一个）
---@async
---@param to Player # 被问者
---@param reason? string # 这次为什么问（内容由发起方定；原样带到应答方）
---@param condition? AskPlayer.Condition # 要什么样的角色（省略 = 不做限制）
---@return AskPlayer # 这次询问（已经结完：答复读 `.player`，失败读 `.err`）
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

--- 把牌挪到某个牌区
---@async
---@param card Card|Card[] # 要挪的牌（单张或一批）
---@param zone? string|Zone # 目标牌区：名字或牌区对象（名字先在当前回合角色身上找；不给 = 这次挪牌失败）
---@return MoveCard # 这次挪牌（已经结完：失败读 `.err`）
function M:moveCard(card, zone)
    local cards = moe.util.toList(card)
    local effect = moe.moveCard.create {
        game  = self,
        cards = cards,
        zone  = zone,
    }
    effect:apply():await()
    return effect
end

--- 造成一次伤害
---@async
---@param from Player # 伤害来源
---@param to Player # 承受者
---@param amount integer # 点数
---@return Damage # 这次伤害（已经结完：结果读 `.result`，失败读 `.err`）
function M:damage(from, to, amount)
    local damage = moe.damage.create {
        game   = self,
        from   = from,
        to     = to,
        amount = amount,
    }
    damage:apply():await()
    return damage
end

--- 回复一次体力
---@async
---@param to Player # 谁回复体力
---@param amount integer # 点数
---@return Heal # 这次回复（已经结完：失败读 `.err`）
function M:heal(to, amount)
    local heal = moe.heal.create {
        game   = self,
        to     = to,
        amount = amount,
    }
    heal:apply():await()
    return heal
end

--- 摸一次牌
---@async
---@param player Player # 谁摸牌（已阵亡的不摸）
---@param count integer # 摸几张
---@return Draw # 这次摸牌（已经结完：失败读 `.err`）
function M:draw(player, count)
    local draw = moe.draw.create {
        game   = self,
        player = player,
        count  = count,
    }
    draw:apply():await()
    return draw
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

--- 让某个人判定
---@async
---@param player Player # 谁的判定
---@param reason? string # 为什么判（内容由发起方定）
---@return Judge # 这次判定（已经结完：结果读 `.card`，失败读 `.err`）
function M:judge(player, reason)
    local judge = moe.judge.create {
        game   = self,
        player = player,
        reason = reason,
    }
    judge:apply():await()
    return judge
end

---@param def CardDef
---@param user Player
---@param card Card
---@param targets? Player[] # 期望的目标
---@return Player[]? # 各声明取交集后的合法目标
---@return string? # 不成立的原因
local function collectLegalTargets(def, user, card, targets)
    local handlers = def:getHandlers('获取目标')
    if #handlers == 0 then
        return nil, '「{}」没有声明「获取目标」，现在用不了' % { def.fullName }
    end
    ---@type CardDef.TargetPlan
    local ctx = {
        user = user,
        card = card,
        targets = targets
    }
    ---@type Player[][]
    local lists = {}
    for _, handler in ipairs(handlers) do
        local list = handler(ctx)
        if type(list) ~= 'table' then
            return nil, '「{}」的「获取目标」必须返回合法目标列表' % { def.fullName }
        end
        lists[#lists + 1] = list
    end
    ---@type Player[]
    local legal = moe.util.arrayIntersect(lists)
    if #legal == 0 then
        return nil, '「{}」现在没有合法目标' % { def.fullName }
    end
    return legal
end

--- 牌本身能不能用（两条入口共用）：牌名 / 定义 / 在使用者身上 / 在声明的牌区 / 次数
---@param game Game
---@param user Player
---@param card Card
---@return CardDef? # 能用时给出定义
---@return any # 不能时的原因
local function checkCardItself(game, user, card)
    local name = card.name
    if type(name) ~= 'string' then
        return nil, '这张牌没有牌名，查不到内容定义'
    end
    local def = game:getCard(name)
    if not def then
        return nil, '没有叫「{}」的内容定义' % { name }
    end
    local zone = user:findCard(card)
    if not zone then
        return nil, '使用者手上没有这张牌'
    end
    local useZone = def:getZone()
    if useZone and zone ~= user:getZone(useZone) then
        return nil, '「{}」只能从「{}」里用' % { def.fullName, useZone }
    end
    local phase = game:getUsePhase(user)
    if phase then
        local limit = def:getLimit(phase.name) + phase:getLimitDelta(name)
        if phase:getUseCount(name) >= limit then
            return nil, '本阶段已经用过「{}」了' % { name }
        end
    end
    return def, nil
end

---@param user Player # 使用者
---@param card Card # 要用的牌
---@param target? Player|Player[] # 要校验的目标（省略 = 不判目标那一条）
---@return boolean # 能这样用吗
---@return any # 不能的原因
---@return Player[]? # 能用时的合法目标（无目标牌没有）
function M:canUse(user, card, target)
    local def, problem = checkCardItself(self, user, card)
    if not def then
        return false, problem
    end

    ---@type Player[]?
    local targets = target and moe.util.toList(target)

    -- 目标：给了目标才判（无目标牌给了非空目标就是不成立）
    ---@type Player[]? # 能用时的合法目标（无目标牌没有）
    local legal = nil
    if def:isNoTarget() then
        if targets and #targets > 0 then
            return false, '「{}」不需要指定目标' % { def.fullName }
        end
    else
        local reason
        legal, reason = collectLegalTargets(def, user, card, targets)
        if not legal then
            return false, reason
        end
        if targets then
            if #targets == 0 then
                return false, '「{}」至少要指定一个目标' % { def.fullName }
            end
            ---@type Player[]
            local wanted = {}
            for _, player in ipairs(targets) do
                if not moe.util.arrayHas(legal, player) then
                    return false, '「{}」不能以这个角色为目标' % { def.fullName }
                end
                wanted[#wanted + 1] = player
            end
            legal = wanted
        end
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
    return true, nil, legal
end

--- 这张牌此刻能不能「对一张牌使用」（合法性由「获取卡牌目标」给出；目标牌由发起方给定）
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
    local handlers = def:getHandlers('获取卡牌目标')
    if #handlers == 0 then
        return false, '「{}」没有声明「获取卡牌目标」，不能对牌使用' % { def.fullName }
    end
    if targetCard then
        ---@type CardDef.CardTargetPlan
        local ctx = { user = user, card = card, targets = { targetCard } }
        ---@type Card[][]
        local lists = {}
        for _, handler in ipairs(handlers) do
            local list = handler(ctx)
            if type(list) ~= 'table' then
                return false, '「{}」的「获取卡牌目标」必须返回合法目标列表' % { def.fullName }
            end
            lists[#lists + 1] = list
        end
        if not moe.util.arrayHas(moe.util.arrayIntersect(lists), targetCard) then
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
---@return UseCard # 这次用牌（已经结完：结果读 `.result`，失败读 `.err`）
function M:useCard(user, card, targets)
    local effect = moe.useCard.create {
        game    = self,
        user    = user,
        card    = card,
        targets = moe.util.toList(targets),
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
    ---@type Effect[]
    local snapshot = {}
    table.move(self.effects, 1, #self.effects, 1, snapshot)
    return snapshot
end

--- 让某人进入濒死：当场结算（规则侧在 `'濒死-进入'` 里求桃、回正时喊 `leave()`）
---@param player Player
---@param damage? Damage # 把它打到濒死的这次伤害
---@return Dying # 新起的已经结完；他已经在濒死中就直接返回那一次（致死伤害换成这一次）
---@async
function M:enterDying(player, damage)
    local current = self.dyingMap[player]
    if current and not current:hasLeft() then
        current.damage = damage
        return current
    end
    local dying = moe.dying.create {
        game   = self,
        player = player,
        damage = damage,
    }
    self.dyingMap[player] = dying
    dying:apply():await()
    return dying
end

--- 他现在正在濒死中的那次结算（没有就是空）
---@param player Player
---@return Dying?
function M:getDying(player)
    return self.dyingMap[player]
end

--- 清掉这个玩家当前的濒死账（那次结算自己用）
---@param dying Dying
function M:clearDying(dying)
    if self.dyingMap[dying.player] == dying then
        self.dyingMap[dying.player] = nil
    end
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
    task:execute(function ()
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
