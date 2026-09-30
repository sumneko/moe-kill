--- 一次「技能 / 装备发动」：**这段里起的结算都挂在它下面**（= 归因 —— 「这件事是哪个技能做的」沿 `parent` 链就能查到）
---@class Cast : Effect
---@field source Skill|Card # 谁发动的
---@field body fun() # 这次发动做的事
local M = Class 'Cast'

Extends('Cast', 'Effect')

---@param game Game
---@param source Skill|Card # 谁发动的
---@param from? Player # 发动者（技能看 `owner`、牌看它所在区的主人）
---@param body fun() # 这次发动做的事
function M:__init(game, source, from, body)
    self.kind   = 'cast'
    self.source = source
    self.from   = from
    self.body   = body
end

---@async
function M:settle()
    return self.body()
end
