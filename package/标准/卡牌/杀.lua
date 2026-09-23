-- 【杀】（标准版）
-- 出牌阶段，对你攻击范围内的一名其他角色使用：该角色需打出一张【闪】来抵消，否则受到你造成的 1 点伤害。

Card '杀'
    : extends '基本牌'
    : limit('出牌', 1)
    : on('获取目标', function (target)
        local desk  = game.desk
        local range = target.user:getAttr('攻击范围')
        return table.filter(desk.alivePlayers, function (player)
            return player ~= target.user
               and desk:getDistance(target.user, player) <= range
        end)
    end)
    : on('生效', function (cardEffect)
        local target = cardEffect.target
        if game:askCard(target, '打出', { name = '闪' }).card then
            return
        end
        game:damage(cardEffect.user, target, 1)
    end)
