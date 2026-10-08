--- 技能的目标条件：个数区间 + 逐角色谓词（`: targets { … }` 声明的形状）
---@class SkillDef.TargetCondition
---@field min? integer # 至少几个目标（省略 = 1）
---@field max? integer # 至多几个目标（省略 = 1）
---@field filter? fun(player: Player, skill: Skill): boolean # 留下哪些角色（省略 = 全部存活角色）

--- 技能的内容定义（名字 / 自动同意 / 标签；内核只存不解释）
--- **「自动同意」是玩家的偏好默认值，与「是否必须发动」无关** —— 强制发动的技能自己不问（底本 Chapter1/Section2 与 Chapter2/Section5 讲的是「必须发动」与「锁定技」标签正交）
---@class SkillDef
---@field name string # 裸名（= 技能名）
---@field public package string # 所属包名（显式写 public：否则 package 会被当成访问修饰符）
---@field fullName string # 完整名（包名.名字）
---@field source string # 声明它的文件（逻辑路径）
---@field package autoFire boolean # 自动同意的默认值（不写 = 每次问）
---@field cardCondition? AskCard.Condition # 这次发动要带的牌（`cards()` 声明；不写 = 不要牌）
---@field targetCondition? SkillDef.TargetCondition # 这次发动要的目标（`targets()` 声明；不写 = 不要目标）
---@field private game Game # 所属的局
---@field private tagSet table<string, true> # 标签集合
---@field private handlers table<string, function[]> # 各时机上的回调（按登记顺序）
local M = Class 'SkillDef'

--- 「觉醒技」视为附带这两个标签（底本 Chapter2/Section5）
---@type table<string, string[]>
local IMPLIED_TAGS = {
    觉醒技 = { '锁定技', '限定技' },
}

---@param game Game
---@param name string
---@param owner string
---@param source string
function M:__init(game, name, owner, source)
    self.game     = game
    self.name     = name
    self.package  = owner
    self.fullName = owner .. '.' .. name
    self.source   = source
    self.autoFire = false
    self.tagSet   = {}
    self.handlers = {}
end

--- 登记这个技能的一个钩子（`'被动'` 在技能挂上时跑一次，内容侧在那里订阅 / 建状态）
---@param event string
---@param handler function
---@return SkillDef
function M:on(event, handler)
    local list = self.handlers[event]
    if not list then
        list = {}
        self.handlers[event] = list
    end
    list[#list + 1] = handler
    return self
end

---@param event string
---@return function[] # 这条时机上的所有回调（快照）
function M:getHandlers(event)
    local list = self.handlers[event]
    if not list then
        return {}
    end
    return moe.util.copy(list)
end

--- 声明「自动同意」的默认值（不写 = false = 被动触发时每次都问）
---@param value boolean
---@return SkillDef
function M:auto(value)
    self.autoFire = value
    return self
end

--- 声明「这次发动要带的牌」（筛选条件照 `AskCard.Condition`，`min` / `max` 不写 = 1 / 1；不写整条 = 不要牌）
---@param condition AskCard.Condition
---@return SkillDef
function M:cards(condition)
    self.cardCondition = condition
    return self
end

--- 声明「这次发动要的目标」（`min` / `max` 不写 = 1 / 1；不写整条 = 不要目标）
---@param condition SkillDef.TargetCondition
---@return SkillDef
function M:targets(condition)
    self.targetCondition = condition
    return self
end

--- 声明标签（可多次调，取并集）
---@param names string|string[]
---@return SkillDef
function M:tags(names)
    for _, name in ipairs(moe.util.toList(names)) do
        self.tagSet[name] = true
    end
    return self
end

--- 有没有这个标签（「觉醒技」视为附带锁定技与限定技）
---@param name string
---@return boolean
function M:hasTag(name)
    if self.tagSet[name] then
        return true
    end
    for tag, implied in pairs(IMPLIED_TAGS) do
        if self.tagSet[tag] and moe.util.arrayHas(implied, name) then
            return true
        end
    end
    return false
end

---@return string[] # 声明过的标签（快照，顺序不定）
function M:getTags()
    ---@type string[]
    local snapshot = {}
    for name in pairs(self.tagSet) do
        snapshot[#snapshot + 1] = name
    end
    return snapshot
end

--- 这次发动带的牌与目标（内核按技能声明收集、答复校验之后给；= `SkillCast.use` —— 没声明的那半是空表）
---@class Skill.Use
---@field cards Card[] # 这次发动带的牌
---@field targets Player[] # 这次发动指定的目标

--- 挂在角色身上的一个技能：订阅与资源由内容侧在「被动」钩子里 `host:bindGC(…)` 挂上，停用时内核释放容器
---@class Skill : GCHost
---@field name string # 定义名（裸名）
---@field owner Player # 谁拥有
---@field auto boolean # 被动触发时要不要自动同意（不询问；玩家 / 客户端可切）
---@field def SkillDef # 内容定义（公开字段；收集选项时内核读它的声明）
---@field private game Game # 属于哪一局
---@field private passiveSuppress integer # 被压制的层数（出厂 1 = 未启用）
---@field private passiveHost? GCHost # 本次应用时给回调的容器（懒建；停用时释放）
local S = Class 'Skill'

Extends('Skill', 'GCHost')

---@param game Game
---@param def SkillDef
---@param owner Player
function S:__init(game, def, owner)
    self.game  = game
    self.def   = def
    self.name  = def.name
    self.owner = owner
    self.auto  = def.autoFire
    self.passiveSuppress = 1
end

--- 问一次要不要发动：自动同意开着就直接放行，否则问「发动」这一句（技能自己决定在哪儿问）
---@async
---@return boolean # 要不要发动
function S:confirm()
    if self.auto then
        return true
    end
    return self.game:askChoice(self.owner, self.name, { '发动' }).choice == '发动'
end

--- 以这次技能发动为归因地跑一段：里面起的结算都挂在它下面（`parent` 链上查得到「这是哪个技能做的」）
---@async
---@param body fun(cast: SkillCast) # 这次发动做的事
---@param use? Skill.Use # 这次发动带的牌与目标（没声明前置的可以不给）
---@return SkillCast # 这次发动
function S:cast(body, use)
    use = use or { cards = {}, targets = {} }
    local cast = New 'SkillCast' (self.game, self, self.owner, body, use)
    cast:apply():await()
    return cast
end

--- 这个技能上登记过这条钩子吗（有「使用」钩子 = 可以作为主动技发动）
---@param event string
---@return boolean
function S:hasHandler(event)
    return #self.def:getHandlers(event) > 0
end

--- 主动发动这个技能：跑「使用」钩子（归因到这次发动名下）
---@param use? Skill.Use # 这次发动带的牌与目标（没声明前置的可以不给）
---@async
---@return SkillCast # 这次发动
function S:use(use)
    local handlers = self.def:getHandlers('使用')
    return self:cast(function (cast)
        for _, handler in ipairs(handlers) do
            handler(cast)
        end
    end, use)
end

--- 摘掉这个技能（幂等，内部就是 `Delete(self)`）
function S:remove()
    Delete(self)
end

--- 启用（拥有时默认启用）：松开一层压制（松开到 0 时应用）
---@return function # 撤销这一次松开
function S:enablePassive()
    self.passiveSuppress = self.passiveSuppress - 1
    if self.passiveSuppress == 0 then
        self:applyPassive()
    end
    return function ()
        self:disablePassive()
    end
end

--- 停用（如技能被克制 / 封印）：压上一层压制（压回 1 时撤销已应用的效果）
---@return function # 撤销这一次压制
function S:disablePassive()
    self.passiveSuppress = self.passiveSuppress + 1
    if self.passiveSuppress == 1 then
        self:removePassive()
    end
    return function ()
        self:enablePassive()
    end
end

--- 跑「被动」钩子：给它一个随本次应用存活的容器（要挂什么就 `host:bindGC(…)`）
---@private
function S:applyPassive()
    local host = moe.gc.host()
    self.passiveHost = host
    for _, handler in ipairs(self.def:getHandlers('被动')) do
        handler(self, host)
    end
end

--- 释放本次应用挂下的东西（先摘掉再释放，重复触发不会重复）
---@private
function S:removePassive()
    local host = self.passiveHost
    self.passiveHost = nil
    if host then
        Delete(host)
    end
end

--- 摘掉：先放掉已应用的东西，再从宿主那儿除名
function S:__del()
    self:removePassive()
    self.owner:removeSkill(self)
end
