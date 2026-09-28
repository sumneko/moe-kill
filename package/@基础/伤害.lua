-- 伤害：Damage 类与入口 game:damage；结算里扣体力，扣到 ≤0 就进濒死

---@class Damage : Effect
---@field from? Player # 伤害来源（无来源的伤害为空，如【闪电】）
---@field to Player # 承受者
---@field amount integer # 点数
local Damage = Class('Damage', 'Effect')

---@param game Game
---@param from? Player
---@param to Player
---@param amount integer
function Damage:__init(game, from, to, amount)
    self.kind   = 'damage'
    self.from   = from
    self.to     = to
    self.amount = amount
end

--- 伤害结算
---@async
function Damage:settle()
    local to = self.to
    to:addAttr('体力', -self.amount)
    -- 扣到 ≤0 就进濒死（濒死就在这次伤害结算里，早于它结完）
    if to:getAttr('体力') <= 0 then
        to:enterDying(self)
    end
    self.game:fire('伤害-结束', self)
end

---@class Game
local Game = Class 'Game'

--- 造成一次伤害（来源可空 = 无来源伤害）
---@async
---@param from? Player # 伤害来源
---@param to Player # 承受者
---@param amount integer # 点数
---@return Damage # 这次伤害（已经结完：失败读 `.err`）
function Game:damage(from, to, amount)
    local damage = New 'Damage' (self, from, to, amount)
    damage:apply():await()
    return damage
end
