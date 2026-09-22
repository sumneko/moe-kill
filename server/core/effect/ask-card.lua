require 'core.effect'

---@class AskCard.Answer # 一次答复：给出哪张牌；要打给谁的话再带上目标
---@field card Card
---@field targets? Player|Player[] # 单目标可以只给一个，多目标给一张列表（入库前统一成列表）

---@class AskCard.Option # 一个合法选项：可以给出的一张牌
---@field card Card
---@field targets? Player[] # 这张牌的可用目标（省略 = 那就不该给目标，如「打出」）

---@class AskCard.CreateOptions
---@field game Game
---@field to Player # 被问者
---@field reason? string # 这次为什么问（内核不解释，原样带给规则层）
---@field options? AskCard.Option[] # 合法选项（不给 = 不做限制）

---@class AskCard : Effect
---@field to Player # 被问者
---@field reason string # 这次为什么问
---@field options? AskCard.Option[] # 合法选项（答复必须落在里面）
---@field card? Card # 答复给出的那张牌（= `.result.card`）
---@field targets? Player[] # 答复指定的目标（= `.result.targets`；恒为一张列表）
---@field package task? Task # 父类里是 package：这里要再声明一次才能在本文件访问
local M = Class 'AskCard'

Extends('AskCard', 'Effect')

---@param game Game
---@param to Player
---@param reason string
---@param options AskCard.Option[]?
function M:__init(game, to, reason, options)
    self.game    = game
    self.kind    = 'askCard'
    self.to      = to
    self.reason  = reason
    self.options = options
end

--- 目标统一成一张列表
---@param targets? Player|Player[]
---@return Player[]?
local function toTargetList(targets)
    if targets == nil then
        return nil
    end
    if Type(targets) ~= nil then
        ---@cast targets Player
        return { targets }
    end
    ---@cast targets Player[]
    return targets
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
            local targets = toTargetList(answer.targets)
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
    self.task:resolve {
        card    = value.card,
        targets = toTargetList(value.targets),
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

--- 把询问交给应答方（答复一到，结果就定下了）
---@async
function M:settle()
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
    return New 'AskCard' (options.game, options.to, options.reason, options.options)
end
