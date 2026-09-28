-- 【闪电】（标准版）
-- 出牌阶段，对自己使用。将此牌放置于自己的判定区里：若判定结果为黑桃 2~9，则受到 3 点雷电伤害并弃置此牌；
-- 否则将此牌移动到下一位角色的判定区里。

---@type integer # 中招区间：黑桃 2~9
local HIT_MIN = 2
local HIT_MAX = 9

-- 判中了吗（黑桃 2~9）
---@param judge Judge?
---@return boolean
local function isHit(judge)
    local card = judge?.card
    return card ~= nil
       and card.suit == '黑桃'
       and card.point ~= nil
       and card.point >= HIT_MIN
       and card.point <= HIT_MAX
end

-- 他的判定区里有没有同名牌
---@param player Player
---@param name string
---@return boolean
local function hasSameName(player, name)
    for _, card in ipairs(player:getZone('判定'):list()) do
        if card.name == name then
            return true
        end
    end
    return false
end

-- 往下家挪：从下家起找第一个合法目标（存活、判定区里没有闪电）并把自己移过去；找不到就送弃牌堆
---@param cardEffect CardEffect
local function passToNext(cardEffect)
    local card   = cardEffect.card
    local player = cardEffect.target
    for current in game.desk:actionOrder(nil, player) do
        if current ~= player and not hasSameName(current, card.name) then
            game:moveCard(card, current:getZone('判定'))
            return
        end
    end
    game:moveCard(card, '弃牌')
end

Card '闪电'
    : extends '延时锦囊牌'
    : on('获取目标', function (plan)
        return { plan.user }
    end)
    : on('生效', function (cardEffect)
        local judge = game:judge(cardEffect.target, cardEffect.card.name)
        if isHit(judge) then
            game:damage(nil, cardEffect.target, 3)
        else
            passToNext(cardEffect)
        end
    end)
