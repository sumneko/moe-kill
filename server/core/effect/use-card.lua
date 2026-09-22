require 'core.effect'

---@class UseCard.CreateOptions
---@field game Game
---@field user Player # 使用者
---@field card Card # 被使用的牌
---@field targets Player[] # 目标（可以为空表）

---@class UseCard : Effect
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

---@async
function M:settle()
    local ok, reason = self.game:canUse(self.user, self.card, self.targets)
    if not ok then
        self:reject(reason)
    end

    local def = self.game:getCard(self.card:getLabel())
    ---@cast def CardDef
    local zone, index = self.user:findCard(self.card)
    ---@cast zone Zone
    ---@cast index integer
    zone:take(index)
    self.game:fire('卡牌-结算前', self)
    for _, target in ipairs(self.game.desk:sortByActionOrder(self.user, self.targets)) do
        local effect = New 'CardEffect' (self.game, def, self.user, self.card, target)
        effect:apply()
    end
    self.game:fire('卡牌-结算后', self)
end

---@class CardEffect : Effect # 这张牌对某个目标的一次生效
local CardEffect = Class 'CardEffect'

Extends('CardEffect', 'Effect')

---@param game Game
---@param def CardDef
---@param user Player
---@param card Card
---@param target Player
function CardEffect:__init(game, def, user, card, target)
    self.kind   = 'cardEffect'
    self.def    = def
    self.user   = user
    self.card   = card
    self.target = target
end

---@async
function CardEffect:settle()
    for _, handler in ipairs(self.def:getHandlers('生效')) do
        handler(self)
    end
end

---@class UseCard.API
moe.useCard = {}

---@param options UseCard.CreateOptions
---@return UseCard
function moe.useCard.create(options)
    return New 'UseCard' (options.game, options.user, options.card, options.targets)
end
