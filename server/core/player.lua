---@class Player.CreateOptions
---@field attributes Attributes
---@field name? string

---@class Player
---@field private name? string
---@field private attributes Attributes
---@field private zoneList Zone[]
---@field private zoneMap table<string, Zone>
---@field private tags table<string, any>
---@field private acting boolean
local M = Class 'Player'

---@param attributes Attributes
---@param name? string
function M:__init(attributes, name)
    self.name       = name
    self.attributes = attributes
    self.zoneList   = {}
    self.zoneMap    = {}
    self.tags       = {}
    self.acting     = true
end

---@param options Player.CreateOptions
---@return Player
function M.create(options)
    if not options or not options.attributes then
        error('玩家需要一个属性实例', 2)
    end
    return New 'Player' (options.attributes, options.name)
end

---@return Attributes
function M:getAttributes()
    return self.attributes
end

---@param name string
---@param value number
function M:setAttr(name, value)
    self.attributes:set(name, value)
end

---@param name string
---@return number
function M:getAttr(name)
    return self.attributes:get(name)
end

---@param name string
---@param value number
function M:addAttr(name, value)
    self.attributes:add(name, value)
end

---@return string?
function M:getName()
    return self.name
end

---@param name string
---@param zone? Zone # 省略时新建一个普通牌区
---@return function # 撤销这次添加（移除该牌区）
function M:addZone(name, zone)
    if type(name) ~= 'string' or name == '' then
        error('牌区必须有个非空名字', 2)
    end
    if self.zoneMap[name] then
        error('这个玩家已经有叫 {} 的牌区了' % { name }, 2)
    end
    local instance = zone or New 'Zone' ()
    self.zoneMap[name] = instance
    self.zoneList[#self.zoneList+1] = instance
    local removed = false
    return function ()
        if removed then
            return
        end
        removed = true
        self.zoneMap[name] = nil
        for i, item in ipairs(self.zoneList) do
            if item == instance then
                table.remove(self.zoneList, i)
                break
            end
        end
    end
end

---@param name string
---@return Zone?
function M:getZone(name)
    return self.zoneMap[name]
end

---@return Zone[] # 按加入顺序
function M:getZones()
    ---@type Zone[]
    local zones = {}
    table.move(self.zoneList, 1, #self.zoneList, 1, zones)
    return zones
end

---@param key string
---@param value any
function M:setTag(key, value)
    if type(key) ~= 'string' or key == '' then
        error('标签键必须是非空字符串', 2)
    end
    self.tags[key] = value
end

---@param key string
---@return any
function M:getTag(key)
    return self.tags[key]
end

---@param key string
function M:removeTag(key)
    self.tags[key] = nil
end

---@param value boolean
function M:setActing(value)
    self.acting = value and true or false
end

---@return boolean
function M:isActing()
    return self.acting
end

return M
