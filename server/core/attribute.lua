local attribute = require 'tools.attribute'

---@class AttributeSpec
---@field simple? boolean
---@field min? number | string
---@field max? number | string

---@class AttributeSystem
---@field private system Attribute.System
local System = Class 'AttributeSystem'

---@class Attributes
---@field private system Attribute.System
---@field private instance Attribute.Instance
local Attributes = Class 'Attributes'

function System:__init()
    self.system = attribute.create()
end

---@param name string
---@param spec? AttributeSpec
---@return AttributeSystem
function System:define(name, spec)
    assert(type(name) == 'string' and name ~= '', '属性名必须是非空字符串')
    self.system:define(name, spec?.simple ~= false, spec?.min, spec?.max)
    return self
end

---@param customData? any
---@return Attributes
function System:createInstance(customData)
    return New 'Attributes' (self.system, self.system:instance(customData))
end

function System:updateEvents()
    self.system:updateEvent()
end

---@param system Attribute.System
---@param instance Attribute.Instance
function Attributes:__init(system, instance)
    self.system   = system
    self.instance = instance
end

---@param name string
---@return number
function Attributes:get(name)
    return self.instance:get(name)
end

---@param name string
---@return number
function Attributes:getMin(name)
    return self.instance:getMin(name)
end

---@param name string
---@return number
function Attributes:getMax(name)
    return self.instance:getMax(name)
end

---@param name string
---@param value number
function Attributes:set(name, value)
    self.instance:set(name, value)
    self.system:updateEvent()
end

---@param name string
---@param value number
function Attributes:add(name, value)
    self.instance:add(name, value)
    self.system:updateEvent()
end

--- 加一条修正（撤销函数精确减掉这次加的量）
---@param name string
---@param delta number
---@return fun()
function Attributes:addModifier(name, delta)
    self:add(name, delta)
    local removed = false
    return function ()
        if removed then
            return
        end
        removed = true
        self:add(name, -delta)
    end
end

---@param name string
---@param callback Attribute.EventCallback
---@return fun()
function Attributes:onChange(name, callback)
    return self.instance:event(name, callback)
end

---@class AttributeSystem.API
moe.attribute = {}

---@return AttributeSystem
function moe.attribute.create()
    return New 'AttributeSystem' ()
end
