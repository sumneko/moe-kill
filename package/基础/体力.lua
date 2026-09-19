local 属性系统 = core.attribute.create()

属性系统:define('体力', { min = 0 })
属性系统:define('体力上限', { min = 0 })

rule:setValue('属性系统', 属性系统)

rule:on('游戏-开始', function (ctx)
    local 上限 = rule:getValue('体力上限') or 0
    for _, 玩家 in ipairs(ctx.desk:getPlayers()) do
        local 属性 = 玩家:getAttributes()
        属性:set('体力上限', 上限)
        属性:set('体力', 上限)
    end
end)
