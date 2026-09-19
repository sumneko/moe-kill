local attributeSystem = rule:getAttributeSystem()

attributeSystem:define('体力', {
    min    = -999999,
    max    = '体力上限',
    simple = true,
})
attributeSystem:define('体力上限', {
    min    = 0,
    max    = 999999,
    simple = true,
})

rule:on('游戏-开始', function ()
    local defaultHp = rule:getValue('默认体力') or 5
    for _, player in ipairs(rule.room:getDesk():getPlayers()) do
        player:setAttr('体力上限', defaultHp)
        player:setAttr('体力',    defaultHp)
    end
end)
