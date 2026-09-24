require 'core.effect.effect'

--- 要什么样的角色：候选名单（发起方算好；答复必须落在这里面）
---@class AskPlayer.Condition
---@field players Player[] # 候选角色

---@class AskPlayer.CreateOptions
---@field game Game
---@field to Player # 被问者
---@field reason? string # 这次为什么问（内容由发起方定；原样带到应答方）
---@field condition? AskPlayer.Condition # 要什么样的角色（省略 = 不做限制）

--- 要一名角色：候选名单由内核摆好，答复必须是里面的一个
---@class AskPlayer : Effect
---@field to Player # 被问者
---@field reason string # 这次为什么问
---@field condition? AskPlayer.Condition # 要什么样的角色
---@field options? Player[] # 候选名单（没给条件时为空 = 不做限制）
---@field player? Player # 答复给出的那名角色（= `.result`）
---@field package task? Task # 父类里是 package：这里要再声明一次才能在本文件访问
local M = Class 'AskPlayer'

Extends('AskPlayer', 'Effect')

---@param game Game
---@param to Player
---@param reason string
---@param condition AskPlayer.Condition?
function M:__init(game, to, reason, condition)
    self.game      = game
    self.kind      = 'askPlayer'
    self.to        = to
    self.reason    = reason
    self.condition = condition
end

--- 候选名单（没给条件就是空 = 不做限制）
---@return Player[]?
function M:collectOptions()
    return self.condition?.players
end

--- 答复落在候选里吗（不在就给原因）
---@param value Player
---@return any # 通过就是空
function M:checkAnswer(value)
    local options = self.options
    if not options then
        return nil
    end
    if moe.util.arrayHas(options, value) then
        return nil
    end
    return '答复不在可选角色里'
end

--- 应答这次询问：给出的答复当场成为这次询问的结果（读 `.player`）
---@param value Player? # 答不上就给 nil（等同没答）
function M:answer(value)
    if value == nil then
        return
    end
    if self.task.resolved then
        log.info('这次询问已经答过了，先给出的算数')
        return
    end
    local problem = self:checkAnswer(value)
    if problem then
        self.task:reject(problem)
        return
    end
    self.task:resolve(value)
end

--- 答复给出的那名角色
---@param self AskPlayer
---@return Player?
M.__getter.player = function (self)
    return self.result
end

--- 把询问交给应答方（候选先摆好；答复一到，结果就定下了）
---@async
function M:settle()
    self.options = self:collectOptions()
    self.game:fire('决策-询问', self)

    if not self.result then
        return
    end

    self.game:fire('决策-答复', self)
end

---@class AskPlayer.API
moe.askPlayer = {}

---@param options AskPlayer.CreateOptions
---@return AskPlayer
function moe.askPlayer.create(options)
    return New 'AskPlayer' (options.game, options.to, options.reason, options.condition)
end
