local attributeSystem = game:getAttributeSystem()

attributeSystem:define('攻击范围', {
    min    = 0,
    max    = 999999,
    simple = true,
})

game:on('游戏-开始', function ()
    for _, player in ipairs(game.desk:getPlayers()) do
        player:setAttr('攻击范围', 1)
    end
end)
