-- 回复：Heal 类与入口 game:heal；结算里加体力，体力回到正数就脱离濒死

---@class Heal : Effect
---@field to Player # 谁回复体力
---@field amount integer # 点数
local Heal = Class('Heal', 'Effect')

---@param game Game
---@param to Player
---@param amount integer
function Heal:__init(game, to, amount)
    self.kind   = 'heal'
    self.to     = to
    self.amount = amount
end

--- 回复结算
---@async
function Heal:settle()
    local to = self.to
    to:addAttr('体力', self.amount)
    -- 体力回到正数就脱离濒死（由回血方喊）
    local dying = to.dying
    if dying and to:getAttr('体力') > 0 then
        dying:leave()
    end
end

---@class Game
local Game = Class 'Game'

--- 回复一次体力
---@async
---@param to Player # 谁回复体力
---@param amount integer # 点数
---@return Heal
function Game:heal(to, amount)
    local heal = New 'Heal' (self, to, amount)
    heal:apply():await()
    return heal
end
