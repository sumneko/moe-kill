require 'core.effect'

---@class AskCard.Answer # 一次答复：给出哪张牌；要打给谁的话再带上目标
---@field card Card
---@field targets? Player|Player[] # 单目标可以只给一个，多目标给一张列表

---@class AskCard.CreateOptions
---@field game Game
---@field to Player # 被问者
---@field reason? string # 这次为什么问（内核不解释，原样带给规则层）
---@field condition any # 匹配条件：要什么样的牌（空表 = 任意牌；内核不解释）

---@class AskCard : Effect
---@field to Player # 被问者
---@field reason string # 这次为什么问
---@field condition any # 匹配条件：要什么样的牌
---@field card? Card # 答复给出的那张牌（= `.result.card`）
---@field targets? Player|Player[] # 答复指定的目标（= `.result.targets`）
---@field package task? Task # 父类里是 package：这里要再声明一次才能在本文件访问
local M = Class 'AskCard'

Extends('AskCard', 'Effect')

---@param game Game
---@param to Player
---@param reason string
---@param condition any
function M:__init(game, to, reason, condition)
    self.game      = game
    self.kind      = 'askCard'
    self.to        = to
    self.reason    = reason
    self.condition = condition
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
    self.task:resolve(value)
end

--- 答复给出的那张牌
---@param self AskCard
---@return Card?
M.__getter.card = function (self)
    return self.result?.card
end

--- 答复指定的目标
---@param self AskCard
---@return Player|Player[]?
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
    return New 'AskCard' (options.game, options.to, options.reason, options.condition)
end
