require 'core.effect.effect'

---@class Dying.CreateOptions
---@field game Game # 这次濒死属于哪一局
---@field player Player # 谁进入濒死
---@field damage? Damage # 把它打到濒死的**最后一次**伤害（内核只搬运，不解释）

---@class Dying : Effect
---@field damage? Damage # 把它打到濒死的最后一次伤害（濒死期间再受伤就换成新的那次）
---@field private left boolean # 有没有脱离濒死（体力恢复为正时由规则侧调 `leave`）
local M = Class 'Dying'

Extends('Dying', 'Effect')

---@param game Game
---@param player Player
---@param damage? Damage
function M:__init(game, player, damage)
    self.kind   = 'dying'
    self.player = player
    self.damage = damage
    self.left   = false
end

--- 已经脱离濒死了吗
---@return boolean
function M:hasLeft()
    return self.left
end

--- 脱离濒死：体力恢复为正时由规则侧调；当场触发 `'濒死-离开'`，重复调没反应
function M:leave()
    if self.left then
        return
    end
    self.left = true
    self.game:clearDying(self)
    self.game:fire('濒死-离开', self)
end

--- 濒死结算：规则侧在 `'濒死-进入'` 里求桃；结完还没脱离就杀死他（死亡时机里那次濒死的账还在）
---@async
function M:settle()
    self.game:fire('濒死-进入', self)
    if self.left then
        return
    end
    self.player:setAlive(false)
    self.game:clearDying(self)
end

---@class Dying.API
moe.dying = {}

---@param options Dying.CreateOptions
---@return Dying
function moe.dying.create(options)
    return New 'Dying' (options.game, options.player, options.damage)
end
