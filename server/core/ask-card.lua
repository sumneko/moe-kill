require 'core.effect'

---@class AskCard.CreateOptions
---@field game Game
---@field to Player # 被问者
---@field reason? string # 这次为什么问（内核不解释，原样带给规则层）
---@field question any # 要什么牌（内容由发起方定，应答方自己解释）

---@class AskCard : Effect
---@field to Player # 被问者
---@field reason string # 这次为什么问
---@field question any # 要什么牌
---@field card? Card # 答复方给出的那张牌（与 `.result` 同值；没人答上时不存在）
local M = Class 'AskCard'

Extends('AskCard', 'Effect')

---@param game Game
---@param to Player
---@param reason string
---@param question any
function M:__init(game, to, reason, question)
    self.game     = game
    self.kind     = 'askCard'
    self.to       = to
    self.reason   = reason
    self.question = question
end

--- 应答这次询问：给出的那张牌当场成为这次询问的结果（读 `.result`）
---@param value Card # 应答方给出的那张牌
function M:answer(value)
    if self.result then
        error('这次询问已经答过了', 2)
    end
    self:resolve(value)
end

--- 把询问交给应答方（答复一到，结果就定下了）
---@async
function M:settle()
    self.game:fire('卡牌-询问', self)
    self.card = self.result
    self.game:fire('卡牌-答复', self)
end

---@class AskCard.API
local API = {}

---@param options AskCard.CreateOptions
---@return AskCard
function API.create(options)
    return New 'AskCard' (options.game, options.to, options.reason, options.question)
end

return API
