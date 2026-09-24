require 'core.effect.effect'

--- 一次答复：给出哪张牌（要一次使用时再带上目标）
---@class AskCard.Answer
---@field card? Card # 给出的牌（答不上就是不给）
---@field targets? Player|Player[] # 目标：只有 `AskUseCard` 接受（`AskCard` 给了会被拒收）

--- 一个合法选项：可以给出的一张牌
---@class AskCard.Option
---@field card Card # 给出的牌
---@field targets? Player[] # 这张牌的可用目标（「要一次使用」才有；有它就代表答复必须给目标、且要落在这里）

--- 要什么样的牌：每个字段都是一条筛选条件（数组 = 满足其一；单值 = 当成只有一个的数组；不填 = 无要求）
---@class AskCard.Condition
---@field name? string|string[] # 牌名
---@field zone? string|Zone|(string|Zone)[] # 牌在哪个区里（名字按「被问者 → 局上」解析；别人的区要传区对象）
---@field card? Card|Card[] # 牌必须在这批里（可以不属于任何牌区）

---@class AskCard.CreateOptions
---@field game Game
---@field to Player # 被问者
---@field reason? string # 这次为什么问（内容由发起方定；原样带到应答方）
---@field condition? AskCard.Condition # 要什么样的牌（省略 = 不做限制）

---@class AskCard : Effect
---@field to Player # 被问者
---@field reason string # 这次为什么问
---@field condition? AskCard.Condition # 要什么样的牌
---@field options? AskCard.Option[] # 按条件算出的合法选项（询问交给应答方之前就摆好；没给条件时为空 = 不做限制）
---@field card? Card # 答复给出的那张牌（= `.result.card`）
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

--- 把一张牌装成一个选项（不算就返回空）—— 子类在这里补「能不能用、目标是谁」
---@param card Card
---@return AskCard.Option?
function M:makeOption(card)
    return { card = card }
end

--- 按条件算出合法选项（候选默认来自被问者的牌区；给了 `zone` / `card` 就只看那些）
---@return AskCard.Option[]? # 没给条件就是空 = 不做限制
function M:collectOptions()
    local condition = self.condition
    if not condition then
        return nil
    end

    ---@type Card[]
    local cards = {}
    if condition.zone then
        for _, item in ipairs(moe.util.toList(condition.zone)) do
            local zone = resolveZone(self.game, self.to, item)
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
        for _, zone in ipairs(self.to:getZones()) do
            local held = zone:list()
            table.move(held, 1, #held, #cards + 1, cards)
        end
    end

    local names = condition.name and moe.util.toList(condition.name) or nil

    ---@type AskCard.Option[]
    local options = {}
    for _, card in ipairs(cards) do
        if not names or moe.util.arrayHas(names, card:getLabel()) then
            local option = self:makeOption(card)
            if option then
                options[#options + 1] = option
            end
        end
    end
    return options
end

--- 这个选项与这份答复配不配（子类在这里补「目标」那一半）
---@param option AskCard.Option
---@param value AskCard.Answer
---@return any # 通过就是空
function M:checkOption(option, value)
    if value.targets ~= nil then
        return '这次答复不该给目标'
    end
    return nil
end

--- 答复落在合法选项里吗（不在就给原因）
---@param value AskCard.Answer
---@return any # 通过就是空
function M:checkAnswer(value)
    local options = self.options
    if not options then
        return nil
    end
    for _, option in ipairs(options) do
        if option.card == value.card then
            return self:checkOption(option, value)
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
    local problem = self:checkAnswer(value)
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

--- 答复已定下、答复时机之前跑一次（子类在这里处置那张牌）
---@async
function M:onAnswered()
end

--- 把询问交给应答方（选项先摆好；答复一到，结果就定下了）
---@async
function M:settle()
    self.options = self:collectOptions()
    self.game:fire('卡牌-询问', self)

    if not self.result then
        return
    end

    self:onAnswered()
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
