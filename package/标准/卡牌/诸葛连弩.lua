-- 【诸葛连弩】（标准版）
-- 出牌阶段，你可以使用任意数量的【杀】。
-- 攻击范围 1

Card '诸葛连弩'
    : extends '武器牌'
    : value('攻击范围', 1)
    : on('被动', function (card, zone)
        local owner = assert(zone.owner)
        return game:on('卡牌-次数修正', function (check)
            if check.card.name ~= '杀' or check.user ~= owner then
                return
            end
            return 1000
        end)
    end)
