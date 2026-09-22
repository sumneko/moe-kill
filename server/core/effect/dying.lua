require 'core.effect'

---@class Dying.CreateOptions
---@field game Game # 这次濒死属于哪一局
---@field player Player # 谁进入濒死
---@field damage? Damage # 把它打到濒死的这次伤害（内核只搬运，不解释）

---@class Dying : Effect
---@field damage? Damage # 把它打到濒死的这次伤害（没有就是别的来源）
local M = Class 'Dying'

Extends('Dying', 'Effect')

---@param game Game
---@param player Player
---@param damage? Damage
function M:__init(game, player, damage)
    self.kind   = 'dying'
    self.player = player
    self.damage = damage
end

--- 濒死结算：规则侧在 `'濒死-进入'` 里求桃与判死；结完还活着就触发 `'濒死-离开'`
---@async
function M:settle()
    self.game:fire('濒死-进入', self)
    if self.player:isAlive() then
        self.game:fire('濒死-离开', self)
    end
end

---@class Dying.API
moe.dying = {}

---@param options Dying.CreateOptions
---@return Dying
function moe.dying.create(options)
    return New 'Dying' (options.game, options.player, options.damage)
end
