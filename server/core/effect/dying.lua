require 'core.effect'

---@class Dying.CreateOptions
---@field game Game # 这次濒死属于哪一局
---@field player Player # 谁进入濒死

---@class Dying : Effect
local M = Class 'Dying'

Extends('Dying', 'Effect')

---@param game Game
---@param player Player
function M:__init(game, player)
    self.kind   = 'dying'
    self.player = player
end

--- 濒死结算：规则侧在这一个时机里求桃与判死（内核不认识生命值属性）
---@async
function M:settle()
    self.game:fire('濒死', self)
end

---@class Dying.API
moe.dying = {}

---@param options Dying.CreateOptions
---@return Dying
function moe.dying.create(options)
    return New 'Dying' (options.game, options.player)
end
