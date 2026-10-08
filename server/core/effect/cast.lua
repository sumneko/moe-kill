--- 一次「技能 / 装备发动」：**这段里起的结算都挂在它下面**（= 归因 —— 「这件事是哪个技能做的」沿 `parent` 链就能查到）
---@class Cast : Effect
---@field source Skill|Card # 谁发动的
---@field body fun(cast: Cast): any # 这次发动做的事（返回值就是这次发动的结果，读 `cast.result`）
local M = Class 'Cast'

Extends('Cast', 'Effect')

---@param game Game
---@param source Skill|Card # 谁发动的
---@param from? Player # 发动者（技能看 `owner`、牌看它所在区的主人）
---@param body fun(cast: Cast): any # 这次发动做的事（返回值就是这次发动的结果）
function M:__init(game, source, from, body)
    self.kind   = 'cast'
    self.source = source
    self.from   = from
    self.body   = body
end

---@async
function M:settle()
    return self.body(self)
end

--- 技能发动的 `Cast`（`Skill:cast` / `Skill:use` 造它）：`source` 一定是技能实例、`from` 一定有、`use` 是这次发动带的牌与目标（没声明前置的给空表）
---@class SkillCast : Cast
---@field source Skill # 发动的技能
---@field from Player # 发动者（技能拥有者）
---@field use Skill.Use # 这次发动带的牌与目标
local SC = Class 'SkillCast'

Extends('SkillCast', 'Cast')

---@param use Skill.Use # 这次发动带的牌与目标（构造前已补空）
function SC:__init(_, _, _, _, use)
    self.use = use
end
