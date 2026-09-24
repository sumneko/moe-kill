---@class Card
---@field private id integer
---@field private label? any
---@field suit? string # 花色
---@field point? integer # 点数（1..13）
---@field private zone? Zone # 现在在哪个牌区里（不在任何牌区时为「不存在」）
---@field private zoneGCHost? GCHost # 随「这张牌在牌区里」存活的容器（懒建）
local M = Class 'Card'

---@param label? any
---@param id integer # 号由局发（`game:nextId`）
---@param suit? string # 花色
---@param point? integer # 点数
function M:__init(label, id, suit, point)
    self.id    = id
    self.label = label
    self.suit  = suit
    self.point = point
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

--- 牌离开这个牌区时调它（挂在牌上，随它在区里这段寿命）
---@param disposer function
function M:withZone(disposer)
    if not self.zoneGCHost then
        self.zoneGCHost = moe.gc.host()
    end
    self.zoneGCHost:bindGC(disposer)
end

--- 记下这张牌所在的牌区（只有牌区自己用：放进 / 取出时维护）
---@param zone Zone?
function M:bindZone(zone)
    if self.zone ~= zone and self.zoneGCHost then
        Delete(self.zoneGCHost)
        self.zoneGCHost = nil
    end
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
---@param suit? string # 花色
---@param point? integer # 点数
---@return Card
function moe.card.create(label, id, suit, point)
    return New 'Card' (label, id, suit, point)
end
