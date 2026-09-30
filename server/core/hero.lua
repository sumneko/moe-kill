--- 武将牌的内容定义（姓名 / 技能名 / 自带数据；内核只存不解释）
--- **势力 / 性别 / 体力**的声明与读法都由内容侧定义（`@基础/武将.lua` 给 `HeroDef` 加字段与方法）—— 内核只管「定义本身」
---@class HeroDef
---@field name string # 裸名（= 姓名）
---@field public package string # 所属包名（显式写 public：否则 package 会被当成访问修饰符）
---@field fullName string # 完整名（包名.名字）
---@field source string # 声明它的文件（逻辑路径）
---@field private game Game # 所属的局
---@field private skillNames string[] # 拥有的技能名（按声明顺序）
---@field private values table<string, any> # 自带的数据
local M = Class 'HeroDef'

---@param game Game
---@param name string
---@param owner string
---@param source string
function M:__init(game, name, owner, source)
    self.game       = game
    self.name       = name
    self.package    = owner
    self.fullName   = owner .. '.' .. name
    self.source     = source
    self.skillNames = {}
    self.values     = {}
end

--- 声明拥有的技能（一次调用定下来；重复调以后写的为准）
---@param names string|string[] # 技能名（技能定义下一批做，这里只是数据）
---@return HeroDef
function M:skills(names)
    self.skillNames = moe.util.toList(names)
    return self
end

---@return string[] # 拥有的技能名（快照，按声明顺序）
function M:getSkills()
    ---@type string[]
    local snapshot = {}
    table.move(self.skillNames, 1, #self.skillNames, 1, snapshot)
    return snapshot
end

--- 声明一条自带的数据（内核只存不解释）
---@param name string # 数据的名字
---@param value any
---@return HeroDef
function M:value(name, value)
    self.values[name] = value
    return self
end

--- 读一条自带的数据
---@param name string # 数据的名字
---@return any # 没声明过就是「不存在」
function M:getValue(name)
    return self.values[name]
end
