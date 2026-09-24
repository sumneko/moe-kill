-- 【无懈可击】（标准版）
-- 使用时机：一张锦囊牌对一个目标生效前。
-- 使用目标：一张对一个目标生效前的锦囊牌。
-- 作用效果：抵消此锦囊牌。
-- 它不能主动使用（没有「对角色使用」这一支），只由「生效前」的询问发起

--- 声明「对卡牌生效」= 它能被「对一张牌使用」（效果由下面那个窗口落地：内核的取消只能由被取消的那个效果自己的执行体发起）
Card '无懈可击'
    : extends '锦囊牌'
    : on('对卡牌生效', function () end)

--- 这次使用用出去的那张牌生效了吗（它那次「对牌生效」被取消 / 不成立，就是没生效）
---@param use UseCardToCard
---@return boolean
local function tookEffect(use)
    for _, child in ipairs(use.childs) do
        if child.kind == 'cardEffectToCard' then
            return child.err == nil
        end
    end
    return false
end

--- 问一圈：有没有人对这张牌使用【无懈可击】
---@param card Card # 要抵消的那张牌
---@return boolean # 这张牌有没有被抵消
local function nullified(card)
    for player in game.desk:actionOrder(game.desk.alivePlayers) do
        ---@type AskUseCardToCard.Condition
        local condition = { name = '无懈可击', target = card }
        local used = game:askUseCardToCard(player, card.name, condition).card
        if used then
            -- 用出去的那张无懈自己也走一遍「生效前」：它没生效，就说明它没抵掉 card
            return tookEffect(game:useCardToCard(player, used, card))
        end
    end
    return false
end

--- 一次「生效前」：问一圈要不要抵消，要就取消这一次生效
---@param effect CardEffect|CardEffectToCard
local function nullify(effect)
    if effect.card:isKind('锦囊') and nullified(effect.card) then
        effect:remove()
    end
end

--- 两种「生效」都在这里问：锦囊对某个角色的生效、以及无懈对一张牌的生效（= 抵消另一张【无懈可击】产生的效果）
game:on('效果-即将生效', function (effect)
    if effect.kind == 'cardEffect' or effect.kind == 'cardEffectToCard' then
        ---@cast effect CardEffect|CardEffectToCard
        nullify(effect)
    end
end)
