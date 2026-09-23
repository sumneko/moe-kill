-- 【南蛮入侵】（标准版）
-- 出牌阶段，对所有其他角色使用。每名目标角色需打出一张【杀】，否则受到 1 点伤害。

Card '南蛮入侵'
    : extends '锦囊牌'
    : on('获取目标', function (target)
        return table.filter(game.desk.alivePlayers, function (player)
            return player ~= target.user
        end)
    end)
    : on('生效', function (cardEffect)
        local target = cardEffect.target
        if game:askCard(target, '打出', { name = '杀' }).card then
            return
        end
        game:damage(cardEffect.user, target, 1)
    end)
