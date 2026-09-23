-- 【决斗】（标准版）
-- 出牌阶段，对一名其他角色使用。由目标角色开始，其与你轮流打出一张【杀】，首先不出【杀】的一方受到另一方造成的 1 点伤害。

Card '决斗'
    : extends '锦囊牌'
    : on('获取目标', function (target)
        return table.filter(game.desk.alivePlayers, function (player)
            return player ~= target.user
        end)
    end)
    : on('生效', function (cardEffect)
        local attacker = cardEffect.user
        local defender = cardEffect.target
        while true do
            if not game:askCard(defender, '打出', { name = '杀' }).card then
                game:damage(attacker, defender, 1)
                return
            end
            attacker, defender = defender, attacker
        end
    end)
