-- 【无懈可击】（标准版）
-- 使用时机：一张锦囊牌对一个目标生效前。
-- 使用目标：一张对一个目标生效前的锦囊牌。
-- 作用效果：抵消此锦囊牌。
-- 它不能主动使用（没有「对角色使用」这一支），只由「生效前」的询问发起

--- 只有锦囊牌能被抵消
---@param card Card
---@return boolean
local function canNullify(card)
    return card:isKind('锦囊')
end

--- 声明「获取卡牌目标」= 它能被「对一张牌使用」（真抵消由下面那个窗口回报给内核）
Card '无懈可击'
    : extends '锦囊牌'
    : on('获取卡牌目标', function (target)
        local card = target.target
        if card and canNullify(card) then
            return card
        end
    end)

--- 问一圈：有没有人对这张牌使用【无懈可击】
--- 一圈里每人只有一次机会；只有「这张牌被抵消」才终止这一圈 ⇒ 谁的无懈自己又被抵掉了，就接着问下一个人
---@param card Card # 要抵消的那张牌
---@return boolean # 这张牌有没有被抵消
local function nullified(card)
    for player in game.desk:actionOrder(game.desk.alivePlayers) do
        ---@type AskUseCardToCard.Condition
        local condition = { name = '无懈可击', target = card }
        local used = game:askUseCardToCard(player, card.name, condition).card
        if used then
            local effect = game:useCardToCard(player, used, card).cardEffectToCard
            -- 刚用出去的那张无懈自己也会被问一遍「能否生效」：它没生效，就说明它没抵掉 card
            if effect?.success then
                return true
            end
        end
    end
    return false
end

--- 一次「生效前」：问一圈要不要抵消
---@param effect CardEffect|CardEffectToCard
---@return string? # 要抵消就给原因（这次生效被阻止）
local function nullify(effect)
    if canNullify(effect.card) and nullified(effect.card) then
        return '无懈可击'
    end
end

--- 两种「生效」都在这里问：锦囊对某个角色的生效、以及无懈对一张牌的生效（= 抵消另一张【无懈可击】产生的效果）
game:on('效果-能否生效', function (effect)
    if effect.kind == 'cardEffect'
    or effect.kind == 'cardEffectToCard' then
        ---@cast effect CardEffect|CardEffectToCard
        return nullify(effect)
    end
end)
