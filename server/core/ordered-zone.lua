require 'core.zone'

---@class Moe.OrderedZone : Moe.Zone
---@field private random Moe.Random?
local M = Class 'Moe.OrderedZone'

Extends('Moe.OrderedZone', 'Moe.Zone')

---@param random? Moe.Random # 绑定后 shuffle 可以不带参数
function M:__init(random)
    self.kind   = 'orderedZone'
    self.random = random
end

---@param random? Moe.Random
---@return Moe.OrderedZone
function M.create(random)
    return New 'Moe.OrderedZone' (random)
end

---@return Moe.Card
function M:takeTop()
    return self:take(1)
end

---@param random? Moe.Random # 省略时用创建时绑定的随机源
---@return Moe.OrderedZone
function M:shuffle(random)
    self:checkEnabled('洗牌')
    local source = random or self.random
    if not source then
        error('这个牌区没有绑定随机源，洗牌时要传一个', 2)
    end
    source:shuffle(self.cards)
    return self
end

return M
