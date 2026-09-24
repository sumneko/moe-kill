-- 定义「攻击范围」属性：够不够得着由内容包拿它与距离比
-- 默认 1；装备（武器）的加成由 @基础/装备.lua 的 equip 加上、随牌离开装备区自动撤
local attributeSystem = game:getAttributeSystem()

attributeSystem:define('攻击范围', {
    min    = 0,
    max    = 999999,
    simple = true,
})

game:on('游戏-开始', function ()
    for _, player in ipairs(game.desk.players) do
        player:setAttr('攻击范围', 1)
    end
end)
