require 'core.effect.effect'

--- 一次答复：给出哪张牌；要打给谁的话再带上目标
---@class AskCard.Answer
---@field card? Card # 给出的牌（答不上就是不给）
---@field targets? Player|Player[] # 单目标可以只给一个，多目标给一张列表（入库前统一成列表）

--- 一个合法选项：可以给出的一张牌
---@class AskCard.Option
---@field card Card # 给出的牌
---@field targets? Player[] # 这张牌的可用目标（省略 = 那就不该给目标，如「打出」）

--- 要什么样的牌：每个字段都是一条筛选条件（数组 = 满足其一；单值 = 当成只有一个的数组；不填 = 无要求）
---@class AskCard.Condition
---@field name? string|string[] # 牌名
---@field zone? string|Zone|(string|Zone)[] # 牌在哪个区里（名字按「被问者 → 局上」解析；别人的区要传区对象）
---@field card? Card|Card[] # 牌必须在这批里（可以不属于任何牌区）
---@field target? Player|Player[] # 可用目标要与它至少有一个重合

---@class AskCard.CreateOptions
---@field game Game
---@field to Player # 被问者
---@field reason? string # 这次为什么问（内核不解释，原样带给规则层）
---@field condition? AskCard.Condition # 要什么样的牌（省略 = 不做限制）

---@class AskCard : Effect
---@field to Player # 被问者
---@field reason string # 这次为什么问
---@field condition? AskCard.Condition # 要什么样的牌
---@field options? AskCard.Option[] # 按条件算出的合法选项（询问交给应答方之前就摆好；没给条件时为空 = 不做限制）
---@field card? Card # 答复给出的那张牌（= `.result.card`）
---@field targets? Player[] # 答复指定的目标（= `.result.targets`；恒为一张列表）
---@field package task? Task # 父类里是 package：这里要再声明一次才能在本文件访问
local M = Class 'AskCard'

Extends('AskCard', 'Effect')

---@param game Game
---@param to Player
---@param reason string
---@param condition AskCard.Condition?
function M:__init(game, to, reason, condition)
    self.game      = game
    self.kind      = 'askCard'
    self.to        = to
    self.reason    = reason
    self.condition = condition
end


--- 找区：区对象直接用；名字按「被问者 → 局上」解析
---@param game Game
---@param to Player
---@param item string|Zone
---@return Zone?
local function resolveZone(game, to, item)
    if type(item) ~= 'string' then
        return item
    end
    return to:getZone(item) or game:getZone(item)
end

--- 这张牌算不算一个合法选项
---@param game Game
---@param to Player
---@param card Card
---@param names string[]?
---@param targets Player[]?
---@param usable boolean # 要不要按「使用」的语义跑 canUse
---@return AskCard.Option? # 不算就返回空
local function optionOf(game, to, card, names, targets, usable)
    if names and not moe.util.arrayHas(names, card:getLabel()) then
        return nil
    end
    if not usable then
        return { card = card }
    end
    local ok, _, legal = game:canUse(to, card)
    if not ok or not legal then
        return nil
    end
    if not targets then
        return { card = card, targets = legal }
    end
    ---@type Player[]
    local list = {}
    for _, player in ipairs(legal) do
        if moe.util.arrayHas(targets, player) then
            list[#list + 1] = player
        end
    end
    if #list == 0 then
        return nil
    end
    return { card = card, targets = list }
end

--- 按条件算出合法选项（候选默认来自被问者的牌区；给了 `zone` / `card` 就只看那些）
---@param game Game
---@param to Player
---@param condition AskCard.Condition?
---@param reason string # `'使用'` = 按使用语义筛（跑 canUse）
---@return AskCard.Option[]? # 没给条件就是空 = 不做限制
local function collectOptions(game, to, condition, reason)
    if not condition then
        return nil
    end

    ---@type Card[]
    local cards = {}
    if condition.zone then
        for _, item in ipairs(moe.util.toList(condition.zone)) do
            local zone = resolveZone(game, to, item)
            if zone then
                local held = zone:list()
                table.move(held, 1, #held, #cards + 1, cards)
            end
        end
    end
    if condition.card then
        local list = moe.util.toList(condition.card)
        table.move(list, 1, #list, #cards + 1, cards)
    end
    if not condition.zone and not condition.card then
        for _, zone in ipairs(to:getZones()) do
            local held = zone:list()
            table.move(held, 1, #held, #cards + 1, cards)
        end
    end

    local names   = condition.name and moe.util.toList(condition.name) or nil
    local targets = condition.target and moe.util.toList(condition.target) or nil
    local usable  = reason == '使用' or targets ~= nil

    ---@type AskCard.Option[]
    local options = {}
    for _, card in ipairs(cards) do
        local option = optionOf(game, to, card, names, targets, usable)
        if option then
            options[#options + 1] = option
        end
    end
    return options
end

--- 答复是否落在合法选项里
---@param options AskCard.Option[]?
---@param answer AskCard.Answer
---@return any # 不合法时给原因
local function answerProblem(options, answer)
    if not options then
        return nil
    end
    for _, option in ipairs(options) do
        if option.card == answer.card then
            ---@type Player[]?
            local targets = nil
            if answer.targets ~= nil then
                targets = moe.util.toList(answer.targets)
            end
            if not option.targets then
                if targets then
                    return '这次答复不该给目标'
                end
                return nil
            end
            if not targets or #targets == 0 then
                return '这次答复要给出目标'
            end
            for _, target in ipairs(targets) do
                if not moe.util.arrayHas(option.targets, target) then
                    return '答复的目标不在可选项里'
                end
            end
            return nil
        end
    end
    return '答复不在可选项里'
end

--- 应答这次询问：给出的答复当场成为这次询问的结果（读 `.result`）
---@param value AskCard.Answer? # 答不上就给 nil（等同没答）
function M:answer(value)
    if value == nil then
        return
    end
    if self.task.resolved then
        log.info('这次询问已经答过了，先给出的算数')
        return
    end
    local problem = answerProblem(self.options, value)
    if problem then
        self.task:reject(problem)
        return
    end
    ---@type Player[]?
    local targets = nil
    if value.targets ~= nil then
        targets = moe.util.toList(value.targets)
    end
    self.task:resolve {
        card    = value.card,
        targets = targets,
    }
end

--- 答复给出的那张牌
---@param self AskCard
---@return Card?
M.__getter.card = function (self)
    return self.result?.card
end

--- 答复指定的目标（恒为一张列表）
---@param self AskCard
---@return Player[]?
M.__getter.targets = function (self)
    return self.result?.targets
end

--- 把询问交给应答方（选项先摆好；答复一到，结果就定下了）
---@async
function M:settle()
    self.options = collectOptions(self.game, self.to, self.condition, self.reason)
    self.game:fire('卡牌-询问', self)

    if not self.result then
        return
    end

    self.game:fire('卡牌-答复', self)
    self.game:fire('卡牌-答复后', self)
end

---@class AskCard.API
moe.askCard = {}

---@param options AskCard.CreateOptions
---@return AskCard
function moe.askCard.create(options)
    return New 'AskCard' (options.game, options.to, options.reason, options.condition)
end
