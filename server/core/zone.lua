---@alias Core.Zone.Kind 'zone' | 'orderedZone'

---@class Core.Zone
---@field kind Core.Zone.Kind
---@field protected cards Core.Card[]
---@field private params table<string, any>
---@field private enabled boolean
local M = Class 'Core.Zone'

local Card = require 'core.card'

---@type table<Core.Zone.Kind, true>
local KINDS = {
    zone        = true,
    orderedZone = true,
}

---@param value any
---@return boolean
function M.isZone(value)
    return type(value) == 'table' and KINDS[value.kind] == true
end

---@param count integer
---@param position? integer
---@return integer
local function resolvePosition(count, position)
    if position == nil then
        return count + 1
    end
    assert(math.type(position) == 'integer', '位置必须是整数')
    local index = position
    if index < 0 then
        index = count + index + 2
    end
    if index < 1 or index > count + 1 then
        error('位置 {} 超出可插入范围（共 {} 个位置：1..{} 或 -1..-{}）' % {
            position,
            count + 1,
            count + 1,
            count + 1,
        }, 3)
    end
    return index
end

---@param params? table<string, any>
function M:__init(params)
    self.kind    = 'zone'
    self.cards   = {}
    self.params  = {}
    self.enabled = true
    if params then
        for key, value in pairs(params) do
            self:setParam(key, value)
        end
    end
end

---@param params? table<string, any>
---@return Core.Zone
function M.create(params)
    return New 'Core.Zone' (params)
end

---@param action string
function M:checkEnabled(action)
    if not self.enabled then
        error('牌区已被禁用，无法{}' % { action }, 3)
    end
end

---@param index integer
function M:checkIndex(index)
    assert(math.type(index) == 'integer', '牌的序号必须是整数')
    if not self.cards[index] then
        error('牌区中没有第 {} 张牌（当前 {} 张）' % { index, #self.cards }, 3)
    end
end

---@param card Core.Card
---@return Core.Card
function M:put(card)
    assert(Card.isCard(card), '只能把牌放入牌区')
    self:checkEnabled('放入牌')
    self.cards[#self.cards + 1] = card
    return card
end

---@param index integer
---@return Core.Card
function M:take(index)
    self:checkEnabled('取牌')
    self:checkIndex(index)
    return table.remove(self.cards, index)
end

---@private
---@param card Core.Card
---@return integer?
function M:indexOf(card)
    for i = 1, #self.cards do
        if self.cards[i] == card then
            return i
        end
    end
    return nil
end

---@param card Core.Card
---@param to Core.Zone
---@param position? integer
---@return Core.Card
function M:move(card, to, position)
    assert(M.isZone(to), '移动目标必须是牌区')
    self:checkEnabled('移出牌')
    to:checkEnabled('移入牌')
    local index = self:indexOf(card)
    if not index then
        error('源牌区中没有这张牌', 3)
    end
    local count = #to.cards
    if to == self then
        count = count - 1
    end
    local target = resolvePosition(count, position)
    table.remove(self.cards, index)
    table.insert(to.cards, target, card)
    return card
end

---@param index integer
---@return Core.Card
function M:peek(index)
    self:checkIndex(index)
    return self.cards[index]
end

---@return integer
function M:count()
    return #self.cards
end

---@return Core.Card[]
function M:list()
    local snapshot = {}
    return table.move(self.cards, 1, #self.cards, 1, snapshot)
end

---@return integer
function M:clear()
    self:checkEnabled('清空牌区')
    local count = #self.cards
    self.cards = {}
    return count
end

---@param key string
---@param value any
function M:setParam(key, value)
    assert(type(key) == 'string', '参数名必须是字符串')
    assert(value ~= nil, '参数值不能是 nil')
    self.params[key] = value
end

---@param key string
---@return any
function M:getParam(key)
    return self.params[key]
end

---@param key string
---@return boolean
function M:removeParam(key)
    if self.params[key] == nil then
        return false
    end
    self.params[key] = nil
    return true
end

---@return boolean
function M:disable()
    if not self.enabled then
        return false
    end
    self.enabled = false
    return true
end

---@return boolean
function M:enable()
    if self.enabled then
        return false
    end
    self.enabled = true
    return true
end

---@return boolean
function M:isEnabled()
    return self.enabled
end

---@return Core.Card
function M:takeTop()
    error('该牌区不具备有序能力，无法取顶', 2)
end

---@param random Core.Random
---@return Core.Zone
function M:shuffle(random)
    error('该牌区不具备有序能力，无法洗牌', 2)
end

return M
