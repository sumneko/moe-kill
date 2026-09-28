-- 濒死：Dying 类与玩家身上的 enterDying；进入时从顺序锚点起求【桃】，没人回正就死

---@class Dying : Effect
---@field damage? Damage # 把它打到濒死的最后一次伤害（濒死期间再受伤就换成新的那次）
---@field private left boolean # 有没有脱离濒死（体力恢复为正时由规则侧调 `leave`）
local Dying = Class('Dying', 'Effect')

---@param game Game
---@param player Player
---@param damage? Damage
function Dying:__init(game, player, damage)
    self.kind   = 'dying'
    self.player = player
    self.damage = damage
    self.left   = false
end

--- 已经脱离濒死了吗
---@return boolean
function Dying:hasLeft()
    return self.left
end

--- 脱离濒死：体力恢复为正时由规则侧调，重复调没反应
function Dying:leave()
    if self.left then
        return
    end
    self.left = true
    self.player.dying = nil
end

--- 濒死结算
---@async
function Dying:settle()
    -- 求桃：从顺序锚点起绕一圈（阵亡者自动跳过），同一个人可以连给多张
    local player  = self.player
    local game    = self.game
    -- 已经脱离过的：不问也不杀
    if self.left then
        return
    end
    ---@type AskUseCard.Condition # 只要能救他的【桃】
    local condition = { name = '桃', target = player }
    for asker in game.desk:actionOrder() do
        -- 答了就接着问他，答不上来换下一位
        while game:askUseCard(asker, '濒死', condition).useCard do
            -- 救回来了就收工
            if self.left then
                return
            end
        end
    end
    -- 一圈都没人救 ⇒ 判死
    player:setAlive(false)
    -- 先死再清：'玩家-死亡' 里那次濒死的账还在（奖惩据此读凶手）
    player.dying = nil
end

---@class Player
---@field dying? Dying # 他当前那次濒死（不在濒死就是空）
local Player = Class 'Player'

--- 进入濒死：当场结算；他已经在濒死中就把致死伤害换成这一次、返回那一次
---@async
---@param damage? Damage # 把它打到濒死的这次伤害
---@return Dying
function Player:enterDying(damage)
    local current = self.dying
    if current then
        current.damage = damage
        return current
    end
    local dying = New 'Dying' (self.game, self, damage)
    self.dying = dying
    dying:apply():await()
    return dying
end
