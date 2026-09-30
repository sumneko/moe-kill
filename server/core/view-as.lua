---@class ViewAs : Class.Base # 一份「视为某牌」的声明（挂在玩家身上，问牌时按声明顺序依次尝试）
---@field name string # 视为哪张牌
---@field owner Player # 挂在谁身上
---@field private game Game # 属于哪一局
---@field private handlers table<string, function[]>
---@field private removed boolean # 已经撤掉了
local M = Class 'ViewAs'

---@param game Game
---@param owner Player
---@param name string
function M:__init(game, owner, name)
    self.game     = game
    self.owner    = owner
    self.name     = name
    self.handlers = {}
    self.removed  = false
end

--- 登记一个处理器（返回自己，供链式写法）
---@param event '发动'
---@param handler fun(ask: AskCard): (boolean?)
---@return ViewAs
function M:on(event, handler)
    local list = self.handlers[event]
    if not list then
        list = {}
        self.handlers[event] = list
    end
    list[#list+1] = handler
    return self
end

---@param event string
---@return function[] # 这个事件上的所有处理器（快照）
function M:getHandlers(event)
    ---@type function[]
    local snapshot = {}
    local list = self.handlers[event]
    if list then
        table.move(list, 1, #list, 1, snapshot)
    end
    return snapshot
end

--- 试一次这份声明：第一个说成立的就照声明造一张虚拟牌交出去
---@async
---@param ask AskCard
---@return Card? # 产出的牌（不成给空）
function M:tryProduce(ask)
    for _, handler in ipairs(self:getHandlers('发动')) do
        if handler(ask) then
            return self.game:createVirtualCard(self.name)
        end
    end
end

--- 撤销这份声明（幂等）
function M:remove()
    if self.removed then
        return
    end
    self.removed = true
    self.owner:removeViewAs(self)
end

--- 被 `Delete` 时撤销（`host:bindGC(viewAs)` 这种用法）
function M:__del()
    self:remove()
end

---@class ViewAs.API
moe.viewAs = {}

--- 建一份声明
---@param game Game
---@param owner Player
---@param name string # 视为哪张牌
---@return ViewAs
function moe.viewAs.create(game, owner, name)
    return New 'ViewAs' (game, owner, name)
end
