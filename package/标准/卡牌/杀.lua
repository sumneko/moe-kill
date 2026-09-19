Card '杀'
    : on('目标合法', function (ctx)
        local desk  = game:getDesk()
        local range = ctx.user:getAttr('攻击范围')
        for _, target in ipairs(ctx.targets) do
            if desk:getDistance(ctx.user, target) > range then
                return false
            end
        end
    end)
    : on('使用', function (ctx)
        for _, target in ipairs(ctx.targets) do
            game:damage(ctx.user, target, 1)
        end
    end)
