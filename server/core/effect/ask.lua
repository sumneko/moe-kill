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
---@field asked boolean # 问题已经交出去了（没问出口之前不收答复）
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
    self.asked    = false
end

--- 应答这次询问：给出的答复当场成为结果（读 `.reply`）
---@param value any # 答复（内容由发起方解释）
function M:answer(value)
    if not self.asked then
        log.info('这次询问还没问出口，这条答复不收')
        return
    end
    if self.task.resolved then
        log.info('这次询问已经答过了，先给出的算数')
        return
    end
    self.task:resolve(value)
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
    self.asked = true
    self.game:fire('决策-询问', self)

    if not self.success or self.reply == nil then
        return
    end

    self.game:fire('决策-答复', self)
end

---@class Ask.API
moe.ask = {}

---@param options Ask.CreateOptions
---@return Ask
function moe.ask.create(options)
    return New 'Ask' (options.game, options.to, options.reason, options.question)
end
