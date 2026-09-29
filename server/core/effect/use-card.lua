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

---@type Player
M.from = nil

---@param self UseCard
---@return Player # 来源：用这张牌的人
M.__getter.from = function (self)
    return self.user
end

---@async
function M:settle()
    local ok, reason = self.game:canUse(self.user, self.card, self.targets)
    if not ok then
        self:cancel(reason)
    end

    local name = self.card.name
    local phase = self.game:getUsePhase(self.user)
    if phase then
        phase:addUseCount(name, 1)
    end

    self.game:moveCard(self.card, self:getTempZone())
    self.game:fire('卡牌-结算前', self)
    self.card:fireHandlers('使用', self)
    if not self.card.def.skipsEffect then
        for target in self.game.desk:actionOrder(self.targets) do
            local effect = New 'CardEffect' (self.game, self.card, target, self)
            effect:apply():await()
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

---@type Player?
CardEffect.from = nil

---@type Player
CardEffect.to = nil

---@param self CardEffect
---@return Player? # 来源：使用者（判定阶段的那次没有）
CardEffect.__getter.from = function (self)
    return self.user
end

---@param self CardEffect
---@return Player # 承受者：这次生效冲谁来的
CardEffect.__getter.to = function (self)
    return self.target
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
