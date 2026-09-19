---@class Card
---@field private id integer
---@field private label? any
local M = Class 'Card'

---@package
moe._nextCardId = moe._nextCardId or moe.util.counter()

---@param label? any
function M:__init(label)
    self.id    = moe._nextCardId()
    self.label = label
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

---@class Card.API
local API = {}

---@param label? any
---@return Card
function API.create(label)
    return New 'Card' (label)
end

return API
