-- 【方天画戟】（标准版）
-- 当你使用【杀】时，若此【杀】是你最后的手牌，你可以额外指定至多两个目标。
-- 攻击范围 4

Card '方天画戟'
    : extends '武器牌'
    : value('攻击范围', 4)
    : event('卡牌-来源-使用选项', function (card, check)
        if check.card.name ~= '杀' then
            return
        end
        local zone  = assert(card:getZone())
        local owner = assert(zone.owner)
        local hand = owner:getZone('手牌')
        if hand:count() == 1 and hand:list()[1] == check.card then
            return { extraTargets = 2 }
        end
    end)
