---@class Ask.CreateOptions
---@field game Game
---@field to Player # 被问者
---@field reason? string # 这次为什么问（内容由发起方定；原样带到应答方）
---@field question any # 问什么（内容由发起方定，应答方自己解释）

--- 通用决策询问：问什么、答什么都由发起方解释
---@class Ask : Effect
---@field to Player # 被问者
---@field reason string # 这次为什么问
---@field question any # 问什么
---@field reply? any # 答复（与 `.result` 同值；没答上时不存在）
local M = Class 'Ask'

Extends('Ask', 'Effect')

---@param game Game
---@param to Player
---@param reason string
---@param question any
function M:__init(game, to, reason, question)
    self.game     = game
    self.kind     = 'ask'
    self.to       = to
    self.reason   = reason
    self.question = question
end

--- 答复：与 `.result` 同值（没答上时不存在）
---@return any
M.__getter.reply = function (self)
    assert(self.task, '询问还没有发动')
    return self.task.result
end

--- 把询问交给应答方（答复一到，结果就定下了）
---@async
function M:settle()
    -- 答复可能是 `false`（合法答复），不能写成 `or` 串
    local user = self.to.user
    local answer = nil
    if user then
        answer = user:ask(self)
    end
    if answer == nil then
        answer = self.game:fire('决策-询问', self)
    end
    if answer == nil then
        -- 没人表态就是「取消」：这次询问没成立
        self.task:reject('取消')
        return
    end

    self.task:resolve(answer)

    self.game:fire('决策-答复', self)
end

---@class Ask.API
moe.ask = {}

---@param options Ask.CreateOptions
---@return Ask
function moe.ask.create(options)
    return New 'Ask' (options.game, options.to, options.reason, options.question)
end
