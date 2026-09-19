require 'core.effect'

---@class UseCard.CreateOptions
---@field game Game
---@field user Player # 使用者
---@field card Card # 被使用的牌
---@field targets Player[] # 目标（可以为空表）

---@class UseCard : Effect
---@field user Player # 使用者
---@field card Card # 被使用的牌
---@field targets Player[] # 目标（可以为空表）
local M = Class 'UseCard'

Extends('UseCard', 'Effect')

---@param game Game
---@param user Player
---@param card Card
---@param targets Player[]
function M:__init(game, user, card, targets)
    self.kind    = 'useCard'
    self.user    = user
    self.card    = card
    self.targets = targets
end

---@param options UseCard.CreateOptions
---@return UseCard
function M.create(options)
    return New 'UseCard' (options.game, options.user, options.card, options.targets)
end

---@param user Player
---@param card Card
---@return Zone? # 牌所在的牌区（找到时才有）
---@return integer? # 牌在该牌区里的位置
local function findHeldZone(user, card)
    for _, zone in ipairs(user:getZones()) do
        for i, held in ipairs(zone:list()) do
            if held == card then
                return zone, i
            end
        end
    end
    return nil, nil
end

function M:settle()
    local name = self.card:getLabel()
    if type(name) ~= 'string' then
        error('这张牌没有牌名，查不到内容定义', 2)
    end
    local def = self.game:getCard(name)
    if not def then
        error('没有叫「{}」的内容定义' % { name }, 2)
    end

    local zone, index = findHeldZone(self.user, self.card)
    if not zone or not index then
        error('使用者手上没有这张牌', 2)
    end

    for _, handler in ipairs(def:getHandlers('目标合法')) do
        if handler(self) == false then
            error('「{}」的目标不合法' % { def.fullName }, 2)
        end
    end

    zone:take(index)
    for _, handler in ipairs(def:getHandlers('使用')) do
        handler(self)
    end
    self.game:fire('卡牌-结算后', self)
end

return M
