---@class ViewAs : Class.Base # 一份「视为某牌」的声明（挂在玩家身上，问牌时按声明顺序依次尝试）
---@field name string # 视为哪张牌
---@field owner Player # 挂在谁身上
---@field source? Card|Skill # 关联的来源（装备传那张牌、技能传技能实例；客户端先点它再选牌与目标；发动归因到它名下）
---@field condition? AskCard.Condition # 要什么样的素材（不填 = 不要素材，牌由内核照牌名造）
---@field private game Game # 属于哪一局
---@field private handlers table<string, function[]>
---@field private removed boolean # 已经撤掉了
local M = Class 'ViewAs'

---@param game Game
---@param owner Player
---@param name string
---@param source? Card|Skill
---@param condition? AskCard.Condition
function M:__init(game, owner, name, source, condition)
    self.game      = game
    self.owner     = owner
    self.name      = name
    self.source    = source
    self.condition = condition
    self.handlers  = {}
    self.removed   = false
end

--- 登记一个处理器（返回自己，供链式写法）
---@param event '发动'
---@param handler fun(ask: AskCard): (boolean|Card|Card[]?) # 返回真 = 发动（按 `condition` 去收素材）；返回牌 = 发动且拿它们当素材；返回假 / 空 = 不发动
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

--- 素材收得到吗（同步判：收不够就跳过这份声明，连表态都不问）
---@return boolean
function M:canGatherMaterials()
    local condition = moe.askCard.normalizeCondition(self.game, self.owner, self.condition)
    if not condition then
        return true
    end
    return #moe.askCard.collectCandidates(self.owner, condition) >= condition.min
end

--- 照声明造一张虚拟牌（`materials` 是这次发动自带的素材 —— 给了就不再去收）
---@async
---@param materials? Card[] # 这次发动自带的素材
---@return Card? # 产出的牌（素材没给够就是空）
function M:produce(materials)
    if materials then
        return self.game:createVirtualCard(self.name, materials)
    end
    if not self.condition then
        return self.game:createVirtualCard(self.name)
    end
    local ask = self.game:askCard(self.owner, self.name, self.condition)
    if #ask.cards == 0 then
        return nil
    end
    return self.game:createVirtualCard(self.name, ask.cards)
end

--- 试一次这份声明：素材够，又有人表态成立，就照声明造一张虚拟牌交出去
--- 有关联来源（`source`）就把整段包成一次「发动」，归因到它名下 —— 装备（`Card:cast`）与技能（`Skill:cast`）共用同一个写法
---@async
---@param ask AskCard
---@return Card? # 产出的牌（不成给空）
function M:tryProduce(ask)
    if not self:canGatherMaterials() then
        return nil
    end
    local source = self.source
    if not source then
        return self:launch(ask)
    end
    ---@type Card?
    local card = nil
    source:cast(function ()
        card = self:launch(ask)
    end)
    return card
end

--- 跑「发动」表态：返回真 ⇒ 按声明收素材；返回牌 ⇒ 拿它们当素材；返回假 / 空 ⇒ 不发动
---@private
---@async
---@param ask AskCard
---@return Card? # 产出的牌（不成给空）
function M:launch(ask)
    local handlers = self:getHandlers('发动')
    if #handlers == 0 then
        return self:produce()
    end
    for _, handler in ipairs(handlers) do
        local answer = handler(ask)
        if answer == true then
            return self:produce()
        end
        if answer and answer ~= false then
            return self:produce(moe.util.toList(answer))
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
---@param source? Card|Skill # 关联的来源
---@param condition? AskCard.Condition # 要什么样的素材（不填 = 不要素材）
---@return ViewAs
function moe.viewAs.create(game, owner, name, source, condition)
    return New 'ViewAs' (game, owner, name, source, condition)
end
