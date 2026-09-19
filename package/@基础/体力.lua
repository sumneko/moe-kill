local attributeSystem = rule:createAttributeSystem()

attributeSystem:define('体力', { min = 0 })
attributeSystem:define('体力上限', { min = 0 })

rule:setValue('属性系统', attributeSystem)

rule:on('游戏-开始', function (ctx)
    local defaultHp = rule:getValue('默认体力') or 0
    for _, player in ipairs(ctx.desk:getPlayers()) do
        local attributes = player:getAttributes()
        attributes:set('体力上限', defaultHp)
        attributes:set('体力', defaultHp)
    end
end)
