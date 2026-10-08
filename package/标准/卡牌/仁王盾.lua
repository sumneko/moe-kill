-- 【仁王盾】（标准版）
-- 锁定技，黑色的【杀】对你无效。

Card '仁王盾'
    : extends '防具牌'
    : event('效果-目标-能否生效', function (card, effect)
        if effect.kind ~= 'cardEffect' then
            return
        end
        ---@cast effect CardEffect
        if effect.card.name ~= '杀' then
            return
        end
        if effect.card.color == '黑' then
            -- 空跑一次发动：这次阻止归到盾的名下（回调空着，将来专门的发动记录读它）
            card:cast(function () end)
            return '仁王盾'
        end
    end)
