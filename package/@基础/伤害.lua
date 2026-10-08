-- 伤害：Damage 类与入口 game:damage；结算里扣体力，扣到 ≤0 就进濒死

---@class Damage : Effect
---@field from? Player # 伤害来源（无来源的伤害为空，如【闪电】）
---@field to Player # 承受者
---@field amount integer # 点数
---@field card? Card # 造成这次伤害的牌（没有对应的牌时为空）
---@field cardsInPlace Card[] # 这次伤害涉及的实体牌里还在原处的那些（虚拟牌看它的素材）
---@field private cardZones Zone[] # 结算开始时这些实体牌各自在哪个区（判「还在不在原处」用）
local Damage = Class('Damage', 'Effect')

---@param game Game
---@param from? Player
---@param to Player
---@param amount integer
---@param card? Card # 造成这次伤害的牌
function Damage:__init(game, from, to, amount, card)
    self.kind   = 'damage'
    self.from   = from
    self.to     = to
    self.amount = amount
    self.card   = card
end

---@type Card[]
Damage.cardsInPlace = nil

--- 还在原处的那些实体牌（能拿几张拿几张；没有牌就是空表）
---@return Card[] # 还在原处的实体牌
Damage.__getter.cardsInPlace = function (self)
    local card = self.card
    if not card then
        return {}
    end
    ---@type Card[]
    local cards = {}
    for i, one in ipairs(card.physical) do
        if one:getZone() == self.cardZones[i] then
            cards[#cards + 1] = one
        end
    end
    return cards
end

--- 一个阶段的三份：全局 → 来源 → 目标（没有来源就不发来源那份）
---@param stage string
function Damage:fireStage(stage)
    self.game:fire('伤害-' .. stage, self)
    self.from?:fire('伤害-来源-' .. stage, self)
    self.to:fire('伤害-目标-' .. stage, self)
end

--- 伤害结算（四个阶段：开始 → 生效前 → 生效（扣体力 + 濒死）→ 生效后 → 结束）
---@async
function Damage:settle()
    local to    = self.to
    local card  = self.card
    local cards = card and card.physical or {}
    self.cardZones = {}
    for i, one in ipairs(cards) do
        self.cardZones[i] = one:getZone()
    end
    self:fireStage('开始')
    self:fireStage('生效前')
    to:addAttr('体力', -self.amount)
    -- 扣到 ≤0 就进濒死（濒死就在这次伤害结算里，早于「生效后」）
    if to:getAttr('体力') <= 0 then
        to:enterDying(self)
    end
    self:fireStage('生效后')
    self:fireStage('结束')
end

---@class Game
local Game = Class 'Game'

--- 造成一次伤害（来源可空 = 无来源伤害）
---@async
---@param from? Player # 伤害来源
---@param to Player # 承受者
---@param amount integer # 点数
---@param card? Card # 造成这次伤害的牌
---@return Damage # 这次伤害（已经结完：失败读 `.err`）
function Game:damage(from, to, amount, card)
    local damage = New 'Damage' (self, from, to, amount, card)
    damage:apply():await()
    return damage
end
