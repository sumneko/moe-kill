require 'core.effect.effect'

---@class MoveCard.CreateOptions
---@field game Game
---@field cards Card[] # 要挪的牌
---@field zone? string|Zone # 目标牌区（名字或牌区对象；不给 = 这次挪牌失败）

---@class MoveCard : Effect
local M = Class 'MoveCard'

Extends('MoveCard', 'Effect')

---@param game Game
---@param cards Card[]
---@param zone? string|Zone
function M:__init(game, cards, zone)
    self.kind  = 'moveCard'
    self.cards = cards
    self.zone  = zone
end

--- 找目标牌区：牌区对象直接用；名字先在**当前回合角色**身上找，再找局上的牌区
---@param game Game
---@param item? string|Zone
---@return Zone
local function resolveZone(game, item)
    if not item then
        error('没有指定目标牌区', 3)
    end
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

--- 一次结算把整批牌挪过去（区名解析不出来就整批不动）
function M:settle()
    local stop = resolveZone(self.game, self.zone)
    for _, card in ipairs(self.cards) do
        local from = card:getZone()
        if from then
            from:move(card, stop)
        else
            stop:put(card)
        end
    end
end

---@class MoveCard.API
moe.moveCard = {}

---@param options MoveCard.CreateOptions
---@return MoveCard
function moe.moveCard.create(options)
    return New 'MoveCard' (options.game, options.cards, options.zone)
end
