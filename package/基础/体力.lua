local attributeSystem = rule:createAttributeSystem()

attributeSystem:define('体力', { min = 0 })
attributeSystem:define('体力上限', { min = 0 })

rule:setValue('属性系统', attributeSystem)

rule:on('游戏-开始', function (ctx)
    local maxHp = rule:getValue('体力上限') or 0
    for _, player in ipairs(ctx.desk:getPlayers()) do
        local attributes = player:getAttributes()
        attributes:set('体力上限', maxHp)
        attributes:set('体力', maxHp)
    end
end)
