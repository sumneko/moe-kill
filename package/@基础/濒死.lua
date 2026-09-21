game:on('游戏-开始', function ()
    for _, player in ipairs(game.desk.players) do
        local attributes = player:getAttributes()
        ---@type function?
        local pending    = nil
        attributes:onChange('体力', function (_, value, last)
            if player:isAlive() and value <= 0 and last > 0 then
                pending = game:enterDying(player)
            elseif pending and value > 0 then
                pending()
                pending = nil
            end
        end)
    end
end)

game:on('濒死', function (dying)
    local player  = dying.player
    local current = player
    while player:getAttr('体力') < 1 do
        local card = game:askCard(current, '使用', { name = '桃' }).result
        if card then
            game:useCard(current, card, { player })
        else
            current = assert(game.desk:getNext(current))
            if current == player then
                break
            end
        end
    end
    if player:getAttr('体力') < 1 then
        player:setAlive(false)
    end
end)
