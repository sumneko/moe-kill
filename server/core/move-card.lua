require 'core.effect'

---@class MoveCard.CreateOptions
---@field game Game
---@field cards Card[] # 要挪的牌
---@field zones string[] # 依次经过的牌区名（停在最后一站）

---@class MoveCard : Effect
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
    ---@type (Zone?)[] # 每张牌此刻所在的区（本来不在任何区的牌为「不存在」）
    local holding = {}
    for i, card in ipairs(self.cards) do
        holding[i] = card:getZone()
    end
    for _, stop in ipairs(stops) do
        for i, card in ipairs(self.cards) do
            local from = holding[i]
            if from then
                from:move(card, stop)
            else
                stop:put(card)
            end
            holding[i] = stop
        end
    end
end

---@class MoveCard.API
moe.moveCard = {}

---@param options MoveCard.CreateOptions
---@return MoveCard
function moe.moveCard.create(options)
    return New 'MoveCard' (options.game, options.cards, options.zones)
end
