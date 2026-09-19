local attributeSystem = game:getAttributeSystem()

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

game:on('游戏-开始', function ()
    local defaultHp = game:getValue('默认体力') or 5
    for _, player in ipairs(game.desk:getPlayers()) do
        player:setAttr('体力上限', defaultHp)
        player:setAttr('体力',    defaultHp)
    end
end)
