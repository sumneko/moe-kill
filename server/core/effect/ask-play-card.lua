--- 要一张打出的牌：与「要一张牌」同形（条件筛候选、答复只有牌），只是答复的牌**当场交出来**
--- 给了 `responseTo` = 这是一次**响应**：答复到手就算这次响应成立（发「被响应」两段时机，订阅者要驳回就 `ask:cancel(原因)`）、没答上则记「没有打出」；
--- 算不算「抵消」由订阅者自己按缘由 / 牌名判（青龙偃月刀 / 贯石斧 只认【杀】的响应）
---@class AskPlayCard : AskCard
local M = Class 'AskPlayCard'

Extends('AskPlayCard', 'AskCard')

function M:__init()
    self.kind = 'askPlayCard'
end

---@async
function M:settle()
    local responseTo = self.responseOptions?.responseTo
    if not self:settleAnswer() then
        if responseTo then
            self.task:reject('没有打出')
        end
        return
    end
    -- 响应成立：答复到手就发两段时机（订阅者在回调里 `ask:cancel` 驳回时这次结算当场停住，后面的段不再发）
    if responseTo then
        self.game:fire('效果-被响应', self)
        responseTo.from:fire('效果-来源-被响应', self)
    end
end

--- 交出来的牌进**发起这次结算的临时处理区**（由那次结算收尾时统一送弃牌堆）；没有外层结算就不动，交给内容侧；
--- 虚拟牌自己进不了牌区 —— 收它就是注销它、改收它的实体子牌（见 `Zone:accept`）
--- 顺手记一笔「本阶段打出过这张」的账（牌名叫什么就记什么，虚拟牌记它视为的名字）
---@async
function M:onAnswered()
    local card = self.card
    if not card then
        return
    end
    local phase = self.to:currentPhase()
    if phase then
        phase:addPlayCount(card.name, 1)
    end
    if self.parent then
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
    return New 'AskPlayCard' (options.game, options.to, options.reason, options.condition, options.responseOptions)
end
