require 'core.effect'

---@class Ask.CreateOptions
---@field game Game
---@field to Player # 被问者
---@field question any # 问的是什么（内容由发起方定，回答者自己解释）

---@class Ask : Effect
---@field to Player # 被问者
---@field question any # 问的是什么
---@field answer? any # 答案：被取消或还没问完时为「不存在」
local M = Class 'Ask'

Extends('Ask', 'Effect')

---@param game Game
---@param to Player
---@param question any
function M:__init(game, to, question)
    self.kind     = 'ask'
    self.to       = to
    self.question = question
end

function M:settle()
    local answerer = self.game.answerer
    if not answerer then
        error('这一局没有回答者，问不了', 2)
    end
    local answer = answerer(self)
    if answer == nil then
        error('回答者没有给出答案', 2)
    end
    self.answer = answer
end

---@class Ask.API
local API = {}

---@param options Ask.CreateOptions
---@return Ask
function API.create(options)
    return New 'Ask' (options.game, options.to, options.question)
end

return API
