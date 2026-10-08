-- 【无中生有】（标准版）
-- 出牌阶段，对自己使用。摸两张牌。

Card '无中生有'
    : extends '锦囊牌'
    : targets {
        filter = function (player, plan)
            return player == plan.user
        end,
    }
    : on('生效', function (cardEffect)
        cardEffect.target:draw(2)
    end)
