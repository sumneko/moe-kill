---@class Zone
---@field kind string
---@field protected cards Card[]
---@field private enabled boolean
---@field private visible boolean # 是否对所有人可见（默认可见；不可见时只有持有者看得见）
---@field private owner? Player # 这个区属于谁（玩家建区时记；公共区没有）
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

function M:__init()
    self.kind    = 'zone'
    self.cards   = {}
    self.enabled = true
    self.visible = true
end

function M:checkEnabled(action)
    if not self.enabled then
        error('牌区已被禁用，无法{}' % { action }, 3)
    end
end

---@param index integer
function M:checkIndex(index)
    assert(math.type(index) == 'integer', '牌的序号必须是整数')
    if not self.cards[index] then
        error('牌区中没有第 {} 张牌（当前 {} 张）' % { index, #self.cards }, 3)
    end
end

---@param card Card
---@return Card
function M:put(card)
    self:checkEnabled('放入牌')
    if card:getZone() then
        error('这张牌已经在某个牌区里了，要换区请用 move', 2)
    end
    self.cards[#self.cards + 1] = card
    card:bindZone(self)
    return card
end

---@param index integer
---@return Card
function M:take(index)
    self:checkEnabled('取牌')
    self:checkIndex(index)
    local card = table.remove(self.cards, index)
    card:bindZone(nil)
    return card
end

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
    return card
end

---@param index integer
---@return Card
function M:peek(index)
    self:checkIndex(index)
    return self.cards[index]
end

---@return integer
function M:count()
    return #self.cards
end

---@return Card[]
function M:list()
    local snapshot = {}
    return table.move(self.cards, 1, #self.cards, 1, snapshot)
end

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

---@return boolean
function M:disable()
    if not self.enabled then
        return false
    end
    self.enabled = false
    return true
end

---@return boolean
function M:enable()
    if self.enabled then
        return false
    end
    self.enabled = true
    return true
end

---@return boolean
function M:isEnabled()
    return self.enabled
end

--- 记下这个区属于谁（只有玩家建区时用）
---@param player Player
function M:bindOwner(player)
    self.owner = player
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

---@return Card
function M:takeTop()
    error('该牌区不具备有序能力，无法取顶', 2)
end

---@param count integer
---@return Card[]
function M:draw(count)
    error('该牌区不具备有序能力，无法从顶取牌', 2)
end

---@param random? Random
---@return Zone
function M:shuffle(random)
    error('该牌区不具备有序能力，无法洗牌', 2)
end

---@class Zone.API
moe.zone = {}

---@return Zone
function moe.zone.create()
    return New 'Zone' ()
end
