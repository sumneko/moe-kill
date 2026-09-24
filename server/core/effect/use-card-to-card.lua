require 'core.effect.effect'

---@class UseCardToCard.CreateOptions
---@field game Game
---@field user Player # 使用者
---@field card Card # 被使用的牌
---@field targetCard Card # 目标：一张牌（【无懈可击】要对的那张锦囊）

--- 一次「对一张牌使用」（与 `UseCard` 同形，只是目标是牌不是角色）
---@class UseCardToCard : Effect
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

--- 这次用牌就是一次结算：临时区自己建，不向父层取
---@return Zone
function M:getTempZone()
    return self:createTempZone()
end

---@async
function M:settle()
    local ok, reason = self.game:canUseToCard(self.user, self.card, self.targetCard)
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
    local effect = New 'CardEffectToCard' (self.game, self, def, self.targetCard)
    effect:apply()
    for _, handler in ipairs(def:getHandlers('结算后')) do
        handler(self)
    end
    self.game:fire('卡牌-结算后', self)
end

--- 这张牌对那个目标（一张牌）的一次生效
---@class CardEffectToCard : Effect
local CardEffectToCard = Class 'CardEffectToCard'

Extends('CardEffectToCard', 'Effect')

---@param game Game
---@param useCard UseCardToCard # 这次生效属于哪一次用牌
---@param def CardDef
---@param target Card # 目标那张牌
function CardEffectToCard:__init(game, useCard, def, target)
    self.kind    = 'cardEffectToCard'
    self.useCard = useCard
    self.def     = def
    self.user    = useCard.user
    self.card    = useCard.card
    self.target  = target
end

--- 对那个目标的一次生效就是一次结算：临时区自己建，不向父层取
---@return Zone
function CardEffectToCard:getTempZone()
    return self:createTempZone()
end

---@async
function CardEffectToCard:settle()
    for _, handler in ipairs(self.def:getHandlers('对卡牌生效')) do
        handler(self, self.useCard)
    end
end

---@class UseCardToCard.API
moe.useCardToCard = {}

---@param options UseCardToCard.CreateOptions
---@return UseCardToCard
function moe.useCardToCard.create(options)
    return New 'UseCardToCard' (options.game, options.user, options.card, options.targetCard)
end
