-- 定义「体力」属性：下限到负数，上限跟着「体力上限」走
-- 开局的默认值只给「还没选武将」的角色（选了武将的上限与体力由 @基础/武将.lua 写）
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
    local defaultHp = rule.defaultHp or 5
    for _, player in ipairs(game.desk.players) do
        if not player.hero then
            player:setAttr('体力上限', defaultHp)
            player:setAttr('体力',    defaultHp)
        end
    end
end)
