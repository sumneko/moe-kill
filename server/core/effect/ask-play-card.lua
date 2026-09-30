--- 要一张打出的牌：与「要一张牌」同形（条件筛候选、答复只有牌），只是答复的牌**当场交出来**
---@class AskPlayCard : AskCard
local M = Class 'AskPlayCard'

Extends('AskPlayCard', 'AskCard')

function M:__init()
    self.kind = 'askPlayCard'
end

--- 交出来的牌进**发起这次结算的临时处理区**（由那次结算收尾时统一送弃牌堆）；没有外层结算就不动，交给内容侧；
--- 虚拟牌自己进不了牌区 —— 收它就是注销它、改收它的实体子牌（见 `Zone:accept`）
---@async
function M:onAnswered()
    local card = self.card
    if card and self.parent then
        self.game:moveCard(card, self.parent:getTempZone())
    end
end

--- 依次试被问者身上的「视为」声明（按声明顺序）：牌名对上这次要的牌才试，谁先产出一张牌就当答复落定
---@async
function M:beforeAsk()
    local names = self.condition?.names
    for _, viewAs in ipairs(self.to:getViewAsList()) do
        if not names or moe.util.arrayHas(names, viewAs.name) then
            local card = viewAs:tryProduce(self)
            if card ~= nil then
                self.task:resolve { cards = { card } }
                return
            end
        end
    end
end

---@class AskPlayCard.API
moe.askPlayCard = {}

---@param options AskCard.CreateOptions
---@return AskPlayCard
function moe.askPlayCard.create(options)
    return New 'AskPlayCard' (options.game, options.to, options.reason, options.condition)
end
