--- 要一张打出的牌来抵消一次生效：「打出 = 抵消名义成立」，答复一落定就发两段时机
--- （全局 `'效果-被抵消'` → 来源 `responseOptions.responseTo.from` 那份 `'效果-来源-被抵消'`）；订阅者要驳回就在回调里 `ask:cancel(原因)`（不会返回）；
--- 「抵消最终成没成立」读 `.success`（没打出 / 被驳回都为假）
---@class AskOffsetCard : AskPlayCard
local M = Class 'AskOffsetCard'

Extends('AskOffsetCard', 'AskPlayCard')

function M:__init()
    self.kind = 'askOffsetCard'
end

---@async
function M:settle()
    self.options = self:collectOptions()

    if not self:collectAnswer() then
        self.task:reject('没有打出')
        return
    end

    self:onAnswered()
    self.game:fire('卡牌-答复', self)
    self.game:fire('卡牌-答复后', self)

    -- 要驳回的订阅者会在回调里 ask:cancel（不会返回）；没人驳回 = 抵消成立
    self.game:fire('效果-被抵消', self)
    local source = self.responseOptions?.responseTo?.from
    source?:fire('效果-来源-被抵消', self)
end

---@class AskOffsetCard.API
moe.askOffsetCard = {}

---@param options AskCard.CreateOptions
---@return AskOffsetCard
function moe.askOffsetCard.create(options)
    return New 'AskOffsetCard' (options.game, options.to, options.reason, options.condition, options.responseOptions)
end
