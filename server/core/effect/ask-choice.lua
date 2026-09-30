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
---@field asked boolean # 问题已经交出去了（没问出口之前不收答复）
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
    self.asked   = false
end

--- 应答这次询问：挑中的选项当场成为结果（不在给出去的选项里就拒收；给 nil 等同没答）
---@param value any? # 挑的是哪一个选项（给 nil 等同没答）
function M:answer(value)
    if value == nil then
        return
    end
    if not self.asked then
        log.info('这次询问还没问出口，这条答复不收')
        return
    end
    if self.task.resolved then
        log.info('这次询问已经答过了，先给出的算数')
        return
    end
    if not moe.util.arrayHas(self.options, value) then
        self.task:reject('答复不在可选项里')
        return
    end
    self.task:resolve(value)
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
    self.asked = true
    self.game:fire('决策-询问', self)

    if not self.success or self.choice == nil then
        return
    end

    self.game:fire('决策-答复', self)
end

---@class AskChoice.API
moe.askChoice = {}

---@param options AskChoice.CreateOptions
---@return AskChoice
function moe.askChoice.create(options)
    return New 'AskChoice' (options.game, options.to, options.reason, options.options)
end
