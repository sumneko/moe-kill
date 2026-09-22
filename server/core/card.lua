---@class Card
---@field private id integer
---@field private label? any
---@field private zone? Zone # 现在在哪个牌区里（不在任何牌区时为「不存在」）
local M = Class 'Card'

---@param label? any
---@param id integer # 号由局发（`game:nextId`）
function M:__init(label, id)
    self.id    = id
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

--- 这张牌现在在哪个牌区
---@return Zone? # 不在任何牌区时为「不存在」
function M:getZone()
    return self.zone
end

--- 记下这张牌所在的牌区（只有牌区自己用：放进 / 取出时维护）
---@param zone Zone?
function M:bindZone(zone)
    self.zone = zone
end

---@return string
function M:__tostring()
    return '牌#{}' % { self.id }
end

---@class Card.API
moe.card = {}

---@param label? any
---@param id integer # 号由局发（`game:nextId`）
---@return Card
function moe.card.create(label, id)
    return New 'Card' (label, id)
end
