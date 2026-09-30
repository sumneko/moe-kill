--- 要一张打出的牌：与「要一张牌」同形（条件筛候选、答复只有牌），只是答复的牌**当场交出来**
---@class AskPlayCard : AskCard
local M = Class 'AskPlayCard'

Extends('AskPlayCard', 'AskCard')

function M:__init()
    self.kind = 'askPlayCard'
end

--- 交出来的牌进**发起这次结算的临时处理区**（由那次结算收尾时统一送弃牌堆）；没有外层结算就不动，交给内容侧；
--- 虚拟牌没有实体牌、不用交（它不进任何牌区）
---@async
function M:onAnswered()
    local card = self.card
    if card and not card.virtual and self.parent then
        self.game:moveCard(card, self.parent:getTempZone())
    end
end

--- 先让被问者的技能有机会替代这次打出（官方优先级：先武将技能、后装备技能）：返回一张牌即替代成立
--- —— 这张牌就当作答复给出的牌，**不再问应答方**（结果已经定下了）
---@async
function M:beforeAsk()
    local substitute = self.to:fire('打出-技能替代', self)
                    or self.to:fire('打出-装备替代', self)

    if substitute ~= nil then
        self.task:resolve { cards = { substitute } }
    end
end

---@class AskPlayCard.API
moe.askPlayCard = {}

---@param options AskCard.CreateOptions
---@return AskPlayCard
function moe.askPlayCard.create(options)
    return New 'AskPlayCard' (options.game, options.to, options.reason, options.condition)
end
