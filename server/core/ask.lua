require 'core.effect'

---@class Ask.CreateOptions
---@field game Game
---@field to Player # 被问者
---@field question any # 问的是什么（内容由发起方定，回答者自己解释）

---@class Ask : Effect
---@field to Player # 被问者
---@field question any # 问的是什么
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

--- 问一次：返回值就是这次询问的答案
---@async
---@return any # 回答者给的答案；没答上或这次询问被取消时为「不存在」
function M:settle()
    local answerer = self.game.answerer
    if not answerer then
        error('这一局没有回答者，问不了', 2)
    end
    return answerer(self)
end

---@class Ask.API
local API = {}

---@param options Ask.CreateOptions
---@return Ask
function API.create(options)
    return New 'Ask' (options.game, options.to, options.question)
end

return API
