require 'core.zone'

---@class OrderedZone : Zone
---@field private random? Random
---@field private shortage? fun(zone: OrderedZone) # 取空了怎么补（内容侧挂）
local M = Class 'OrderedZone'

Extends('OrderedZone', 'Zone')

---@param game Game # 属于哪一局
---@param random? Random # 绑定后 shuffle 可以不带参数
function M:__init(game, random)
    self.kind   = 'orderedZone'
    self.random = random
end

--- 取区顶那张
---@return Card
function M:takeTop()
    return self:take(1)
end

--- 从区顶取 n 张（不够就少给，不报错）
---@param count integer
---@return Card[] # 实际取到的牌（按取的先后）
---@async
function M:draw(count)
    ---@type Card[]
    local cards = {}
    for _ = 1, count do
        if #self.cards == 0 and self.shortage then
            self.shortage(self)
        end
        if #self.cards == 0 then
            break
        end
        cards[#cards + 1] = self:takeTop()
    end
    return cards
end

--- 取空了怎么补（内容侧挂：把弃牌全部洗回之类）
---@param handler fun(zone: OrderedZone)
function M:setShortageHandler(handler)
    self.shortage = handler
end

--- 就地洗牌
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

---@class OrderedZone.API
moe.orderedZone = {}

--- 建一个有序牌区
---@param game Game # 属于哪一局
---@param random? Random
---@return OrderedZone
function moe.orderedZone.create(game, random)
    return New 'OrderedZone' (game, random)
end
