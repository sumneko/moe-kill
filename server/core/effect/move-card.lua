require 'core.effect.effect'

---@class MoveCard.CreateOptions
---@field game Game
---@field cards Card[] # 要挪的牌
---@field zones (string|Zone)[] # 依次经过的牌区（名字或牌区对象；停在最后一站）

---@class MoveCard : Effect
local M = Class 'MoveCard'

Extends('MoveCard', 'Effect')

---@param game Game
---@param cards Card[]
---@param zones (string|Zone)[]
function M:__init(game, cards, zones)
    self.kind  = 'moveCard'
    self.cards = cards
    self.zones = zones
end

--- 找一站：牌区对象直接用；名字先在**当前回合角色**身上找，再找局上的牌区
---@param game Game
---@param item string|Zone
---@return Zone
local function resolveStop(game, item)
    if type(item) ~= 'string' then
        return item
    end
    local turnPlayer = game.turnPlayer
    local zone = turnPlayer and turnPlayer:getZone(item) or game:getZone(item)
    if not zone then
        error('局上没有叫 {} 的牌区' % { item }, 3)
    end
    return zone
end

--- 一次结算把整批牌沿路径挪完（校验全通过才动）
function M:settle()
    ---@type Zone[]
    local stops = {}
    for i, item in ipairs(self.zones) do
        stops[i] = resolveStop(self.game, item)
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
