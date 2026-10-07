---@class AskUseSkill.CreateOptions
---@field game Game
---@field to Player # 被问者
---@field reason? string # 这次为什么问（内容由发起方定；原样带到应答方）

--- 要一次技能使用：候选 = 被问者身上有主动发动钩子（`'使用'`）的技能，答复必须是其中的一个
---@class AskUseSkill : Effect
---@field to Player # 被问者
---@field reason string # 这次为什么问
---@field options Skill[] # 可选的技能（询问交给应答方之前就摆好）
---@field skill? Skill # 答复的技能（= `.result`）
---@field cast? Cast # 把这次答复发动出去得到的「那次发动」（没答复 / 还没发动就是空）
local M = Class 'AskUseSkill'

Extends('AskUseSkill', 'Effect')

---@param game Game
---@param to Player
---@param reason string
function M:__init(game, to, reason)
    self.game    = game
    self.kind    = 'askUseSkill'
    self.to      = to
    self.reason  = reason
    self.options = {}
end

--- 候选：身上有主动发动钩子的技能（按获得顺序）
---@return Skill[]
function M:collectOptions()
    ---@type Skill[]
    local options = {}
    for _, skill in ipairs(self.to:getSkills()) do
        if skill:hasHandler('使用') then
            options[#options + 1] = skill
        end
    end
    return options
end

--- 答复落在候选里吗（不在就给原因）
---@param value Skill
---@return any # 通过就是空
function M:checkAnswer(value)
    if moe.util.arrayHas(self.options, value) then
        return nil
    end
    return '答复不是可以发动的技能'
end

--- 答复的技能（没答上就是空）
---@param self AskUseSkill
---@return Skill?
M.__getter.skill = function (self)
    return self.result
end

--- 把这次答复发动出去（幂等；没答复就什么都不做）
---@async
---@return Cast? # 那次发动
function M:use()
    if self.cast then
        return self.cast
    end
    local skill = self.skill
    if not skill then
        return nil
    end
    self.cast = skill:use()
    return self.cast
end

--- 把询问交给应答方（候选先摆好；答复一到，结果就定下了）
---@async
function M:settle()
    self.options = self:collectOptions()

    local answer = self.game:fire('技能-询问', self)
    if answer == nil then
        return
    end

    local problem = self:checkAnswer(answer)
    if problem then
        self.task:reject(problem)
        return
    end
    self.task:resolve(answer)
end

---@class AskUseSkill.API
moe.askUseSkill = {}

---@param options AskUseSkill.CreateOptions
---@return AskUseSkill
function moe.askUseSkill.create(options)
    return New 'AskUseSkill' (options.game, options.to, options.reason)
end
