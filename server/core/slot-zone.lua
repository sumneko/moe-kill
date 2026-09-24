require 'core.zone'

--- 按槽位寻址的牌区：每个槽位至多一张牌
---@class SlotZone : Zone
---@field slots string[] # 这个区有哪些槽位（按声明顺序）
---@field private slotMap table<string, Card> # 每个槽位里那张牌
---@field private game? Game # 换下来的牌送进哪个局的弃牌堆
local M = Class 'SlotZone'

Extends('SlotZone', 'Zone')

---@param game? Game # 换下来的牌送进哪个局的弃牌堆（要替换槽里的牌就得给）
function M:__init(game)
    self.kind    = 'slotZone'
    self.game    = game
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

--- 要求这个槽位是声明过的
---@param slot string
function M:checkSlot(slot)
    if not moe.util.arrayHas(self.slots, slot) then
        error('这个牌区没有「{}」这个槽位' % { slot }, 3)
    end
end

--- 这张牌在哪个槽位里
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
    self.slotMap[slot] = card
    if from then
        from:move(card, self)
    else
        self:put(card)
    end
    return card
end

---@class SlotZone.API
moe.slotZone = {}

--- 建一个槽位区（槽位名由内容侧用 `setSlots` 设）
---@param game? Game # 换下来的牌送进哪个局的弃牌堆（要替换槽里的牌就得给）
---@return SlotZone
function moe.slotZone.create(game)
    return New 'SlotZone' (game)
end
