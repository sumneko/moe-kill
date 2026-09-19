---@class Moe.CardDef
---@field name string # 裸名
---@field public package string # 所属包名（显式写 public：否则 package 会被当成访问修饰符）
---@field fullName string # 完整名（包名.名字）
---@field source string # 声明它的文件（逻辑路径）
---@field private handlers table<string, function[]>
local CardDef = Class 'Moe.CardDef'

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
---@return Moe.CardDef
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

---@param meta Moe.Loader.PackageMeta
---@return Moe.Loader.PackageMeta
local function copyMeta(meta)
    ---@type Moe.Loader.PackageMeta
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
        ---@type Moe.Loader.MetaFile
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

---@class Moe.Game.CreateOptions
---@field desk Moe.Desk
---@field random Moe.Random
---@field sources? string[] # 包来源（省略时用默认来源）
---@field packages? string[] # 加载清单（省略时只装默认加载的包）
---@class Moe.Game
---@field desk Moe.Desk # 桌子
---@field random Moe.Random # 随机源
---@field sources string[] # 包来源（顺序即优先级）
---@field list string[] # 上一次用的加载清单
---@field cards table<string, table<string, Moe.CardDef>> # 规则表：包名 → 裸名 → 定义
---@field packages string[] # 包的加载顺序（首次出现的顺序）
---@field meta table<string, Moe.Loader.PackageMeta> # 包元信息（装载器每次装完写入）
---@field values table<string, any> # 规则数值（按加载顺序后者覆盖前者）
---@field events Moe.Event # 时机注册
---@field loadedFiles string[] # 上一次实际执行过的文件（按执行完成顺序）
---@field loading? Moe.Loader.Context # 装载期上下文（装载器写、查询读；装完置空）
---@field private attributeSystem? Moe.AttributeSystem
---@field private zoneList Moe.Zone[]
---@field private zoneMap table<string, Moe.Zone>
local M = Class 'Moe.Game'

---@param desk Moe.Desk
---@param random Moe.Random
function M:__init(desk, random)
    self.desk     = desk
    self.random   = random
    self.events   = moe.event.create()
    self.zoneList = {}
    self.zoneMap  = {}
    self.sources  = moe.loader.DEFAULT_SOURCES
    self.list     = {}
    self:resetContent()
end

---@param options Moe.Game.CreateOptions
---@return Moe.Game
function M.create(options)
    if not options or not options.desk or not options.random then
        error('建局需要一张桌子与一个随机源', 2)
    end
    local game = New 'Moe.Game' (options.desk, options.random)
    moe.loader.install(game, {
        sources  = options.sources,
        packages = options.packages,
    })
    return game
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

---@return Moe.Desk
function M:getDesk()
    return self.desk
end

---@return Moe.Random
function M:getRandom()
    return self.random
end

---@return Moe.AttributeSystem
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
---@return Moe.CardDef
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
    local def = New 'Moe.CardDef' (name, owner, ctx.current)
    cards[name] = def
    return def
end

---@param name string
---@return Moe.CardDef?
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
---@return Moe.Loader.PackageMeta?
function M:getPackageMeta(name)
    local meta = self.meta[name]
    if not meta then
        return nil
    end
    return copyMeta(meta)
end

---@return table<string, Moe.Loader.PackageMeta>
function M:getMetas()
    ---@type table<string, Moe.Loader.PackageMeta>
    local result = {}
    for name, meta in pairs(self.meta) do
        result[name] = copyMeta(meta)
    end
    return result
end

---@overload fun(self: Moe.Game, name: string, ordered: true): Moe.OrderedZone
---@param name string
---@param ordered? boolean # 需要有顺序能力（抽牌堆 / 弃牌堆之类）时传 true
---@return Moe.Zone
function M:createZone(name, ordered)
    if type(name) ~= 'string' or name == '' then
        error('牌区必须有个非空名字', 2)
    end
    if self.zoneMap[name] then
        error('局上已经有叫 {} 的牌区了' % { name }, 2)
    end
    local zone = ordered and New 'Moe.OrderedZone' (self.random) or New 'Moe.Zone' ()
    self.zoneMap[name] = zone
    self.zoneList[#self.zoneList+1] = zone
    return zone
end

---@param name string
---@return Moe.Zone?
function M:getZone(name)
    return self.zoneMap[name]
end

---@return Moe.Zone[] # 按创建顺序
function M:getZones()
    ---@type Moe.Zone[]
    local snapshot = {}
    table.move(self.zoneList, 1, #self.zoneList, 1, snapshot)
    return snapshot
end

---@param name string
---@return Moe.Card
function M:createCard(name)
    if type(name) ~= 'string' or name == '' then
        error('牌名必须是非空字符串', 2)
    end
    return moe.card.create(name)
end

return M
