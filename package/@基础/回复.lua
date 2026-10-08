-- 回复：Heal 类与入口 game:heal；结算里加体力，体力回到正数就脱离濒死

---@class Heal : Effect
---@field from? Player # 治疗的来源（没来源就是空）
---@field to Player # 谁回复体力
---@field amount integer # 点数
---@field card? Card # 造成这次治疗的牌（没有对应的牌就是空）
local Heal = Class('Heal', 'Effect')

---@param game Game
---@param to Player
---@param amount integer
---@param from? Player
---@param card? Card
function Heal:__init(game, to, amount, from, card)
    self.kind   = 'heal'
    self.to     = to
    self.amount = amount
    self.from   = from
    self.card   = card
end

--- 一个阶段的三份：全局 → 来源 → 目标（没有来源就不发来源那份）
---@param stage string
function Heal:fireStage(stage)
    self.game:fire('治疗-' .. stage, self)
    self.from?:fire('治疗-来源-' .. stage, self)
    self.to:fire('治疗-目标-' .. stage, self)
end

--- 回复结算（四个阶段：开始 → 生效前 → 生效（加体力 + 脱离濒死）→ 生效后 → 结束）
---@async
function Heal:settle()
    local to = self.to
    self:fireStage('开始')
    self:fireStage('生效前')
    to:addAttr('体力', self.amount)
    -- 体力回到正数就脱离濒死（由回血方喊）
    local dying = to.dying
    if dying and to:getAttr('体力') > 0 then
        dying:leave()
    end
    self:fireStage('生效后')
    self:fireStage('结束')
end

---@class Game
local Game = Class 'Game'

--- 回复一次体力
---@async
---@param to Player # 谁回复体力
---@param amount integer # 点数
---@param from? Player # 治疗的来源
---@param card? Card # 造成这次治疗的牌
---@return Heal
function Game:heal(to, amount, from, card)
    local heal = New 'Heal' (self, to, amount, from, card)
    heal:apply():await()
    return heal
end
