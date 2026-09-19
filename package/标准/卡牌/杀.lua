Card '杀'
    : on('获取目标', function (ctx)
        local desk  = game.desk
        local range = ctx.user:getAttr('攻击范围')
        return util.filter(desk.alivePlayers, function (player)
            return player ~= ctx.user
               and desk:getDistance(ctx.user, player) <= range
        end)
    end)
    : on('使用', function (ctx)
        for _, target in ipairs(ctx.targets) do
            game:damage(ctx.user, target, 1)
        end
    end)
