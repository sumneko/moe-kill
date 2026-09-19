---@class Core.Card
---@field private id integer
---@field private label? any
local M = Class 'Core.Card'

local nextId = 0

---@param label? any
function M:__init(label)
    nextId = nextId + 1
    self.id    = nextId
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
