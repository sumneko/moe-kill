-- 伤害：Damage 类与入口 game:damage；结算里扣体力，扣到 ≤0 就进濒死

---@class Damage : Effect
---@field from? Player # 伤害来源（无来源的伤害为空，如【闪电】）
---@field to Player # 承受者
---@field amount integer # 点数
---@field card? Card # 造成这次伤害的牌（没有对应的牌时为空）
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

--- 伤害结算
---@async
function Damage:settle()
    local to = self.to
    -- 伤害流程开始（= 官方「造成伤害时」，在扣体力之前）：全局一份、来源一份
    self.game:fire('伤害-开始', self)
    self.from?:fire('伤害-来源-开始', self)
    to:addAttr('体力', -self.amount)
    -- 扣到 ≤0 就进濒死（濒死就在这次伤害结算里，早于它结完）
    if to:getAttr('体力') <= 0 then
        to:enterDying(self)
    end
    self.game:fire('伤害-结束', self)
    -- 承受侧那份（带方向词，见 architecture 的「对当事人再发一份」）：技能挂在他自己的时机表上
    to:fire('伤害-目标-结束', self)
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
