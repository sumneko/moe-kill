---@class Moe.Room.CreateOptions
---@field desk Moe.Desk
---@field random Moe.Random
---@field sources string[]? # 规则集来源（省略时用默认来源）
---@field packages string[]? # 规则集加载清单（省略时只装自动加载的默认包）

---@class Moe.Room
---@field private desk Moe.Desk
---@field private random Moe.Random
---@field private rule Moe.Rule
---@field private zoneList Moe.Zone[]
---@field private zoneMap table<string, Moe.Zone>
local M = Class 'Moe.Room'

---@param desk Moe.Desk
---@param random Moe.Random
---@param rule Moe.Rule
function M:__init(desk, random, rule)
    self.desk     = desk
    self.random   = random
    self.rule     = rule
    self.zoneList = {}
    self.zoneMap  = {}
end

---@param options Moe.Room.CreateOptions
---@return Moe.Room
function M.create(options)
    if not options or not options.desk or not options.random then
        error('场地需要一张桌子与一个随机源', 2)
    end
    local rule = moe.rule.create {
        sources  = options.sources,
        packages = options.packages or {},
    }
    return New 'Moe.Room' (options.desk, options.random, rule)
end

---@return Moe.Rule
function M:getRule()
    return self.rule
end

---@return Moe.Desk
function M:getDesk()
    return self.desk
end

---@return Moe.Random
function M:getRandom()
    return self.random
end

---@overload fun(self: Moe.Room, name: string, ordered: true): Moe.OrderedZone
---@param name string
---@param ordered? boolean # 需要有顺序能力（抽牌堆 / 弃牌堆之类）时传 true
---@return Moe.Zone
function M:createZone(name, ordered)
    if type(name) ~= 'string' or name == '' then
        error('牌区必须有个非空名字', 2)
    end
    if self.zoneMap[name] then
        error('场地上已经有叫 {} 的牌区了' % { name }, 2)
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
