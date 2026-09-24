require 'core.effect.ask-card'

--- 要什么样的牌：`AskCard.Condition` 那些条件 + 一条 `target`（要对哪张牌使用）
---@class AskUseCardToCard.Condition : AskCard.Condition
---@field target Card # 要使用在哪张牌上（由发起方给定）

--- 一个合法选项：一张能对目标牌使用的牌
---@class AskUseCardToCard.Option : AskCard.Option
---@field target Card # 它要用在哪张牌上（= 条件里给的那张）

---@class AskUseCardToCard.CreateOptions
---@field game Game
---@field to Player # 被问者
---@field reason? string # 这次为什么问（内容由发起方定；原样带到应答方）
---@field condition AskUseCardToCard.Condition # 要什么样的牌（`target` 必给）

--- 要一次「对一张牌的使用」：候选逐张跑 `canUseToCard`（用不了的牌不进选项），答复只要给牌
---@class AskUseCardToCard : AskCard
---@field condition AskUseCardToCard.Condition # 要什么样的牌（比基类多一条 target）
---@field options? AskUseCardToCard.Option[] # 按条件算出的合法选项（询问交给应答方之前就摆好）
local M = Class 'AskUseCardToCard'

Extends('AskUseCardToCard', 'AskCard')

function M:__init()
    self.kind = 'askUseCardToCard'
end

--- 能把这张牌用在目标牌上才进选项
---@param card Card
---@return AskUseCardToCard.Option?
function M:makeOption(card)
    local ok = self.game:canUseToCard(self.to, card, self.condition.target)
    if not ok then
        return nil
    end
    return { card = card, target = self.condition.target }
end

---@class AskUseCardToCard.API
moe.askUseCardToCard = {}

---@param options AskUseCardToCard.CreateOptions
---@return AskUseCardToCard
function moe.askUseCardToCard.create(options)
    return New 'AskUseCardToCard' (options.game, options.to, options.reason, options.condition)
end
