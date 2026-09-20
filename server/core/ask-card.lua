require 'core.effect'

---@class AskCard.CreateOptions
---@field game Game
---@field to Player # 被问者
---@field question any # 要什么牌（内容由发起方定，应答方自己解释）

---@class AskCard : Effect
---@field to Player # 被问者
---@field question any # 要什么牌
---@field private answered boolean # 是否已经有人应答
---@field private reply? Card # 应答方给出的那张牌
local M = Class 'AskCard'

Extends('AskCard', 'Effect')

---@param game Game
---@param to Player
---@param question any
function M:__init(game, to, question)
    self.kind     = 'askCard'
    self.to       = to
    self.question = question
    self.answered = false
end

--- 应答这次询问：给出的那张牌就是这次询问的结果（读 `.result`）
---@param value Card # 应答方给出的那张牌
function M:answer(value)
    if self.answered then
        error('这次询问已经答过了', 2)
    end
    self.answered = true
    self.reply    = value
end

--- 把询问交给应答方，返回值就是应答方给出的那张牌
---@async
---@return Card? # 那张牌；没人答上或这次询问被取消时为「不存在」
function M:settle()
    self.game:fire('游戏-询问', self)
    return self.reply
end

---@class AskCard.API
local API = {}

---@param options AskCard.CreateOptions
---@return AskCard
function API.create(options)
    return New 'AskCard' (options.game, options.to, options.question)
end

return API
