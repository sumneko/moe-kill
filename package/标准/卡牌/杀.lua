Card '杀'
    : on('获取目标', function (ctx)
        local desk  = game:getDesk()
        local range = ctx.user:getAttr('攻击范围')
        local legal = {}
        for _, player in ipairs(desk:getPlayers()) do
            if player ~= ctx.user and desk:getDistance(ctx.user, player) <= range then
                legal[#legal + 1] = player
            end
        end
        return legal
    end)
    : on('使用', function (ctx)
        for _, target in ipairs(ctx.targets) do
            game:damage(ctx.user, target, 1)
        end
    end)
