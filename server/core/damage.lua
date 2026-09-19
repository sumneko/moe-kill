require 'core.effect'

---@class Damage.CreateOptions
---@field game Game # 这次伤害属于哪一局
---@field from Player # 伤害来源
---@field to Player # 承受者
---@field amount integer # 点数

---@class Damage : Effect
---@field from Player # 伤害来源
---@field to Player # 承受者
---@field amount integer # 点数
local M = Class 'Damage'

Extends('Damage', 'Effect')

---@param game Game
---@param from Player
---@param to Player
---@param amount integer
function M:__init(game, from, to, amount)
    self.kind   = 'damage'
    self.from   = from
    self.to     = to
    self.amount = amount
end

---@param options Damage.CreateOptions
---@return Damage
function M.create(options)
    return New 'Damage' (options.game, options.from, options.to, options.amount)
end

function M:settle()
    self.game:fire('伤害-前', self)
    self.to:addAttr('体力', -self.amount)
    self.game:fire('伤害-后', self)
end

return M
