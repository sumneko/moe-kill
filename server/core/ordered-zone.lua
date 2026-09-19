require 'core.zone'

---@class OrderedZone : Zone
---@field private random? Random
local M = Class 'OrderedZone'

Extends('OrderedZone', 'Zone')

---@param random? Random # 绑定后 shuffle 可以不带参数
function M:__init(random)
    self.kind   = 'orderedZone'
    self.random = random
end

---@param random? Random
---@return OrderedZone
function M.create(random)
    return New 'OrderedZone' (random)
end

---@return Card
function M:takeTop()
    return self:take(1)
end

---@param random? Random # 省略时用创建时绑定的随机源
---@return OrderedZone
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
