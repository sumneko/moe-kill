---@class Effect
---@field kind string # 种类标识（基类给默认值，子类在自己的构造里覆盖）
---@field game Game # 这次效果所属的局
local M = Class 'Effect'

---@param game Game
function M:__init(game)
    self.kind = 'effect'
    self.game = game
end

function M:apply()
    local pop <close> = self.game:pushEffect(self)
    self:settle()
end

function M:settle()
    error('效果子类必须实现 settle', 2)
end

return M
