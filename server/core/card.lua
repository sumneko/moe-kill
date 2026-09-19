---@class Core.Card
---@field private id integer
---@field private label? any
---@field package __counter fun():integer
local M = Class 'Core.Card'

M.__counter = M.__counter or moe.util.counter()

---@param label? any
function M:__init(label)
    self.id    = M.__counter()
    self.label = label
end

---@param label? any
---@return Core.Card
function M.create(label)
    return New 'Core.Card' (label)
end

---@return integer
function M:getId()
    return self.id
end

---@return any
function M:getLabel()
    return self.label
end

---@param label? any
function M:setLabel(label)
    self.label = label
end

---@return string
function M:__tostring()
    return '牌#{}' % { self.id }
end

return M
