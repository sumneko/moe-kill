require 'core.effect.ask-card'

--- 要一张打出的牌：与「要一张牌」同形（条件筛候选、答复只有牌），只是答复的牌**当场交出来**
---@class AskPlayCard : AskCard
local M = Class 'AskPlayCard'

Extends('AskPlayCard', 'AskCard')

function M:__init()
    self.kind = 'askPlayCard'
end

--- 交出来的牌进**发起这次结算的临时处理区**（收尾时由内容侧统一送弃牌堆）；没有父结算就不动，交给内容侧
---@async
function M:onAnswered()
    local card  = self.card
    local owner = self.parent
    if card and owner then
        self.game:moveCard(card, owner:getTempZone())
    end
end

---@class AskPlayCard.API
moe.askPlayCard = {}

---@param options AskCard.CreateOptions
---@return AskPlayCard
function moe.askPlayCard.create(options)
    return New 'AskPlayCard' (options.game, options.to, options.reason, options.condition)
end
