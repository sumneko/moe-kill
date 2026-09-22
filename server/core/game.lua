---@class CardDef
---@field name string # 裸名
---@field public package string # 所属包名（显式写 public：否则 package 会被当成访问修饰符）
---@field fullName string # 完整名（包名.名字）
---@field source string # 声明它的文件（逻辑路径）
---@field private handlers table<string, function[]>
---@field private limits table<string, integer> # 每个阶段最多用几次
local CardDef = Class 'CardDef'

---@type integer # 没声明限额时的兜底：事实上的「不限次数」
local DEFAULT_LIMIT = 1000

---@param name string
---@param owner string
---@param source string
function CardDef:__init(name, owner, source)
    self.name     = name
    self.package  = owner
    self.fullName = owner .. '.' .. name
    self.source   = source
    self.handlers = {}
    self.limits   = {}
end

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
---@return function[]
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
---@param phase string # 阶段名（内核不解释取值）
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
---@field desk Desk
---@field random Random
---@field sources? string[] # 包来源（省略时用默认来源）
---@field packages? string[] # 加载清单（省略时只装默认加载的包）
---@class Game.Result # 一局的结果
---@field side string # 胜方阵营：主公方 / 反贼 / 内奸
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
---@field private attributeSystem? AttributeSystem
---@field private zoneList Zone[]
---@field private zoneMap table<string, Zone>
---@field private effects Effect[] # 记牌器：发起过的根效果（只增）
---@field private dyingPending table<Player, boolean> # 待结的濒死（记账；结算收尾时才起 Dying）
---@field private events Event # 时机表（内容侧用 game:on / game:fire；每次装载会清空）
---@field private idCounter integer # 发号器（牌与将来的技能共用；重装内容也不重置）
---@field phase? Phase # 当前阶段（没进阶段就是空）
---@field private phaseStack Phase[] # 阶段栈（阶段可以嵌套：将来的「额外的一个出牌阶段」）
---@field private flow? fun(): any # 这一局的流程本体（内容登记，装配侧启动）
---@field private flowTask? Task # 流程任务（`endGame` 靠它把流程就地收掉）
---@field private result? Game.Result # 这一局的结果（有值就是已经结束了）
local M = Class 'Game'

---@param desk Desk
---@param random Random
function M:__init(desk, random)
    self.desk     = desk
    self.random   = random
    self.events   = moe.event.create()
    self.zoneList = {}
    self.zoneMap  = {}
    self.effects  = {}
    self.dyingPending = {}
    self.sources  = moe.loader.DEFAULT_SOURCES
    self.list     = {}
    self.idCounter = 0
    self.phaseStack = {}
    desk:bindGame(self)
    self:resetContent()
end

function M:resetContent()
    self.cards       = {}
    self.packages    = {}
    self.meta        = {}
    self.values      = {}
    self.loadedFiles = {}
    self.flow        = nil
    self.turnPlayer  = nil
    self.attributeSystem = nil
    self.events:clear()
end

---@return AttributeSystem
function M:getAttributeSystem()
    self.attributeSystem = self.attributeSystem or moe.attribute.create()
    return self.attributeSystem
end

---@param name string
---@param value any
function M:setValue(name, value)
    if type(name) ~= 'string' or name == '' then
        error('规则数值的名字必须是非空字符串', 2)
    end
    self.values[name] = value
end

---@param values table<string, any>
function M:setValues(values)
    if type(values) ~= 'table' then
        error('规则数值必须是一张名字到值的表', 2)
    end
    for name, value in pairs(values) do
        self:setValue(name, value)
    end
end

---@param name string
---@return any # 没设置过就是「不存在」
function M:getValue(name)
    if type(name) ~= 'string' or name == '' then
        error('规则数值的名字必须是非空字符串', 2)
    end
    return self.values[name]
end

---@return table<string, any>
function M:getValues()
    ---@type table<string, any>
    local result = {}
    for name, value in pairs(self.values) do
        result[name] = value
    end
    return result
end

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
---@param name string # 阶段名（内核当成不透明字符串）
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
    local def = New 'CardDef' (name, owner, ctx.current)
    cards[name] = def
    return def
end

---@param name string
---@return CardDef?
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
---@return Loader.PackageMeta?
function M:getPackageMeta(name)
    local meta = self.meta[name]
    if not meta then
        return nil
    end
    return copyMeta(meta)
end

---@return table<string, Loader.PackageMeta>
function M:getMetas()
    ---@type table<string, Loader.PackageMeta>
    local result = {}
    for name, meta in pairs(self.meta) do
        result[name] = copyMeta(meta)
    end
    return result
end

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
    local zone = ordered and New 'OrderedZone' (self.random) or New 'Zone' ()
    self.zoneMap[name] = zone
    self.zoneList[#self.zoneList+1] = zone
    return zone
end

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

--- 按牌名建一张牌（号由这一局发）
---@param name string
---@return Card
function M:createCard(name)
    if type(name) ~= 'string' or name == '' then
        error('牌名必须是非空字符串', 2)
    end
    return moe.card.create(name, self:nextId())
end

---@param to Player # 被问者
---@param reason? string # 这次为什么问（内容由发起方定，内核不解释）
---@param condition? AskCard.Condition # 要什么样的牌（内核据此在被问者的牌区里算出 `ask.options`；省略 = 不做限制）
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

--- 要一个决策（问什么、答什么都由发起方解释）
---@async
---@param to Player # 被问者
---@param reason? string # 这次为什么问（内容由发起方定，内核不解释）
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

--- 把牌挪到某个牌区（给一串就依次经过，停在最后一站）
---@async
---@param card Card|Card[] # 要挪的牌（单张或一批）
---@param zone string|string[]|Zone|Zone[] # 目标牌区：名字或牌区对象（名字先在当前回合角色身上找）
---@return MoveCard # 这次挪牌（已经结完：失败读 `.err`）
function M:moveCard(card, zone)
    ---@type Card[]
    local cards = card[1] ~= nil and card or { card }
    ---@type (string|Zone)[]
    local zones = {}
    if type(zone) == 'table' and Type(zone) == nil then
        ---@cast zone (string|Zone)[]
        for i, item in ipairs(zone) do
            zones[i] = item
        end
    else
        ---@cast zone string|Zone
        zones[1] = zone
    end
    local effect = moe.moveCard.create {
        game  = self,
        cards = cards,
        zones = zones,
    }
    effect:apply():await()
    return effect
end

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

---@async
---@param player Player # 谁摸牌
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

---@param targets Player|Player[]
---@return Player[] # 目标列表（单个也包成表）
local function toPlayerList(targets)
    if Type(targets) ~= nil then
        ---@cast targets Player
        return { targets }
    end
    ---@cast targets Player[]
    return targets
end

---@param def CardDef
---@param user Player
---@param card Card
---@return Player[]? # 各声明取交集后的合法目标
---@return any # 不成立的原因
local function collectLegalTargets(def, user, card)
    local handlers = def:getHandlers('获取目标')
    if #handlers == 0 then
        return nil, '「{}」没有声明「获取目标」，现在用不了' % { def.fullName }
    end
    local ctx = { user = user, card = card }
    ---@type Player[]?
    local legal = nil
    for _, handler in ipairs(handlers) do
        local list = handler(ctx)
        if type(list) ~= 'table' then
            return nil, '「{}」的「获取目标」必须返回合法目标列表' % { def.fullName }
        end
        if legal then
            ---@type Player[]
            local narrowed = {}
            for _, player in ipairs(legal) do
                if moe.util.arrayHas(list, player) then
                    narrowed[#narrowed + 1] = player
                end
            end
            legal = narrowed
        else
            ---@type Player[]
            local copied = {}
            table.move(list, 1, #list, 1, copied)
            legal = copied
        end
    end
    if not legal or #legal == 0 then
        return nil, '「{}」现在没有合法目标' % { def.fullName }
    end
    return legal
end

--- 这张牌此刻能不能用；能用就给合法目标
---@param user Player # 使用者
---@param card Card # 要用的牌
---@param targets? Player|Player[] # 要校验的目标（省略 = 只判「此刻能不能用」）
---@return boolean # 能用吗
---@return any # 不能用的原因
---@return Player[]? # 能用时的合法目标
function M:canUse(user, card, targets)
    local name = card:getLabel()
    if type(name) ~= 'string' then
        return false, '这张牌没有牌名，查不到内容定义'
    end
    local def = self:getCard(name)
    if not def then
        return false, '没有叫「{}」的内容定义' % { name }
    end
    if not user:findCard(card) then
        return false, '使用者手上没有这张牌'
    end
    local legal, reason = collectLegalTargets(def, user, card)
    if not legal then
        return false, reason
    end

    ---@type Player[]?
    local list = nil
    if targets ~= nil then
        list = toPlayerList(targets)
        if #list == 0 then
            return false, '「{}」至少要指定一个目标' % { def.fullName }
        end
        for _, target in ipairs(list) do
            if not moe.util.arrayHas(legal, target) then
                return false, '「{}」不能以这个角色为目标' % { def.fullName }
            end
        end
    end

    local phase = self:getUsePhase(user)
    if phase then
        local limit = def:getLimit(phase.name) + phase:getLimitDelta(name)
        if phase:getUseCount(name) >= limit then
            return false, '本阶段已经用过「{}」了' % { name }
        end
    end

    local refusal = self:fire('卡牌-能否使用', { user = user, card = card, targets = list })
    if refusal ~= nil then
        if refusal == false then
            refusal = '这张牌现在不能使用'
        end
        return false, refusal
    end
    return true, nil, legal
end

---@async
---@param user Player # 使用者
---@param card Card # 被使用的牌
---@param targets Player|Player[] # 目标：单个或列表（空表 = 没指定目标）
---@return UseCard # 这次用牌（已经结完：结果读 `.result`，失败读 `.err`）
function M:useCard(user, card, targets)
    local effect = moe.useCard.create {
        game    = self,
        user    = user,
        card    = card,
        targets = toPlayerList(targets),
    }
    effect:apply():await()
    return effect
end

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

--- 记下这个玩家该进濒死：真正的结算等当前这次效果结算收尾时开始（返回撤销）
---@param player Player
---@return function # 撤销这次记账（例如体力又回正了）
---@async
function M:enterDying(player)
    self.dyingPending[player] = true
    local removed = false
    if not (moe.task.getCurrentTask()?.context.effect) then
        self:flushDying()
    end
    return function ()
        if removed then
            return
        end
        removed = true
        self.dyingPending[player] = nil
    end
end

--- 把记下的濒死结掉（结算收尾时由内核调）
---@async
function M:flushDying()
    if not coroutine.isyieldable() then
        return
    end
    while true do
        local player = next(self.dyingPending)
        if not player then
            return
        end
        self.dyingPending[player] = nil
        if player:isAlive() then
            local dying = moe.dying.create { game = self, player = player }
            dying:apply():await()
        end
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

-- 这一局的结果（还没结束就是「不存在」）
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

---@param options Game.CreateOptions
---@return Game
function moe.game.create(options)
    if not options or not options.desk or not options.random then
        error('建局需要一张桌子与一个随机源', 2)
    end
    local game = New 'Game' (options.desk, options.random)
    moe.loader.install(game, {
        sources  = options.sources,
        packages = options.packages,
    })
    return game
end
