require 'core.zone'

--- 按槽位寻址的牌区：每个槽位至多一张牌（槽位名由内容侧在加载期声明，内核只认名字）
---@class SlotZone : Zone
---@field slots string[] # 这个区声明了哪些槽位（按声明顺序）
---@field private slotMap table<string, Card> # 每个槽位里那张牌
---@field private game? Game # 换下来的牌送进哪个局的弃牌堆（建区时给）
local M = Class 'SlotZone'

Extends('SlotZone', 'Zone')

---@param game? Game
---@param slots? string[] # 槽位名（省略 = 没有槽位）
function M:__init(game, slots)
    self.kind    = 'slotZone'
    self.game    = game
    self.slots   = {}
    self.slotMap = {}
    if slots then
        table.move(slots, 1, #slots, 1, self.slots)
    end
end

---@param slot string
function M:checkSlot(slot)
    if not moe.util.arrayHas(self.slots, slot) then
        error('这个牌区没有「{}」这个槽位' % { slot }, 3)
    end
end

--- 这个槽位里现在那张牌
---@param slot string
---@return Card? # 空着 / 记的牌已经不在本区就是「不存在」
function M:getSlot(slot)
    self:checkSlot(slot)
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

--- 把牌放进这个槽位（同槽已有的牌置入弃牌堆）
---@param slot string
---@param card Card
---@return Card
function M:putInto(slot, card)
    self:checkSlot(slot)
    local old = self:getSlot(slot)
    if old and old ~= card then
        local game = self.game
        if not game then
            error('槽位区得记着自己在哪一局，才能把换下来的牌置入弃牌堆', 2)
        end
        self:move(old, game:getZone('弃牌'))
    end
    local from = card:getZone()
    if from then
        from:move(card, self)
    else
        self:put(card)
    end
    self.slotMap[slot] = card
    return card
end

---@class SlotZone.API
moe.slotZone = {}

---@param game? Game
---@param slots? string[] # 槽位名
---@return SlotZone
function moe.slotZone.create(game, slots)
    return New 'SlotZone' (game, slots)
end
