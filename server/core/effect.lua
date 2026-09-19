---@class Effect
---@field kind string # 种类标识（基类给默认值，子类在自己的构造里覆盖）
---@field game Game # 这次效果所属的局
---@field parent? Effect # 外层效果：这个效果是在哪个效果的结算里被结算的（栈空时结算则为「不存在」）
local M = Class 'Effect'

---@param game Game
function M:__init(game)
    self.kind = 'effect'
    self.game = game
end

function M:apply()
    self.parent = self.game:getCurrentEffect()
    local pop <close> = self.game:pushEffect(self)
    self:settle()
end

function M:settle()
    error('效果子类必须实现 settle', 2)
end

---@class Effect.API
local API = {}

return API
