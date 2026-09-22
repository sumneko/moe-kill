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
        local hand = assert(current:getZone('手牌'), '这个玩家没有手牌区')
        ---@type AskCard.Option[]
        local options = {}
        for _, card in ipairs(hand:list()) do
            if card:getLabel() == '桃' and game:canUse(current, card, { player }) then
                options[#options + 1] = { card = card, targets = { player } }
            end
        end
        ---@type Card?
        local card = game:askCard(current, '使用', options).card
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
