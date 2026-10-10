--- 这两半条件：牌那半用 `AskCard.Condition`、目标那半用 `AskPlayer.Condition`
---@class AskCardWithTarget.Conditions
---@field card? AskCard.Condition # 要什么样的牌（`cancelable` 也在这半：它管的是整次询问）
---@field target? AskPlayer.Condition # 这批牌给出给哪些目标

---@class AskCardWithTarget.CreateOptions
---@field game Game
---@field to Player # 被问者
---@field reason? string # 这次为什么问（内容由发起方定；原样带到应答方）
---@field conditions? AskCardWithTarget.Conditions # 两半条件（省略 = 都不做限制）

--- 要一次「给出」：答复必须带目标（这批牌给出给哪些目标），个数落在目标那半的 `min` / `max` 之间
--- 「怎么给出去」不归它管 —— 那是发起方（技能 / 装备）自己的事：拿到 `.cards` 与 `.targets` 之后自己处置
---@class AskCardWithTarget : AskCard
---@field condition? AskCard.NormalizedCondition # 牌那半（形状与 `AskCard` 一模一样，父类照常读它）
---@field targetCondition AskPlayer.NormalizedCondition # 目标那半（构造时归一化，候选恒给出；条件里写的是 `target`）
---@field targets Player[] # 答复指定的目标（没答就是空表）
---@field target? Player # 答复指定的第一个目标（没答就是空）
local M = Class 'AskCardWithTarget'

Extends('AskCardWithTarget', 'AskCard')

---@param user User
---@return AskCard.Answer?
function M:askUser(user)
    return user:askCardWithTarget(self)
end

---@param conditions AskCardWithTarget.Conditions? # 两半条件（父类先拿整份空转一遍，这里把它换成两半各自的归一结果）
function M:__init(_, _, _, conditions)
    self.kind            = 'askCardWithTarget'
    self.condition       = moe.askCard.normalizeCondition(self.game, self.to, conditions?.card)
    self.targetCondition = moe.askPlayer.normalizeCondition(self.game, conditions?.target)
end

--- 答复要给出目标（个数落在区间里、都在候选名单里、不重复）
---@param option AskCard.Option
---@param value AskCard.Answer
---@return any # 通过就是空
function M:checkOption(option, value)
    local condition = self.targetCondition
    ---@type Player[]
    local list = {}
    if value.targets ~= nil then
        list = moe.util.toList(value.targets)
    end
    if #list == 0 then
        if condition.min == 0 then
            return nil
        end
        return '这次答复要给出目标'
    end
    return moe.askCard.checkTargets(list, condition.players, condition.min, condition.max)
end

--- 答复指定的目标（没答就是空表）
---@param self AskCardWithTarget
---@return Player[]
M.__getter.targets = function (self)
    return self.result?.targets or {}
end

--- 答复指定的第一个目标（没答就是空）
---@param self AskCardWithTarget
---@return Player?
M.__getter.target = function (self)
    return self.targets[1]
end

---@class AskCardWithTarget.API
moe.askCardWithTarget = {}

---@param options AskCardWithTarget.CreateOptions
---@return AskCardWithTarget
function moe.askCardWithTarget.create(options)
    return New 'AskCardWithTarget' (options.game, options.to, options.reason, options.conditions)
end
