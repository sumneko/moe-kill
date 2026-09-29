---@class BuffDef # 内容侧声明的一只状态（`Buff '名字'`）
---@field name string # 裸名
---@field public package string # 所属包名（显式写 public：否则 package 会被当成访问修饰符）
---@field fullName string # 完整名（包名.名字）
---@field source string # 声明它的文件（逻辑路径）
---@field private handlers table<string, function[]>
local BuffDef = Class 'BuffDef'

---@param name string
---@param owner string
---@param source string
function BuffDef:__init(name, owner, source)
    self.name     = name
    self.package  = owner
    self.fullName = owner .. '.' .. name
    self.source   = source
    self.handlers = {}
end

--- 登记这只状态的一个时机
---@param event string
---@param handler function
---@return BuffDef
function BuffDef:on(event, handler)
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
function BuffDef:getHandlers(event)
    ---@type function[]
    local snapshot = {}
    local list = self.handlers[event]
    if list then
        table.move(list, 1, #list, 1, snapshot)
    end
    return snapshot
end

---@class Buff : GCHost # 挂在角色身上的一段状态：资源与订阅靠 bindGC 跟着它活
---@field name string # 定义名（裸名）
---@field owner Player # 挂在谁身上
---@field payload? any # 挂上时给的那份载荷（内核只存不解释，给内容侧自己约定）
---@field private def BuffDef # 内容定义
---@field private game Game # 属于哪一局
local M = Class 'Buff'

Extends('Buff', 'GCHost')

---@param game Game
---@param def BuffDef
---@param owner Player
---@param payload? any
function M:__init(game, def, owner, payload)
    self.game    = game
    self.def     = def
    self.name    = def.name
    self.owner   = owner
    self.payload = payload
end

--- 失去：幂等（内部就是 `Delete(self)`）
function M:remove()
    Delete(self)
end

--- 跑这只状态这条时机的所有处理器
---@param event string
---@param ... any
function M:fireHandlers(event, ...)
    for _, handler in ipairs(self.def:getHandlers(event)) do
        handler(self, ...)
    end
end

--- 失去这只状态：发时机 → 从宿主摘掉（资源与订阅随后由基类放掉）
function M:__del()
    self:fireHandlers('失去')
    self.owner:removeBuff(self)
end

---@class Buff.API
moe.buff = {}

--- 声明一只状态（给 `game:declareBuff` 用）
---@param name string
---@param owner string
---@param source string
---@return BuffDef
function moe.buff.declare(name, owner, source)
    return New 'BuffDef' (name, owner, source)
end

--- 把一只状态挂到某人身上
---@param game Game
---@param def BuffDef
---@param owner Player
---@param payload? any # 内容侧自己约定的一份载荷（内核只存不解释）
---@return Buff
function moe.buff.create(game, def, owner, payload)
    return New 'Buff' (game, def, owner, payload)
end
