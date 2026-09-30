---@class Zone
---@field kind string
---@field protected cards Card[]
---@field private disabled integer # 被禁用的层数（0 = 启用）
---@field private visible boolean # 是否对所有人可见（默认可见；不可见时只有持有者看得见）
---@field owner? Player # 这个区属于谁（公共区没有归属者）
---@field game Game # 属于哪一局
local M = Class 'Zone'

--- 一次批量搬运里的一条记录
---@class Zone.Move
---@field card Card
---@field from? Zone # 它原来在哪个区（本来就没有归属就是空）
---@field to Zone # 它进了哪个区

---@param game Game # 属于哪一局
function M:__init(game)
    self.kind     = 'zone'
    self.cards    = {}
    self.disabled = 0
    self.visible  = true
    self.game     = game
end

--- 牌进来了：本区被禁用就先压它一层，再跑它定义上的「进入区域」钩子
---@param card Card
function M:notifyEnter(card)
    if self.disabled > 0 then
        card:disablePassive()
    end
    card:fireHandlers('进入区域', card, self)
end

--- 牌离开了：先跑它定义上的「离开区域」钩子，再松开本区压的那一层（发的时候牌已经不在本区里）
---@param card Card
function M:notifyLeave(card)
    card:fireHandlers('离开区域', card, self)
    if self.disabled > 0 then
        card:enablePassive()
    end
end

--- 把这张牌从本区的列表里摘下来（不发事件、不动它的归属 —— 搬牌的人自己管）
---@protected
---@param card Card
function M:detach(card)
    local index = self:indexOf(card)
    if index then
        table.remove(self.cards, index)
    end
end

--- 静默把这批牌收进本区（只摘、置、绑，不发任何事件）
---@protected
---@param cards Card[]
---@return Zone.Move[] # 这次搬动的记录（发事件时用）
function M:takeIn(cards)
    ---@type Zone.Move[]
    local moves = {}
    for i, card in ipairs(cards) do
        local from = card:getZone()
        if from then
            from:detach(card)
        end
        card:unbindZone()
        self.cards[#self.cards + 1] = card
        card:bindZone(self)
        moves[i] = {
            card = card,
            from = from,
            to   = self,
        }
    end
    return moves
end

--- 一起发这批搬动的事件（按每条记录自己的源区 / 目标区发）：先所有「离开区域」、再所有「进入区域」
---@protected
---@param moves Zone.Move[]
function M:notifyMoved(moves)
    for _, move in ipairs(moves) do
        local from = move.from
        if from then
            from:notifyLeave(move.card)
        end
    end
    for _, move in ipairs(moves) do
        move.to:notifyEnter(move.card)
    end
end

--- 收下这批牌（它们原来在哪个区都行：检查过了才动，最后一起发「离开区域」/「进入区域」；收的是每张牌的实体牌 —— 虚拟牌进不了牌区，收它就等于收它的素材）
---@param cards Card|Card[] # 要收的牌（单张或一批）
---@return boolean # 收下了没有
---@return string? # 没收下的原因
function M:accept(cards)
    ---@type Card[]
    local list = {}
    for _, card in ipairs(moe.util.toList(cards)) do
        local physical = card.physical
        table.move(physical, 1, #physical, #list + 1, list)
    end
    self:notifyMoved(self:takeIn(list))
    return true
end

--- 把这张牌从本区拿出来（摘掉、解绑、发「离开区域」；内核自己用：清空、取顶）
---@protected
---@param card Card
---@return Card? # 本区没这张牌就是空
function M:remove(card)
    local index = self:indexOf(card)
    if not index then
        return nil
    end
    table.remove(self.cards, index)
    card:unbindZone()
    self:notifyLeave(card)
    return card
end

--- 这张牌在第几位
---@private
---@param card Card
---@return integer?
function M:indexOf(card)
    for i = 1, #self.cards do
        if self.cards[i] == card then
            return i
        end
    end
    return nil
end

--- 看第几张（不取出来）
---@param index integer
---@return Card? # 这个序号没牌就是空
function M:peek(index)
    return self.cards[index]
end

---@return integer # 里面几张牌
function M:count()
    return #self.cards
end

---@return Card[] # 快照（改它不影响牌区）
function M:list()
    local snapshot = {}
    return table.move(self.cards, 1, #self.cards, 1, snapshot)
end

--- 清空整个牌区（每张牌都发一次「离开区域」）
---@return integer # 清掉几张
function M:clear()
    local cards = self:list()
    for i = 1, #cards do
        self:remove(cards[i])
    end
    return #cards
end

--- 禁用这个牌区：区里的牌不能用、被动被压制（可以叠多层，每个禁用者各占一层）
---@return function # 撤销这一次禁用
function M:disable()
    self.disabled = self.disabled + 1
    if self.disabled == 1 then
        for _, card in ipairs(self:list()) do
            card:disablePassive()
        end
    end
    local undone = false
    return function ()
        if undone then
            return
        end
        undone = true
        self.disabled = self.disabled - 1
        if self.disabled == 0 then
            for _, card in ipairs(self:list()) do
                card:enablePassive()
            end
        end
    end
end

---@return boolean # 这个区现在是不是启用（没被禁用）
function M:isEnabled()
    return self.disabled == 0
end

--- 记下这个区属于谁（玩家建区时用）
---@param player Player
function M:bindOwner(player)
    self.owner = player
end

--- 设置可见性
---@param value boolean
function M:setVisible(value)
    self.visible = value
end

--- 这个区对某人是否可见
---@param viewer Player
---@return boolean
function M:isVisibleTo(viewer)
    return self.visible or self.owner == viewer
end

---@class Zone.API
moe.zone = {}

--- 建一个牌区
---@param game Game # 属于哪一局
---@return Zone
function moe.zone.create(game)
    return New 'Zone' (game)
end
