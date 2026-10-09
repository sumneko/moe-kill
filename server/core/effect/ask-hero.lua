--- 要什么样的武将：候选（发起方算好；答复必须落在这里面）+ 个数区间
---@class AskHero.Condition
---@field hero? HeroDef|HeroDef[] # 候选：一名 / 一批（不给 = 不做限制）
---@field min? integer # 至少要选几个（省略 = 1）
---@field max? integer # 至多选几个（省略 = min）

--- 归一化之后的形状：候选归一成名单（不填 = 不做限制），`min` / `max` 一定给出
---@class AskHero.NormalizedCondition
---@field heroes? HeroDef[] # 候选名单（不填 = 不做限制；空表 = 一个都不行）
---@field min integer
---@field max integer

--- 把条件归一化一次（`hero` 归一成名单、`min` / `max` 补默认）
---@param condition AskHero.Condition?
---@return AskHero.NormalizedCondition?
local function normalizeCondition(condition)
    if not condition then
        return nil
    end
    local min = condition.min or 1
    ---@type AskHero.NormalizedCondition
    local normalized = {
        min = min,
        max = condition.max or min,
    }
    if condition.hero ~= nil then
        normalized.heroes = moe.util.toList(condition.hero)
    end
    return normalized
end

---@class AskHero.CreateOptions
---@field game Game
---@field to Player # 被问者
---@field reason? string # 这次为什么问（内容由发起方定；原样带到应答方）
---@field condition? AskHero.Condition # 要什么样的武将（省略 = 不做限制）

--- 要若干名武将：候选名单由发起方给，答复必须是里面的（个数落在 `min` / `max` 之间、不重复）
---@class AskHero : Effect
---@field to Player # 被问者
---@field reason string # 这次为什么问
---@field condition? AskHero.NormalizedCondition # 要什么样的武将（构造时归一化）
---@field options? HeroDef[] # 候选名单（没给条件时为空 = 不做限制）
---@field hero? HeroDef # 答复给出的第一个武将（没答就是空）
---@field heroes HeroDef[] # 答复给出的武将（恒列表，没答就是空表）
local M = Class 'AskHero'

Extends('AskHero', 'Effect')

---@param game Game
---@param to Player
---@param reason string
---@param condition AskHero.Condition?
function M:__init(game, to, reason, condition)
    self.game      = game
    self.kind      = 'askHero'
    self.to        = to
    self.reason    = reason
    self.condition = normalizeCondition(condition)
end

--- 候选名单（不填 = 不做限制）
---@return HeroDef[]?
function M:collectOptions()
    return self.condition?.heroes
end

--- 答复落在候选名单与个数区间里吗（不在就给原因；默认正好一名）
---@param value HeroDef|HeroDef[]
---@return any # 通过就是空
function M:checkAnswer(value)
    local min = self.condition?.min or 1
    local max = self.condition?.max or min
    return moe.askCard.checkTargets(moe.util.toList(value), self.options, min, max)
end

--- 答复给出的武将（恒列表：没答就是空表）
---@param self AskHero
---@return HeroDef[]
M.__getter.heroes = function (self)
    local result = self.result
    if result == nil then
        return {}
    end
    return moe.util.toList(result)
end

--- 答复给出的第一个武将（没答就是空）
---@param self AskHero
---@return HeroDef?
M.__getter.hero = function (self)
    return self.heroes[1]
end

--- 这次允许「一个都不选」吗（`min` 为 0 ⇒ 取消也是合法答复、算成立）
---@return boolean
function M:allowNone()
    return (self.condition?.min or 1) == 0
end

--- 把询问交给应答方（候选先摆好；答复一到，结果就定下了）
---@async
function M:settle()
    self.options = self:collectOptions()

    local answer = self.to.user?:askHero(self)
                or self.game:fire('武将-询问', self)
    if answer == nil then
        -- 没人表态：这次允许「一个都不选」就当空答复（成立、没有答复），否则是「取消」
        if not self:allowNone() then
            self.task:reject('取消')
        end
        return
    end

    local problem = self:checkAnswer(answer)
    if problem then
        self.task:reject(problem)
        return
    end
    self.task:resolve(answer)

    self.game:fire('武将-答复', self)
end

---@class AskHero.API
moe.askHero = {}

--- 把条件归一化一次
---@param condition AskHero.Condition?
---@return AskHero.NormalizedCondition?
function moe.askHero.normalizeCondition(condition)
    return normalizeCondition(condition)
end

---@param options AskHero.CreateOptions
---@return AskHero
function moe.askHero.create(options)
    return New 'AskHero' (options.game, options.to, options.reason, options.condition)
end
