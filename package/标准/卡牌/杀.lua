-- 【杀】（标准版）
-- 出牌阶段，对你攻击范围内的一名其他角色使用：该角色需打出一张【闪】来抵消，否则受到你造成的 1 点伤害。

Card '杀'
    : on('获取目标', function (ctx)
        local desk  = game.desk
        local range = ctx.user:getAttr('攻击范围')
        return table.filter(desk.alivePlayers, function (player)
            return player ~= ctx.user
               and desk:getDistance(ctx.user, player) <= range
        end)
    end)
    : on('生效', function (ctx)
        local target = ctx.target
        local card   = game:askCard(target, '打出', { name = '闪' }).result
        if card then
            return
        end
        game:damage(ctx.user, target, 1)
    end)
