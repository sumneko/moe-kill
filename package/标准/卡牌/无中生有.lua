-- 【无中生有】（标准版）
-- 出牌阶段，对自己使用。摸两张牌。

Card '无中生有'
    : extends '锦囊牌'
    : on('获取目标', function (plan)
        return { plan.user }
    end)
    : on('生效', function (cardEffect)
        game:draw(cardEffect.target, 2)
    end)
