---@class Core.Room.CreateOptions
---@field desk Core.Desk
---@field random Core.Random

---@class Core.Room
---@field private desk Core.Desk
---@field private random Core.Random
---@field private zoneList Core.Zone[]
---@field private zoneMap table<string, Core.Zone>
local M = Class 'Core.Room'

---@param desk Core.Desk
---@param random Core.Random
function M:__init(desk, random)
    self.desk     = desk
    self.random   = random
    self.zoneList = {}
    self.zoneMap  = {}
end

---@param options Core.Room.CreateOptions
---@return Core.Room
function M.create(options)
    if not options or not options.desk or not options.random then
        error('场地需要一张桌子与一个随机源', 2)
    end
    return New 'Core.Room' (options.desk, options.random)
end

---@return Core.Desk
function M:getDesk()
    return self.desk
end

---@return Core.Random
function M:getRandom()
    return self.random
end

---@overload fun(self: Core.Room, name: string, ordered: true): Core.OrderedZone
---@param name string
---@param ordered? boolean # 需要有顺序能力（抽牌堆 / 弃牌堆之类）时传 true
---@return Core.Zone
function M:createZone(name, ordered)
    if type(name) ~= 'string' or name == '' then
        error('牌区必须有个非空名字', 2)
    end
    if self.zoneMap[name] then
        error('场地上已经有叫 {} 的牌区了' % { name }, 2)
    end
    local zone = ordered and New 'Core.OrderedZone' (self.random) or New 'Core.Zone' ()
    self.zoneMap[name] = zone
    self.zoneList[#self.zoneList+1] = zone
    return zone
end

---@param name string
---@return Core.Zone?
function M:getZone(name)
    return self.zoneMap[name]
end

---@return Core.Zone[] # 按创建顺序
function M:getZones()
    ---@type Core.Zone[]
    local snapshot = {}
    table.move(self.zoneList, 1, #self.zoneList, 1, snapshot)
    return snapshot
end

---@param name string
---@return Core.Card
function M:createCard(name)
    if type(name) ~= 'string' or name == '' then
        error('牌名必须是非空字符串', 2)
    end
    return moe.core.card.create(name)
end

return M
