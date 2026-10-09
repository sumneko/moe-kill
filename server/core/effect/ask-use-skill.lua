---@class AskUseSkill.CreateOptions
---@field game Game
---@field to Player # 被问者
---@field reason? string # 这次为什么问（内容由发起方定；原样带到应答方）

--- 技能这次能挑的牌与张数区间（技能声明了 `cards` 才有）
---@class AskUseSkill.CardPlan
---@field legal Card[] # 能挑的牌
---@field min integer # 至少要给几张
---@field max integer # 至多给几张

--- 技能这次能挑的目标与个数区间（技能声明了 `targets` 才有）
---@class AskUseSkill.TargetPlan
---@field legal Player[] # 能挑的目标
---@field min integer # 至少要选几个
---@field max integer # 至多选几个

--- 一个合法选项：一个技能，以及它的前置（牌 / 目标）各自能挑什么
---@class AskUseSkill.Option
---@field skill Skill # 哪个技能
---@field cards? AskUseSkill.CardPlan # 牌那半（技能声明了 `cards` 才有）
---@field targets? AskUseSkill.TargetPlan # 目标那半（技能声明了 `targets` 才有）

--- 一次答复：发动哪个技能，带上这次发动用的牌与目标（按技能声明，可有可无）
--- 由应答方从 `'技能-询问'` 里**返回**（返回空 = 不表态，问下一位）；答复不合法由内核拒收
---@class AskUseSkill.Answer
---@field skill Skill # 要发动的技能
---@field cards? Card|Card[] # 这次发动带的牌（入库前统一成列表）
---@field targets? Player|Player[] # 这次发动指定的目标（入库前统一成列表）

--- 归一化之后存进结果里的形状
---@class AskUseSkill.Result
---@field skill Skill
---@field cards? Card[]
---@field targets? Player[]

--- 要一次技能使用：候选 = 被问者身上有主动发动钩子（`'使用'`）的技能，答复必须是其中的一个
--- 技能声明过 `cards` / `targets` 的话，选项里带上「能挑的牌（与张数）」/「能挑的目标（与个数）」——
--- 凑不齐前置的技能不进选项；答复里的牌与目标必须落在选项里（声明了就必须给、没声明就不能给）
---@class AskUseSkill : Effect
---@field to Player # 被问者
---@field reason string # 这次为什么问
---@field options AskUseSkill.Option[] # 可选的技能（询问交给应答方之前就摆好）
---@field skill? Skill # 答复的技能（= `.result.skill`；没答上就是空）
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

--- 这个技能这次能挑的目标（声明里有 `filter` 就逐角色筛，没有就是所有存活角色）
---@param skill Skill
---@param condition SkillDef.TargetCondition
---@return Player[]
function M:collectTargets(skill, condition)
    ---@type Player[]
    local targets = {}
    for _, player in ipairs(self.game.desk.alivePlayers) do
        if not condition.filter or condition.filter(player, skill) then
            targets[#targets + 1] = player
        end
    end
    return targets
end

--- 这个技能现在还能发动吗（自己回合的阶段里次数有没有用尽）
---@param skill Skill
---@return boolean
function M:canFire(skill)
    local phase = self.game:getUsePhase(skill.owner)
    if not phase then
        return true
    end
    return phase:getUseCount(skill.def.fullName) < skill.def:getLimit(phase.name)
end

--- 把一个技能装成选项（前置凑不齐 / 次数用尽就返回空）
---@param skill Skill
---@return AskUseSkill.Option?
function M:makeOption(skill)
    if not self:canFire(skill) then
        return nil
    end
    ---@type AskUseSkill.Option
    local option = { skill = skill }

    local cardCondition = skill.def.cardCondition
    if cardCondition then
        local normalized = assert(moe.askCard.normalizeCondition(self.game, self.to, cardCondition))
        local cards      = moe.askCard.collectCandidates(self.to, normalized)
        if #cards < normalized.min then
            return nil
        end
        option.cards = { legal = cards, min = normalized.min, max = normalized.max }
    end

    local targetCondition = skill.def.targetCondition
    if targetCondition then
        local min     = targetCondition.min or 1
        local max     = targetCondition.max or min
        local targets = self:collectTargets(skill, targetCondition)
        if #targets < min then
            return nil
        end
        option.targets = { legal = targets, min = min, max = max }
    end

    return option
end

--- 候选：身上有主动发动钩子的技能（按获得顺序）；声明过前置的还要凑得齐
---@return AskUseSkill.Option[]
function M:collectOptions()
    ---@type AskUseSkill.Option[]
    local options = {}
    for _, skill in ipairs(self.to:getSkills()) do
        if skill:hasHandler('使用') then
            local option = self:makeOption(skill)
            if option then
                options[#options + 1] = option
            end
        end
    end
    return options
end

--- 在选项里找那个技能（找不到给空）
---@param value any
---@return AskUseSkill.Option?
function M:findOption(value)
    for _, option in ipairs(self.options) do
        if option.skill == value then
            return option
        end
    end
end

--- 牌那半：张数落在区间里、都在能挑的牌里、不重复
---@param plan AskUseSkill.CardPlan
---@param value AskUseSkill.Answer
---@return any # 通过就是空
function M:checkCards(plan, value)
    ---@type Card[]
    local cards = {}
    if value.cards ~= nil then
        cards = moe.util.toList(value.cards)
    end
    if #cards < plan.min then
        return '至少要给 {} 张牌' % { plan.min }
    end
    if #cards > plan.max then
        return '至多给 {} 张牌' % { plan.max }
    end
    ---@type table<Card, true>
    local seen = {}
    for _, card in ipairs(cards) do
        if not moe.util.arrayHas(plan.legal, card) then
            return '答复不在可选项里'
        end
        if seen[card] then
            return '答复的牌重复了'
        end
        seen[card] = true
    end
    return nil
end

--- 答复合不合法：技能落在选项里，牌与目标各自按声明校验（该给就要给、不该给就不能给）
---@param value AskUseSkill.Answer
---@return any # 通过就是空
function M:checkAnswer(value)
    if type(value) ~= 'table' then
        return '答复必须是一张表（`{ skill = ... }`）'
    end
    local option = self:findOption(value.skill)
    if not option then
        return '答复不是可以发动的技能'
    end

    if option.cards then
        local problem = self:checkCards(option.cards, value)
        if problem then
            return problem
        end
    elseif value.cards ~= nil then
        return '这次答复不该给牌'
    end

    if option.targets then
        ---@type Player[]
        local list = {}
        if value.targets ~= nil then
            list = moe.util.toList(value.targets)
        end
        if #list == 0 then
            if option.targets.min == 0 then
                return nil
            end
            return '这次答复要给出目标'
        end
        return moe.askCard.checkTargets(list, option.targets.legal, option.targets.min, option.targets.max)
    elseif value.targets ~= nil then
        return '这次答复不该给目标'
    end
    return nil
end

--- 答复入库前统一成 `{ skill, cards = 列表?, targets = 列表? }` 的形状（单值或一列都收）
---@param value AskUseSkill.Answer
---@return AskUseSkill.Result
function M:normalizeAnswer(value)
    ---@type AskUseSkill.Result
    local result = { skill = value.skill }
    if value.cards ~= nil then
        result.cards = moe.util.toList(value.cards)
    end
    if value.targets ~= nil then
        result.targets = moe.util.toList(value.targets)
    end
    return result
end

--- 答复的技能（没答上就是空）
---@param self AskUseSkill
---@return Skill?
M.__getter.skill = function (self)
    return self.result?.skill
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
    ---@type AskUseSkill.Result
    local result = assert(self.result)
    self.cast = skill:use {
        cards   = result.cards or {},
        targets = result.targets or {},
    }
    local phase = self.game:getUsePhase(skill.owner)
    if phase then
        phase:addUseCount(skill.def.fullName, 1)
    end
    return self.cast
end

--- 把询问交给应答方（候选先摆好；答复一到，结果就定下了）
---@async
function M:settle()
    self.options = self:collectOptions()

    local answer = self.game:fire('技能-询问', self)
    if answer == nil then
        -- 没人表态就是「取消」：这次询问没成立
        self.task:reject('取消')
        return
    end

    local problem = self:checkAnswer(answer)
    if problem then
        self.task:reject(problem)
        return
    end
    self.task:resolve(self:normalizeAnswer(answer))
end

---@class AskUseSkill.API
moe.askUseSkill = {}

---@param options AskUseSkill.CreateOptions
---@return AskUseSkill
function moe.askUseSkill.create(options)
    return New 'AskUseSkill' (options.game, options.to, options.reason)
end
