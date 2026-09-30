--- 一次答复：给出哪张牌 + 打给谁（要一次使用就得给目标；无目标牌不用）
---@class AskUseCard.Answer : AskCard.Answer
---@field targets? Player|Player[] # 单目标可以只给一个，多目标给一张列表（入库前统一成列表）

--- 一个合法选项：一张能用的牌 + 它这次使用的可用目标与数量区间
---@class AskUseCard.Option : AskCard.Option
---@field plan Game.UsableTargets # 「不指定目标」的牌是 legal 空表、0、0

--- 要什么样的牌：`AskCard.Condition` 那些条件 + 一条 target
---@class AskUseCard.Condition : AskCard.Condition
---@field target? Player|Player[] # 可用目标要与它至少有一个重合

---@class AskUseCard.CreateOptions
---@field game Game
---@field to Player # 被问者
---@field reason? string # 这次为什么问（内容由发起方定；原样带到应答方）
---@field condition? AskUseCard.Condition # 要什么样的牌（省略 = 不做限制）
---@field useOptions? Game.UseOptions # 这次使用的选项（候选收集与用出去都带上）

--- 要一次「使用」：候选逐张跑 canUse（用不了的牌不进选项），答复必须带目标
---@class AskUseCard : AskCard
---@field condition? AskUseCard.Condition # 要什么样的牌（比基类多一条 target）
---@field useOptions? Game.UseOptions # 这次使用的选项（照原样带去那次使用）
---@field options? AskUseCard.Option[] # 合法选项（覆写基类：带可用目标与数量区间）
---@field targets? Player[] # 答复指定的目标（= `.result.targets`；无目标牌是「不存在」）
---@field useCard? UseCard # 把这次答复用出去得到的那次使用（没答复 / 还没用过就是空）
local M = Class 'AskUseCard'

Extends('AskUseCard', 'AskCard')

function M:__init(_, _, _, _, useOptions)
    self.kind       = 'askUseCard'
    self.useOptions = useOptions
end

--- 能把这张牌用出去才进选项（条件里给了 `target` 的话，合法目标已由 `canUse` 收窄）
---@param card Card
---@return AskUseCard.Option?
function M:makeOption(card)
    local ok, _, plan = self.game:canUse(self.to, card, self.condition?.target, self.useOptions)
    if not ok then
        return nil
    end
    ---@cast plan Game.UsableTargets
    return { card = card, plan = plan }
end

--- 答复要给出目标，个数落在选项的区间里，且都在可用目标里；无目标牌不要给目标
---@param option AskCard.Option
---@param value AskCard.Answer
---@return any # 通过就是空
function M:checkOption(option, value)
    ---@cast option AskUseCard.Option
    local legal = option.plan.legal
    if #legal == 0 then
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
    if #list < option.plan.min then
        return '至少要指定 {} 个目标' % { option.plan.min }
    end
    if #list > option.plan.max then
        return '至多指定 {} 个目标' % { option.plan.max }
    end
    ---@type table<Player, true>
    local seen = {}
    for _, target in ipairs(list) do
        if not moe.util.arrayHas(legal, target) then
            return '答复的目标不在可选项里'
        end
        if seen[target] then
            return '答复的目标重复了'
        end
        seen[target] = true
    end
    return nil
end

--- 答复指定的目标（无目标牌是「不存在」）
---@param self AskUseCard
---@return Player[]?
M.__getter.targets = function (self)
    return self.result?.targets
end

--- 把答复的牌用出去（没有答复就什么都不做；重复调给的是同一次）
---@async
---@return UseCard? # 那次使用（没答复就是空；用不出去时读它的 `.err`）
function M:use()
    if self.useCard then
        return self.useCard
    end
    local card = self.card
    if not card then
        return nil
    end
    self.useCard = self.game:useCard(self.to, card, self.targets, self.useOptions)
    return self.useCard
end

---@class AskUseCard.API
moe.askUseCard = {}

---@param options AskUseCard.CreateOptions
---@return AskUseCard
function moe.askUseCard.create(options)
    return New 'AskUseCard' (options.game, options.to, options.reason, options.condition, options.useOptions)
end
