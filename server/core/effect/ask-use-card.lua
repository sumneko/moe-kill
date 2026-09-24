require 'core.effect.ask-card'

--- 一次答复：给出哪张牌 + 打给谁（要一次使用就得给目标；无目标牌不用）
---@class AskUseCard.Answer : AskCard.Answer
---@field targets? Player|Player[] # 单目标可以只给一个，多目标给一张列表（入库前统一成列表）

--- 一个合法选项：一张能用的牌 + 它的可用目标
---@class AskUseCard.Option : AskCard.Option
---@field targets? Player[] # 这张牌的可用目标（无目标牌没有这个字段）

--- 要什么样的牌：`AskCard.Condition` 那些条件 + 一条 target
---@class AskUseCard.Condition : AskCard.Condition
---@field target? Player|Player[] # 可用目标要与它至少有一个重合

---@class AskUseCard.CreateOptions
---@field game Game
---@field to Player # 被问者
---@field reason? string # 这次为什么问（内容由发起方定；原样带到应答方）
---@field condition? AskUseCard.Condition # 要什么样的牌（省略 = 不做限制）

--- 要一次「使用」：候选逐张跑 canUse（用不了的牌不进选项），答复必须带目标
---@class AskUseCard : AskCard
---@field condition? AskUseCard.Condition # 要什么样的牌（比基类多一条 target）
---@field targets? Player[] # 答复指定的目标（= `.result.targets`；无目标牌是「不存在」）
local M = Class 'AskUseCard'

Extends('AskUseCard', 'AskCard')

function M:__init()
    self.kind = 'askUseCard'
end

--- 能把这张牌用出去才进选项（条件里给了 `target` 的话，合法目标已由 `canUse` 收窄）
---@param card Card
---@return AskUseCard.Option?
function M:makeOption(card)
    local ok, _, legal = self.game:canUse(self.to, card, self.condition?.target)
    if not ok then
        return nil
    end
    if not legal then
        return { card = card }
    end
    return { card = card, targets = legal }
end

--- 答复要给出目标，且落在这个选项的可用目标里；无目标牌不要给目标
---@param option AskCard.Option
---@param value AskCard.Answer
---@return any # 通过就是空
function M:checkOption(option, value)
    ---@cast option AskUseCard.Option
    local targets = option.targets
    if not targets then
        if value.targets ~= nil and #moe.util.toList(value.targets) > 0 then
            return '这张牌不需要目标'
        end
        return nil
    end
    if value.targets == nil then
        return '这次答复要给出目标'
    end
    local list = moe.util.toList(value.targets)
    if #list == 0 then
        return '这次答复要给出目标'
    end
    for _, target in ipairs(list) do
        if not moe.util.arrayHas(targets, target) then
            return '答复的目标不在可选项里'
        end
    end
    return nil
end

--- 答复指定的目标（无目标牌是「不存在」）
---@param self AskUseCard
---@return Player[]?
M.__getter.targets = function (self)
    return self.result?.targets
end

---@class AskUseCard.API
moe.askUseCard = {}

---@param options AskUseCard.CreateOptions
---@return AskUseCard
function moe.askUseCard.create(options)
    return New 'AskUseCard' (options.game, options.to, options.reason, options.condition)
end
