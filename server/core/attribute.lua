local attribute = require 'tools.attribute'

---@class Core.AttributeSpec
---@field simple? boolean
---@field min? number | string
---@field max? number | string

---@class Core.AttributeSystem
---@field private system Attribute.System
local M = Class 'Core.AttributeSystem'

---@return Core.AttributeSystem
function M.create()
    return New 'Core.AttributeSystem' ()
end

function M:__init()
    self.system = attribute.create()
end

---@param name string
---@param spec? Core.AttributeSpec
---@return Core.AttributeSystem
function M:define(name, spec)
    assert(type(name) == 'string' and name ~= '', '属性名必须是非空字符串')
    local simple = spec?.simple
    if simple == nil then
        simple = true
    end
    self.system:define(name, simple, spec?.min, spec?.max)
    return self
end

---@param customData? any
---@return Attribute.Instance
function M:createInstance(customData)
    return self.system:instance(customData)
end

function M:updateEvents()
    self.system:updateEvent()
end

return M
