-- 【万箭齐发】（标准版）
-- 出牌阶段，对所有其他角色使用。每名目标角色需打出一张【闪】，否则受到 1 点伤害。

Card '万箭齐发'
    : extends '锦囊牌'
    : on('获取目标', function (ctx)
        return table.filter(game.desk.alivePlayers, function (player)
            return player ~= ctx.user
        end)
    end)
    : on('生效', function (ctx)
        local target = ctx.target
        if game:askCard(target, '打出', { name = '闪' }).card then
            return
        end
        game:damage(ctx.user, target, 1)
    end)
