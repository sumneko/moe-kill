---@class Zone
---@field kind string
---@field protected cards Card[] # 从区顶到区底（有序区靠这个顺序说话：1 = 顶）
---@field private disabled integer # 被禁用的层数（0 = 启用）
---@field private visible Visibility # 可见性：`true` = 所有人、`false` = 无人、一批角色 = 只有他们（默认 `true`）
---@field owner? Player # 这个区属于谁（公共区没有归属者）
---@field name? string # 这个区叫什么（登记它的那一方写：玩家建区 / 局上建区；临时区这种自留地没有名字）
---@field game Game # 属于哪一局
local M = Class 'Zone'

--- 一次批量搬运里的一条记录
---@class Zone.Move
---@field card Card
---@field from? Zone # 它原来在哪个区（本来就没有归属就是空）
---@field to Zone # 它进了哪个区
---@field visible? Visibility # 这次搬动对谁可见（不给 = 读的人按「源区可见 or 目标区可见」算）

---@param game Game # 属于哪一局
function M:__init(game)
    self.kind     = 'zone'
    self.cards    = {}
    self.disabled = 0
    self.visible  = true
    self.game     = game
end

--- 牌进来了：本区被禁用就先压它一层，再跑它定义上的「卡牌-进入区域」钩子（有主人的区还给主人发一份）
---@param card Card
---@param visible? Visibility # 这次搬动对谁可见
function M:notifyEnter(card, visible)
    if self.disabled > 0 then
        card:disablePassive()
    end
    card:fireHandlers('卡牌-进入区域', card, self, visible)
    self.owner?:fire('卡牌-进入区域', card, self, visible)
end

--- 牌离开了：先跑它定义上的「卡牌-离开区域」钩子（有主人的区也给主人发一份），再松开本区压的那一层（发的时候牌已经不在本区里）
---@param card Card
---@param visible? Visibility # 这次搬动对谁可见
function M:notifyLeave(card, visible)
    card:fireHandlers('卡牌-离开区域', card, self, visible)
    self.owner?:fire('卡牌-离开区域', card, self, visible)
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

--- 把一批牌化成实体牌（虚拟牌进不了牌区：收它就是收它的素材）
---@protected
---@param cards Card|Card[]
---@return Card[]
function M:toPhysical(cards)
    ---@type Card[]
    local list = {}
    for _, card in ipairs(moe.util.toList(cards)) do
        moe.util.arrayMerge(list, card.physical)
    end
    return list
end

--- 静默把这批牌收进本区（只摘、置、绑，不发任何事件）
---@protected
---@param cards Card[]
---@param visible? Visibility # 这次搬动对谁可见
---@param at? integer # 插到第几位（省略 = 追加到末尾）
---@return Zone.Move[] # 这次搬动的记录（发事件时用）
function M:takeIn(cards, visible, at)
    ---@type Zone.Move[]
    local moves = {}
    for i, card in ipairs(cards) do
        local from = card:getZone()
        if from then
            from:detach(card)
        end
        -- 一次搬动就一次归属变更：中间不留「无主」态（那会被当成一次「离开」）
        table.insert(self.cards, at and (at + i - 1) or (#self.cards + 1), card)
        card:bindZone(self)
        moves[i] = {
            card    = card,
            from    = from,
            to      = self,
            visible = visible,
        }
    end
    return moves
end

--- 一起发这批搬动的事件（按每条记录自己的源区 / 目标区发）：先所有「卡牌-离开区域」、再所有「卡牌-进入区域」
---@protected
---@param moves Zone.Move[]
function M:notifyMoved(moves)
    for _, move in ipairs(moves) do
        local from = move.from
        if from then
            from:notifyLeave(move.card, move.visible)
        end
    end
    for _, move in ipairs(moves) do
        move.to:notifyEnter(move.card, move.visible)
    end
end

--- 收下这批牌（它们原来在哪个区都行：检查过了才动，最后一起发「卡牌-离开区域」/「卡牌-进入区域」；收的是每张牌的实体牌 —— 虚拟牌进不了牌区，收它就等于收它的素材）
---@param cards Card|Card[] # 要收的牌（单张或一批）
---@param visible? Visibility # 这次搬动对谁可见（不给 = 源区可见 or 目标区可见，由读的人算）
---@return boolean # 收下了没有
---@return string? # 没收下的原因
function M:accept(cards, visible)
    self:notifyMoved(self:takeIn(self:toPhysical(cards), visible))
    return true
end

--- 把这张牌从本区拿出来（摘掉、解绑、发「卡牌-离开区域」；内核自己用：清空、取顶）
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
    return moe.util.copy(self.cards)
end

--- 清空整个牌区（每张牌都发一次「卡牌-离开区域」）
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

--- 记下这个区叫什么（登记它的那一方用）
---@param name string
function M:bindName(name)
    self.name = name
end

--- 设置可见性：`true` = 所有人、`false` = 无人、给一名或一批角色 = 只有他们（重复调以后写的为准）
---@param value Visibility
function M:setVisible(value)
    self.visible = moe.visibility.normalize(value)
end

--- 这个区对某人是否可见
---@param viewer Player
---@return boolean
function M:isVisibleTo(viewer)
    return moe.visibility.isVisibleTo(self.visible, viewer)
end

---@class Zone.API
moe.zone = {}

--- 建一个牌区
---@param game Game # 属于哪一局
---@return Zone
function moe.zone.create(game)
    return New 'Zone' (game)
end
