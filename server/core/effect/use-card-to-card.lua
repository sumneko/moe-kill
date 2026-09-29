---@class UseCardToCard.CreateOptions
---@field game Game
---@field user Player # 使用者
---@field card Card # 被使用的牌
---@field targetCard Card # 目标：一张牌（【无懈可击】要对的那张锦囊）

--- 一次「对一张牌使用」（与 `UseCard` 同形，只是目标是牌不是角色）
---@class UseCardToCard : Effect
---@field cardEffectToCard? CardEffectToCard # 这次使用对那张牌产生的那次生效（还没走到那一步就是空）
local M = Class 'UseCardToCard'

Extends('UseCardToCard', 'Effect')

---@param game Game
---@param user Player
---@param card Card
---@param targetCard Card
function M:__init(game, user, card, targetCard)
    self.kind       = 'useCardToCard'
    self.user       = user
    self.card       = card
    self.targetCard = targetCard
end

---@type Player
M.from = nil

---@param self UseCardToCard
---@return Player # 来源：用这张牌的人
M.__getter.from = function (self)
    return self.user
end

---@async
function M:settle()
    local ok, reason = self.game:canUseToCard(self.user, self.card, self.targetCard)
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
    self.user:fire('卡牌-结算前', self)
    self.card:fireHandlers('使用', self)
    local effect = New 'CardEffectToCard' (self.game, self.card, self.targetCard, self)
    self.cardEffectToCard = effect
    effect:apply():await()
    self.game:fire('卡牌-结算后', self)
end

--- 这张牌对那个目标（一张牌）的一次生效
---@class CardEffectToCard : Effect
local CardEffectToCard = Class 'CardEffectToCard'

Extends('CardEffectToCard', 'Effect')

---@param game Game
---@param card Card
---@param target Card # 目标那张牌
---@param useCard UseCardToCard # 这次生效属于哪一次用牌
function CardEffectToCard:__init(game, card, target, useCard)
    self.kind    = 'cardEffectToCard'
    self.card    = card
    self.target  = target
    self.useCard = useCard
    self.user    = useCard.user
end

---@type Player
CardEffectToCard.from = nil

---@param self CardEffectToCard
---@return Player # 来源：使用者
CardEffectToCard.__getter.from = function (self)
    return self.user
end

--- 它本身不做事：这张牌要不要被阻止，由内容侧在 `'效果-能否生效'` 里回报
---@async
function CardEffectToCard:settle()
end

---@class UseCardToCard.API
moe.useCardToCard = {}

---@param options UseCardToCard.CreateOptions
---@return UseCardToCard
function moe.useCardToCard.create(options)
    return New 'UseCardToCard' (options.game, options.user, options.card, options.targetCard)
end
