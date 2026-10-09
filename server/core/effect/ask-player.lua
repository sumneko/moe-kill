--- 要什么样的角色：候选（发起方算好；答复必须落在这里面）+ 个数区间
---@class AskPlayer.Condition
---@field player? Player|Player[]|true|fun(player: Player): boolean # 候选：一名 / 一批 / `true` = 不限 / 谓词（在存活角色里筛）
---@field min? integer # 至少要选几个（省略 = 1）
---@field max? integer # 至多选几个（省略 = min）

--- 归一化之后的形状：候选解算成名单（不填 = 不做限制），`min` / `max` 一定给出
---@class AskPlayer.NormalizedCondition
---@field players? Player[] # 候选名单（不填 = 不做限制；空表 = 一个都不行）
---@field min integer
---@field max integer

--- 把条件归一化一次：`player` 的四种写法解算成候选名单（谓词在**存活角色**里筛）、`min` / `max` 补默认
---@param game Game
---@param condition AskPlayer.Condition?
---@return AskPlayer.NormalizedCondition?
local function normalizeCondition(game, condition)
    if not condition then
        return nil
    end
    local min = condition.min or 1
    ---@type AskPlayer.NormalizedCondition
    local normalized = {
        min = min,
        max = condition.max or min,
    }
    local player = condition.player
    if type(player) == 'function' then
        ---@cast player fun(player: Player): boolean
        ---@type Player[]
        local list = {}
        for _, one in ipairs(game.desk.alivePlayers) do
            if player(one) then
                list[#list + 1] = one
            end
        end
        normalized.players = list
    elseif player ~= nil and player ~= true then
        normalized.players = moe.util.toList(player)
    end
    return normalized
end

---@class AskPlayer.CreateOptions
---@field game Game
---@field to Player # 被问者
---@field reason? string # 这次为什么问（内容由发起方定；原样带到应答方）
---@field condition? AskPlayer.Condition # 要什么样的角色（省略 = 不做限制）

--- 要若干名角色：候选名单由内核摆好，答复必须是里面的（个数落在 `min` / `max` 之间、不重复）
---@class AskPlayer : Effect
---@field to Player # 被问者
---@field reason string # 这次为什么问
---@field condition? AskPlayer.NormalizedCondition # 要什么样的角色（构造时归一化）
---@field options? Player[] # 候选名单（没给条件时为空 = 不做限制）
---@field player? Player # 答复给出的第一个角色（没答就是空）
---@field players Player[] # 答复给出的角色（恒列表，没答就是空表）
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
    self.condition = normalizeCondition(game, condition)
end

--- 候选名单（不填 = 不做限制）
---@return Player[]?
function M:collectOptions()
    return self.condition?.players
end

--- 答复落在候选名单与个数区间里吗（不在就给原因；默认正好一名）
---@param value Player|Player[]
---@return any # 通过就是空
function M:checkAnswer(value)
    local min = self.condition?.min or 1
    local max = self.condition?.max or min
    return moe.askCard.checkTargets(moe.util.toList(value), self.options, min, max)
end

--- 答复给出的角色（恒列表：没答就是空表）
---@param self AskPlayer
---@return Player[]
M.__getter.players = function (self)
    local result = self.result
    if result == nil then
        return {}
    end
    return moe.util.toList(result)
end

--- 答复给出的第一个角色（没答就是空）
---@param self AskPlayer
---@return Player?
M.__getter.player = function (self)
    return self.players[1]
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

    local answer = self.to.user?:askPlayer(self)
                or self.game:fire('决策-询问', self)
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

    self.game:fire('决策-答复', self)
end

---@class AskPlayer.API
moe.askPlayer = {}

--- 把条件归一化一次：`player` 的四种写法解算成候选名单（谓词在**存活角色**里筛）、`min` / `max` 补默认
---@param game Game
---@param condition AskPlayer.Condition?
---@return AskPlayer.NormalizedCondition?
function moe.askPlayer.normalizeCondition(game, condition)
    return normalizeCondition(game, condition)
end

---@param options AskPlayer.CreateOptions
---@return AskPlayer
function moe.askPlayer.create(options)
    return New 'AskPlayer' (options.game, options.to, options.reason, options.condition)
end
