require 'core.effect'

---@class MoveCard.CreateOptions
---@field game Game
---@field cards Card[] # 要挪的牌
---@field zones string[] # 依次经过的牌区名（停在最后一站）

---@class MoveCard : Effect
---@field cards Card[] # 要挪的牌
---@field zones string[] # 依次经过的牌区名
local M = Class 'MoveCard'

Extends('MoveCard', 'Effect')

---@param game Game
---@param cards Card[]
---@param zones string[]
function M:__init(game, cards, zones)
    self.kind  = 'moveCard'
    self.cards = cards
    self.zones = zones
end

--- 一次结算把整批牌沿路径挪完（校验全通过才动）
function M:settle()
    ---@type Zone[]
    local stops = {}
    for i, name in ipairs(self.zones) do
        local stop = self.game:getZone(name)
        if not stop then
            error('局上没有叫 {} 的牌区' % { name }, 2)
        end
        stops[i] = stop
    end
    ---@type Zone[] # 每张牌此刻所在的区，随着路径推进
    local holding = {}
    for i, card in ipairs(self.cards) do
        local from = card:getZone()
        if not from then
            error('这张牌不在任何牌区里，挪不动：{}' % { tostring(card) }, 2)
        end
        holding[i] = from
    end
    for _, stop in ipairs(stops) do
        for i, card in ipairs(self.cards) do
            holding[i]:move(card, stop)
            holding[i] = stop
        end
    end
end

---@class MoveCard.API
local API = {}

---@param options MoveCard.CreateOptions
---@return MoveCard
function API.create(options)
    return New 'MoveCard' (options.game, options.cards, options.zones)
end

return API
