--- 技能的发动方式（只影响「能不能主动发动」，与强制与否无关）
---@alias 技能类型 '主动'|'被动'|'自动'

--- 技能的内容定义（名字 / 发动方式 / 标签；内核只存不解释）
--- **发动方式与标签是两个正交维度**：底本 Chapter1/Section2「是否必须发动……与此技能是否带有"锁定技"标签无关」+ Chapter2/Section5「"锁定技"……已经成为了一个标签」
---@class SkillDef
---@field name string # 裸名（= 技能名）
---@field public package string # 所属包名（显式写 public：否则 package 会被当成访问修饰符）
---@field fullName string # 完整名（包名.名字）
---@field source string # 声明它的文件（逻辑路径）
---@field private kindName 技能类型 # 发动方式（默认「主动」；只影响「能不能主动发动」，与强制与否无关）
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
    self.kindName = '主动'
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
    ---@type function[]
    local snapshot = {}
    local list = self.handlers[event]
    if list then
        table.move(list, 1, #list, 1, snapshot)
    end
    return snapshot
end

--- 声明发动方式（主动 / 被动 / 自动）
---@param kind 技能类型
---@return SkillDef
function M:kind(kind)
    self.kindName = kind
    return self
end

---@return 技能类型 # 发动方式
function M:getKind()
    return self.kindName
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

--- 挂在角色身上的一个技能：订阅与资源由内容侧在「被动」钩子里 `host:bindGC(…)` 挂上，停用时内核释放容器
---@class Skill : GCHost
---@field name string # 定义名（裸名）
---@field owner Player # 谁拥有
---@field private def SkillDef # 内容定义
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
    self.passiveSuppress = 1
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
