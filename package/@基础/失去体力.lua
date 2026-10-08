-- 失去体力：LoseHp 类与玩家身上的 loseHp；扣体力，扣到 ≤0 就在这次结算里进濒死
-- 「失去体力」不是伤害（底本 Chapter2/Section5）：没有来源、不发伤害类时机，因它死亡也不奖惩

---@class LoseHp : Effect
---@field player Player # 谁失去体力
---@field amount integer # 失去几点
local LoseHp = Class('LoseHp', 'Effect')

---@param game Game
---@param player Player
---@param amount integer
function LoseHp:__init(game, player, amount)
    self.kind   = 'loseHp'
    self.player = player
    self.amount = amount
end

--- 失去体力结算
---@async
function LoseHp:settle()
    local player = self.player
    player:addAttr('体力', -self.amount)
    -- 扣到 ≤0 就进濒死（没有来源：这次濒死没有致死伤害）
    if player:getAttr('体力') <= 0 then
        player:enterDying()
    end
end

---@class Player
local Player = Class 'Player'

--- 让这名角色失去体力
---@async
---@param amount integer # 失去几点
---@return LoseHp
function Player:loseHp(amount)
    local loseHp = New 'LoseHp' (self.game, self, amount)
    loseHp:apply():await()
    return loseHp
end
