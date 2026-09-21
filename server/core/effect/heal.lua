require 'core.effect'

---@class Heal.CreateOptions
---@field game Game # 这次回复属于哪一局
---@field to Player # 谁回复体力
---@field amount integer # 点数

---@class Heal : Effect
local M = Class 'Heal'

Extends('Heal', 'Effect')

---@param game Game
---@param to Player
---@param amount integer
function M:__init(game, to, amount)
    self.kind   = 'heal'
    self.to     = to
    self.amount = amount
end

---@async
function M:settle()
    self.game:fire('回复-前', self)
    self.game:fire('回复-生效', self)
    self.game:fire('回复-后', self)
end

---@class Heal.API
moe.heal = {}

---@param options Heal.CreateOptions
---@return Heal
function moe.heal.create(options)
    return New 'Heal' (options.game, options.to, options.amount)
end
