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

    local name = self.card.name
    local phase = self.game:getUsePhase(self.user)
    if phase then
        phase:addUseCount(name, 1)
    end

    local zone, index = self.user:findCard(self.card)
    ---@cast zone Zone
    ---@cast index integer
    zone:take(index)
    self.game:fire('卡牌-结算前', self)
    self.card:fireHandlers('使用', self)
    if not self.card:getDef()?.skipsEffect then
        for target in self.game.desk:actionOrder(self.targets) do
            local effect = New 'CardEffect' (self.game, self.card, target, self)
            effect:apply()
        end
    end
    self.game:fire('卡牌-结算后', self)
end

--- 这张牌对某个目标的一次生效（使用期逐目标 / 判定阶段每张一次）
---@class CardEffect : Effect
---@field card Card
---@field target Player
---@field useCard? UseCard # 这次生效属于哪一次用牌（判定阶段的那次没有）
---@field user Player # 使用者（判定阶段的那次没有）
local CardEffect = Class 'CardEffect'

Extends('CardEffect', 'Effect')

---@param game Game
---@param card Card
---@param target Player
---@param useCard? UseCard # 这次生效属于哪一次用牌（判定阶段的不给）
function CardEffect:__init(game, card, target, useCard)
    self.kind    = 'cardEffect'
    self.card    = card
    self.target  = target
    self.useCard = useCard
    if useCard then
        self.user = useCard.user
    end
end

---@async
function CardEffect:settle()
    self.card:fireHandlers('生效', self, self.useCard)
end

---@class UseCard.API
moe.useCard = {}

---@param options UseCard.CreateOptions
---@return UseCard
function moe.useCard.create(options)
    return New 'UseCard' (options.game, options.user, options.card, options.targets)
end
