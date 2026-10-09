---@class OrderedZone : Zone
--- 区顶 = 列表的第 1 位（`peek(1)` / `draw` 取的就是它）
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
        local top = self.cards[1]
        if not top then
            break
        end
        cards[#cards + 1] = assert(self:remove(top))
    end
    return cards
end

--- 取空了怎么补（内容侧挂：把弃牌全部洗回之类）
---@param handler fun(zone: OrderedZone)
function M:setShortageHandler(handler)
    self.shortage = handler
end

--- 把一批牌按给定顺序置于区顶（第一张最靠顶）
---@param cards Card|Card[]
function M:placeTop(cards)
    self:notifyMoved(self:takeIn(self:toPhysical(cards), nil, 1))
end

--- 把一批牌按给定顺序置于区底（第一张更靠上、最后一张最靠底）—— 与 `accept` 同一件事，单列出来让「顺序约定」只写在一处
---@param cards Card|Card[]
function M:placeBottom(cards)
    self:accept(cards)
end

--- 就地洗牌
---@param random? Random # 省略时用创建时绑定的随机源
function M:shuffle(random)
    local source = random or self.random
    if not source then
        error('这个牌区没有绑定随机源，洗牌时要传一个', 2)
    end
    source:shuffle(self.cards)
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
