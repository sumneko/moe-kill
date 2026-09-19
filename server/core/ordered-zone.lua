require 'core.zone'

---@class Core.OrderedZone : Core.Zone
local M = Class 'Core.OrderedZone'

Extends('Core.OrderedZone', 'Core.Zone')

---@param params? table<string, any>
---@return Core.OrderedZone
function M.create(params)
    return New 'Core.OrderedZone' (params)
end

---@return Core.Card
function M:takeTop()
    return self:take(1)
end

---@param random Core.Random
---@return Core.OrderedZone
function M:shuffle(random)
    self:checkEnabled('洗牌')
    if Type(random) ~= 'Core.Random' then
        error('洗牌需要传入随机源实例', 2)
    end
    random:shuffle(self.cards)
    return self
end

return M
