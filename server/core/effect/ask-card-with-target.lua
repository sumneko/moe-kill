--- 要什么样的牌：`AskCard.Condition` 那些条件 + 目标（这批牌给出给谁）
---@class AskCardWithTarget.Condition : AskCard.Condition
---@field targets? Player|Player[] # 候选目标（答复必须落在里面；不填 = 不做限制）
---@field minTarget? integer # 至少要给几个目标（省略 = 1）
---@field maxTarget? integer # 至多给几个目标（省略 = minTarget）

--- 归一化之后的形状（基类那几条见 `AskCard.NormalizedCondition`；`targets` 归一成列表、`minTarget` / `maxTarget` 补上默认）
---@class AskCardWithTarget.NormalizedCondition : AskCard.NormalizedCondition
---@field targets? Player[]
---@field minTarget integer
---@field maxTarget integer

---@class AskCardWithTarget.CreateOptions
---@field game Game
---@field to Player # 被问者
---@field reason? string # 这次为什么问（内容由发起方定；原样带到应答方）
---@field condition? AskCardWithTarget.Condition # 要什么样的牌（省略 = 不做限制）

--- 要一次「给出」：答复必须带目标（这批牌给出给哪些人），个数落在 `minTarget` / `maxTarget` 之间
--- 「怎么给出去」不归它管 —— 那是发起方（技能 / 装备）自己的事：拿到 `.cards` 与 `.targets` 之后自己处置
---@class AskCardWithTarget : AskCard
---@field condition? AskCardWithTarget.NormalizedCondition # 要什么样的牌（比基类多 `targets` / `minTarget` / `maxTarget`）
---@field targets Player[] # 答复指定的目标（没答就是空表）
---@field target? Player # 答复指定的第一个目标（没答就是空）
local M = Class 'AskCardWithTarget'

Extends('AskCardWithTarget', 'AskCard')

---@param condition AskCardWithTarget.Condition? # 要什么样的牌（父类已归一遍基类字段，这里补归子类字段）
function M:__init(_, _, _, condition)
    self.kind = 'askCardWithTarget'
    local normalized = self.condition
    if normalized and condition then
        if normalized.targets then
            normalized.targets = moe.util.toList(normalized.targets)
        end
        normalized.minTarget = condition.minTarget or 1
        normalized.maxTarget = condition.maxTarget or normalized.minTarget
    end
end

--- 答复要给出目标（个数落在区间里、都在候选名单里、不重复）
---@param option AskCard.Option
---@param value AskCard.Answer
---@return any # 通过就是空
function M:checkOption(option, value)
    local min = self.condition?.minTarget or 1
    local max = self.condition?.maxTarget or min
    ---@type Player[]
    local list = {}
    if value.targets ~= nil then
        list = moe.util.toList(value.targets)
    end
    if #list == 0 then
        if min == 0 then
            return nil
        end
        return '这次答复要给出目标'
    end
    return moe.askCard.checkTargets(list, self.condition?.targets, min, max)
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
    return New 'AskCardWithTarget' (options.game, options.to, options.reason, options.condition)
end
