-- 摸牌阶段：摸「摸牌数」张（技能可以在「阶段-开始」里改它，改完挂到本阶段上、阶段结束自动撤）
local attributeSystem = game:getAttributeSystem()
attributeSystem:define('摸牌数', {
    min    = 0,
    max    = 999999,
    simple = true,
})

game:on('游戏-开始', function ()
    local count = game:getValue('默认摸牌数') or 2
    for _, player in ipairs(game.desk.players) do
        player:setAttr('摸牌数', count)
    end
end)

game:on('阶段-生效', function (phase)
    if phase.name == '摸牌' then
        phase.player:draw(phase.player:getAttr('摸牌数'))
    end
end)
