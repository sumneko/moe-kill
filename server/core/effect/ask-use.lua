---@class AskUse.CreateOptions
---@field game Game
---@field to Player # 被问者
---@field reason? string # 给用户看的提示文本（内容侧写全句，如「请使用一张牌或发动一个技能」）
---@field condition? AskUseCard.Condition # 要什么样的牌（省略 = 不筛：他所有牌区的牌）
---@field useOptions? Game.UseOptions # 这次使用的选项（候选收集与用出去都带上）

--- 要一次行动：既摆出能用的牌（含视为），也摆出能发动的技能；答复给出其中一样就算数
--- 技能那一半与 `AskUseSkill` 共用同一份口径（`moe.askUseSkill` 上那几件），本类只做「摆一起」与「按答复分流」
---@class AskUse : AskUseCard
---@field skills AskUseSkill.Option[] # 能发动的技能（询问交给应答方之前就摆好）
---@field result (AskCard.Result|AskUseSkill.Result)? # 答复（牌那半或技能那半的形状）
---@field skill? Skill # 答复的技能（= `.result.skill`；答复的是牌就是空）
---@field cast? Cast # 把这次答复发动出去得到的「那次发动」（没答复 / 答复的是牌就是空）
local M = Class 'AskUse'

Extends('AskUse', 'AskUseCard')

function M:__init()
    self.kind   = 'askUse'
    self.skills = {}
end

--- 这次的答复是不是「空答复」（技能、牌、视为都没有才算）= 取消
---@param value table
---@return boolean
function M:isEmptyAnswer(value)
    if value.skill ~= nil then
        return false
    end
    return value.viewAs == nil and #moe.util.toList(value.card) == 0
end

--- 答复可以是技能，也可以是一张牌 / 一份视为；技能那条走技能那半的口径
---@param value table
---@return any # 通过就是空
function M:checkAnswer(value)
    if value.skill ~= nil then
        return moe.askUseSkill.checkAnswer(self.to, self.skills, value)
    end
    return moe.askCard.checkAnswer(self, value)
end

--- 答复按给了哪一样归一（技能答复与牌 / 视为答复的形状不同）
---@param value table
---@return AskCard.Result|AskUseSkill.Result
function M:normalizeAnswer(value)
    if value.skill ~= nil then
        return moe.askUseSkill.normalizeAnswer(value)
    end
    return moe.askCard.normalizeAnswer(value)
end

--- 答复的技能（答复的是牌就是空）
---@param self AskUse
---@return Skill?
M.__getter.skill = function (self)
    local result = self.result
    if not result then
        return nil
    end
    ---@cast result AskUseSkill.Result
    return result.skill
end

--- 答复给出的第一张牌（技能答复时是空 —— 那次答复带的牌是技能素材，不是「用的牌」）
---@param self AskUse
---@return Card?
M.__getter.card = function (self)
    if self.skill then
        return nil
    end
    return self.result?.cards[1]
end

--- 把答复的技能发动出去（幂等；没答复 / 答复的是牌就什么都不做）
---@async
---@return Cast? # 那次发动
function M:useSkill()
    if self.cast then
        return self.cast
    end
    local skill = self.skill
    if not skill then
        return nil
    end
    local result = assert(self.result)
    ---@cast result AskUseSkill.Result
    self.cast = moe.askUseSkill.fire(self.game, skill, result)
    return self.cast
end

--- 两半都摆好再交给应答方；一次什么也问不出来的询问直接算没成立（不发出去）
---@async
function M:settle()
    self.skills = moe.askUseSkill.collectOptions(self.game, self.to)
    local cardOptions = self:collectOptions()
    if #self.skills == 0 and #cardOptions == 0 then
        self.task:reject('没有可以做的事')
        return
    end
    self:settleAnswer()
end

---@class AskUse.API
moe.askUse = {}

---@param options AskUse.CreateOptions
---@return AskUse
function moe.askUse.create(options)
    return New 'AskUse' (options.game, options.to, options.reason, options.condition, options.useOptions)
end
