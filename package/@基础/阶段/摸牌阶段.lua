-- 摸牌阶段：摸两张
local DRAW_COUNT = 2

game:on('阶段-开始', function (phase)
    if phase.name == '摸牌' then
        phase.player:draw(DRAW_COUNT)
    end
end)
