-- 【仁王盾】（标准版）
-- 锁定技，黑色的【杀】对你无效。

Card '仁王盾'
    : extends '防具牌'
    : on('被动', function (card, zone)
        local owner = zone.owner
        if not owner then
            return
        end
        return owner:on('效果-目标-能否生效', function (effect)
            if effect.kind ~= 'cardEffect' then
                return
            end
            ---@cast effect CardEffect
            if effect.card.name ~= '杀' then
                return
            end
            if effect.card.suit == '黑桃' or effect.card.suit == '梅花' then
                return '仁王盾'
            end
        end)
    end)
