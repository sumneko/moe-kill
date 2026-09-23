require 'core.effect.effect'

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

    local name = self.card:getLabel()
    ---@cast name string
    local phase = self.game:getUsePhase(self.user)
    if phase then
        phase:addUseCount(name, 1)
    end

    local def = self.game:getCard(name)
    ---@cast def CardDef
    local zone, index = self.user:findCard(self.card)
    ---@cast zone Zone
    ---@cast index integer
    zone:take(index)
    self.game:fire('卡牌-结算前', self)
    for _, handler in ipairs(def:getHandlers('结算前')) do
        handler(self)
    end
    for target in self.game.desk:actionOrder(self.targets) do
        local effect = New 'CardEffect' (self.game, self, def, target)
        effect:apply()
    end
    for _, handler in ipairs(def:getHandlers('结算后')) do
        handler(self)
    end
    self.game:fire('卡牌-结算后', self)
end

--- 这张牌对某个目标的一次生效
---@class CardEffect : Effect
local CardEffect = Class 'CardEffect'

Extends('CardEffect', 'Effect')

---@param game Game
---@param useCard UseCard # 这次生效属于哪一次用牌
---@param def CardDef
---@param target Player
function CardEffect:__init(game, useCard, def, target)
    self.kind    = 'cardEffect'
    self.useCard = useCard
    self.def     = def
    self.user    = useCard.user
    self.card    = useCard.card
    self.target  = target
end

---@async
function CardEffect:settle()
    for _, handler in ipairs(self.def:getHandlers('生效')) do
        handler(self, self.useCard)
    end
end

---@class UseCard.API
moe.useCard = {}

---@param options UseCard.CreateOptions
---@return UseCard
function moe.useCard.create(options)
    return New 'UseCard' (options.game, options.user, options.card, options.targets)
end
