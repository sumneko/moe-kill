---@class Zone
---@field kind string
---@field protected cards Card[]
---@field private enabled boolean
---@field private visible boolean # 是否对所有人可见（默认可见；不可见时只有持有者看得见）
---@field owner? Player # 这个区属于谁（公共区没有归属者）
---@field game? Game # 属于哪一局（公共区由局给；玩家建区时顺归属者拿；测试自己造的可以没有）
local M = Class 'Zone'

---@param count integer
---@param position? integer
---@return integer
local function resolvePosition(count, position)
    if position == nil then
        return count + 1
    end
    assert(math.type(position) == 'integer', '位置必须是整数')
    local index = position
    if index < 0 then
        index = count + index + 2
    end
    if index < 1 or index > count + 1 then
        error('位置 {} 超出可插入范围（共 {} 个位置：1..{} 或 -1..-{}）' % {
            position,
            count + 1,
            count + 1,
            count + 1,
        }, 3)
    end
    return index
end

---@param game? Game # 属于哪一局
function M:__init(game)
    self.kind    = 'zone'
    self.cards   = {}
    self.enabled = true
    self.visible = true
    self.game    = game
end

--- 没启用这个牌区就报错
---@param action string # 要做什么（拼进报错里）
function M:checkEnabled(action)
    if not self.enabled then
        error('牌区已被禁用，无法{}' % { action }, 3)
    end
end

--- 序号超出范围就报错
---@param index integer
function M:checkIndex(index)
    assert(math.type(index) == 'integer', '牌的序号必须是整数')
    if not self.cards[index] then
        error('牌区中没有第 {} 张牌（当前 {} 张）' % { index, #self.cards }, 3)
    end
end

--- 这张牌在这个区里的名字（只有槽位区有）
---@protected
---@param card Card
---@return string? # 槽位名（不是槽位区就是空）
function M:slotOf(card)
    return nil
end

--- 牌进来了：把它定义上的「进入区域」钩子各跑一次（没局 / 没定义就什么都不做）
---@param card Card
function M:notifyEnter(card)
    local game  = self.game
    local label = card:getLabel()
    if not game or type(label) ~= 'string' or label == '' then
        return
    end
    local def = game:getCard(label)
    if not def then
        return
    end
    local slot = self:slotOf(card)
    for _, handler in ipairs(def:getHandlers('进入区域')) do
        handler(card, self, slot)
    end
end

--- 放一张牌进来（已经在别的牌区里的牌要用 `move`）
---@param card Card
---@return Card
function M:put(card)
    self:checkEnabled('放入牌')
    if card:getZone() then
        error('这张牌已经在某个牌区里了，要换区请用 move', 2)
    end
    self.cards[#self.cards + 1] = card
    card:bindZone(self)
    self:notifyEnter(card)
    return card
end

--- 取出第几张（取出来后不在任何牌区里）
---@param index integer
---@return Card
function M:take(index)
    self:checkEnabled('取牌')
    self:checkIndex(index)
    local card = table.remove(self.cards, index)
    card:bindZone(nil)
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

--- 把一张牌挪到另一个牌区（可以先直接给目标区对象）
---@param card Card
---@param to Zone
---@param position? integer
---@return Card
function M:move(card, to, position)
    self:checkEnabled('移出牌')
    to:checkEnabled('移入牌')
    local index = self:indexOf(card)
    if not index then
        error('源牌区中没有这张牌', 3)
    end
    local count = #to.cards
    if to == self then
        count = count - 1
    end
    local target = resolvePosition(count, position)
    table.remove(self.cards, index)
    table.insert(to.cards, target, card)
    card:bindZone(to)
    to:notifyEnter(card)
    return card
end

--- 看第几张（不取出来）
---@param index integer
---@return Card
function M:peek(index)
    self:checkIndex(index)
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

--- 清空整个牌区（返回被清掉几张）
---@return integer
function M:clear()
    self:checkEnabled('清空牌区')
    local count = #self.cards
    for i = 1, count do
        self.cards[i]:bindZone(nil)
    end
    self.cards = {}
    return count
end

--- 禁用这个牌区（不能放进 / 取出 / 清空；重复禁用返回 false）
---@return boolean
function M:disable()
    if not self.enabled then
        return false
    end
    self.enabled = false
    return true
end

--- 重新启用这个牌区（重复启用返回 false）
---@return boolean
function M:enable()
    if self.enabled then
        return false
    end
    self.enabled = true
    return true
end

---@return boolean # 现在能不能放进 / 取出
function M:isEnabled()
    return self.enabled
end

--- 记下这个区属于谁（只有玩家建时用；顺带记下它在哪一局）
---@param player Player
function M:bindOwner(player)
    self.owner = player
    self.game  = player.game
end

--- 设置可见性
---@param value boolean
function M:setVisible(value)
    self.visible = value and true or false
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
---@param game? Game # 属于哪一局（有局才会发「进入区域」）
---@return Zone
function moe.zone.create(game)
    return New 'Zone' (game)
end
