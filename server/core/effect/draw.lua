require 'core.effect.effect'

---@class Draw.CreateOptions
---@field game Game # 这次摸牌属于哪一局
---@field player Player # 谁摸牌
---@field count integer # 摸几张

---@class Draw : Effect
local M = Class 'Draw'

Extends('Draw', 'Effect')

---@param game Game
---@param player Player
---@param count integer
function M:__init(game, player, count)
    self.kind   = 'draw'
    self.player = player
    self.count  = count
end

--- 摸牌结算：规则侧在 `'摸牌'` 里真的取牌（用 `game:drawCards`）；已阵亡的不摸
---@async
function M:settle()
    if not self.player:isAlive() then
        return
    end
    self.game:fire('摸牌', self)
end

---@class Draw.API
moe.draw = {}

---@param options Draw.CreateOptions
---@return Draw
function moe.draw.create(options)
    return New 'Draw' (options.game, options.player, options.count)
end
