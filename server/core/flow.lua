require 'core.effect'

---@class Flow.CreateOptions
---@field game Game
---@field handler fun(): any # 这一局的流程（加载期由内容登记）

---@class Flow : Effect # 这一局的流程：跑起来就是一次效果（可等待、可停）
---@field handler fun(): any # 流程本体
local M = Class 'Flow'

Extends('Flow', 'Effect')

---@param game Game
---@param handler fun(): any
function M:__init(game, handler)
    self.game    = game
    self.kind    = 'flow'
    self.handler = handler
end

--- 跑这一局的流程：返回值就是这次流程的结果
function M:settle()
    return self.handler()
end

---@class Flow.API
moe.flow = {}

---@param options Flow.CreateOptions
---@return Flow
function moe.flow.create(options)
    return New 'Flow' (options.game, options.handler)
end
