---@class CardDef
---@field name string # 裸名
---@field public package string # 所属包名（显式写 public：否则 package 会被当成访问修饰符）
---@field fullName string # 完整名（包名.名字）
---@field source string # 声明它的文件（逻辑路径）
---@field private handlers table<string, function[]>
local CardDef = Class 'CardDef'

---@param name string
---@param owner string
---@param source string
function CardDef:__init(name, owner, source)
    self.name     = name
    self.package  = owner
    self.fullName = owner .. '.' .. name
    self.source   = source
    self.handlers = {}
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
---@class Game
---@field desk Desk # 桌子
---@field random Random # 随机源
---@field sources string[] # 包来源（顺序即优先级）
---@field list string[] # 上一次用的加载清单
---@field cards table<string, table<string, CardDef>> # 规则表：包名 → 裸名 → 定义
---@field packages string[] # 包的加载顺序（首次出现的顺序）
---@field meta table<string, Loader.PackageMeta> # 包元信息（装载器每次装完写入）
---@field values table<string, any> # 规则数值（按加载顺序后者覆盖前者）
---@field events Event # 时机注册
---@field loadedFiles string[] # 上一次实际执行过的文件（按执行完成顺序）
---@field loading? Loader.Context # 装载期上下文（装载器写、查询读；装完置空）
---@field private attributeSystem? AttributeSystem
---@field private zoneList Zone[]
---@field private zoneMap table<string, Zone>
---@field private effects Effect[] # 记牌器：发起过的根效果（只增）
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
    self.sources  = moe.loader.DEFAULT_SOURCES
    self.list     = {}
    desk:bindGame(self)
    self:resetContent()
end

function M:resetContent()
    self.cards       = {}
    self.packages    = {}
    self.meta        = {}
    self.values      = {}
    self.loadedFiles = {}
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
    if not self.loading then
        error('时机注册只能在加载规则集时声明', 2)
    end
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
function M:fire(name, ...)
    if type(name) ~= 'string' or name == '' then
        error('时机名必须是非空字符串', 2)
    end
    self.events:fire(name, ...)
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
---@param ordered? boolean # 需要有顺序能力（抽牌堆 / 弃牌堆之类）时传 true
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

---@param name string
---@return Card
function M:createCard(name)
    if type(name) ~= 'string' or name == '' then
        error('牌名必须是非空字符串', 2)
    end
    return moe.card.create(name)
end

---@param to Player # 被问者
---@param question any # 要什么牌（内容由发起方定，应答方自己解释）
---@return AskCard # 这次询问（已经结完：给出的牌读 `.result`，失败读 `.err`）
---@async
function M:askCard(to, question)
    local ask = moe.askCard.create {
        game     = self,
        to       = to,
        question = question,
    }
    ask:apply():await()
    return ask
end

---@param player Player # 打出这张牌的角色
---@param card Card # 打出的牌
function M:respond(player, card)
    local zone, index = player:findCard(card)
    if not zone or not index then
        error('这个角色的牌区里没有这张牌', 2)
    end
    zone:take(index)
    self:fire('卡牌-打出后', { player = player, card = card })
end

--- 把牌挪进某个牌区
---@param cards Card[] # 要挪的牌
---@param zoneName string # 目标牌区名（局上的区）
function M:moveCard(cards, zoneName)
    -- TODO: 先在局上的区与各个玩家的区里找到每张牌，再移进目标区（找不到就报错、不改状态）
    error('挪牌还没实现', 2)
end

---@param from Player # 伤害来源
---@param to Player # 承受者
---@param amount integer # 点数
---@async
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

---@param user Player # 使用者
---@param card Card # 被使用的牌
---@param targets Player[] # 目标（可以为空表）
---@async
---@return UseCard # 这次用牌（已经结完：结果读 `.result`，失败读 `.err`）
function M:useCard(user, card, targets)
    local effect = moe.useCard.create {
        game    = self,
        user    = user,
        card    = card,
        targets = targets,
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

---@class Game.API
local API = {}

---@param options Game.CreateOptions
---@return Game
function API.create(options)
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

return API
