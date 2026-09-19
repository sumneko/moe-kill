---@alias Core.Card.Kind 'card'

---@class Core.Card
---@field kind Core.Card.Kind
---@field private id integer
---@field private label? any
local M = Class 'Core.Card'

local nextId = 0

---@param label? any
function M:__init(label)
    nextId = nextId + 1
    self.kind  = 'card'
    self.id    = nextId
    self.label = label
end

---@param label? any
---@return Core.Card
function M.create(label)
    return New 'Core.Card' (label)
end

---@param value any
---@return boolean
function M.isCard(value)
    return type(value) == 'table' and value.kind == 'card'
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
