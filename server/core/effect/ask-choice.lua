--- 一次答复：从给出去的选项里挑一个
---@class AskChoice.CreateOptions
---@field game Game
---@field to Player # 被问者
---@field reason? string # 这次为什么问（内容由发起方定；原样带到应答方）
---@field options any[] # 有哪些可选项（内容由发起方定，应答方自己解释）

--- 要一名角色在若干选项里挑一个：选项由发起方给，答复必须是其中之一（不答 = 取消，`.choice` 为空）
---@class AskChoice : Effect
---@field to Player # 被问者
---@field reason string # 这次为什么问
---@field options any[] # 可选项（内容由发起方定）
---@field choice? any # 挑中的那个选项（没答上时不存在）
local M = Class 'AskChoice'

Extends('AskChoice', 'Effect')

---@param game Game
---@param to Player
---@param reason string
---@param options any[]
function M:__init(game, to, reason, options)
    self.game    = game
    self.kind    = 'askChoice'
    self.to      = to
    self.reason  = reason
    self.options = options
end

--- 答复落在给出去的选项里吗（不在就给原因）
---@param value any
---@return any # 通过就是空
function M:checkAnswer(value)
    if moe.util.arrayHas(self.options, value) then
        return nil
    end
    return '答复不在可选项里'
end

--- 挑中的那个选项（没答上时不存在）
---@return any
M.__getter.choice = function (self)
    assert(self.task, '询问还没有发动')
    return self.task.result
end

--- 把询问交给应答方（选项已经摆在身上；答复一到，结果就定下了）
---@async
function M:settle()
    local answer = self.game:fire('决策-询问', self)
    if answer == nil then
        return
    end

    local problem = self:checkAnswer(answer)
    if problem then
        self.task:reject(problem)
        return
    end
    self.task:resolve(answer)

    self.game:fire('决策-答复', self)
end

---@class AskChoice.API
moe.askChoice = {}

---@param options AskChoice.CreateOptions
---@return AskChoice
function moe.askChoice.create(options)
    return New 'AskChoice' (options.game, options.to, options.reason, options.options)
end
