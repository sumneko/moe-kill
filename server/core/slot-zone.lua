--- 按槽位寻址的牌区：每个槽位至多一张牌，进本区的牌必须先在某个槽位里
---@class SlotZone : Zone
---@field slots string[] # 这个区有哪些槽位（按声明顺序）
---@field private slotMap table<string, Card> # 每个槽位里那张牌
local M = Class 'SlotZone'

Extends('SlotZone', 'Zone')

---@param game Game # 换下来的牌送进哪个局的弃牌堆
function M:__init(game)
    self.kind    = 'slotZone'
    self.slots   = {}
    self.slotMap = {}
end

--- 设置这个区有哪些槽位（重复设以后写的为准，槽位里的牌跟着清掉）
---@param slots string[] # 槽位名（按顺序）
---@return SlotZone
function M:setSlots(slots)
    if type(slots) ~= 'table' then
        error('槽位名表必须是一张字符串列表', 2)
    end
    ---@type string[]
    local copied = {}
    for i, name in ipairs(slots) do
        if type(name) ~= 'string' or name == '' then
            error('槽位名必须是非空字符串', 2)
        end
        copied[i] = name
    end
    self.slots   = copied
    self.slotMap = {}
    return self
end

--- 这个区有没有这个槽位
---@param slot string
---@return boolean
function M:checkSlot(slot)
    return moe.util.arrayHas(self.slots, slot)
end

--- 这张牌在哪个槽位里（只有槽位区有；内核发「进入区域」钩子时用）
---@param card Card
---@return string?
function M:slotOf(card)
    for slot, held in pairs(self.slotMap) do
        if held == card then
            return slot
        end
    end
    return nil
end

--- 这个槽位里现在那张牌
---@param slot string
---@return Card? # 空着 / 没这个槽位 / 记的牌已经不在本区都是「不存在」
function M:getSlot(slot)
    if not self:checkSlot(slot) then
        return nil
    end
    local card = self.slotMap[slot]
    if not card then
        return nil
    end
    if card:getZone() ~= self then
        self.slotMap[slot] = nil
        return nil
    end
    return card
end

--- 进本区的牌必须先在某个槽位里（`slotMap` 里没有就进不去）
---@param card Card
---@return boolean
function M:canEnter(card)
    return self:slotOf(card) ~= nil
end

--- 收下这批牌（槽位区：必须给槽位名、一次只能一张；同槽已有的牌会一起送进弃牌堆）
---@param cards Card|Card[]
---@param slot? string
---@return boolean # 收下了没有
---@return string? # 没收下的原因
function M:accept(cards, slot)
    local list = moe.util.toList(cards)
    if not slot then
        return false, '槽位区必须指名收进哪个槽位'
    end
    if #list > 1 then
        return false, '一个槽位只能收一张牌'
    end
    if not self:checkSlot(slot) then
        return false, '这个牌区没有「{}」这个槽位' % { slot }
    end
    local old     = self:getSlot(slot)
    local discard = self.game:getZone('弃牌')
    ---@type Zone.Move[]
    local moves = {}
    if old and old ~= list[1] then
        -- 旧牌先静默挪进弃牌堆（这时它的槽位还查得到；它的事件排在本次搬动的最前面）
        for _, move in ipairs(discard:takeIn({ old })) do
            moves[#moves + 1] = move
        end
    end
    self.slotMap[slot] = list[1]
    for _, move in ipairs(self:takeIn(list, { slot })) do
        moves[#moves + 1] = move
    end
    self:notifyMoved(moves)
    return true
end

---@class SlotZone.API
moe.slotZone = {}

--- 建一个槽位区（槽位名由内容侧用 `setSlots` 设）
---@param game Game # 换下来的牌送进哪个局的弃牌堆
---@return SlotZone
function moe.slotZone.create(game)
    return New 'SlotZone' (game)
end
