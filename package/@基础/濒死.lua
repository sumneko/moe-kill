game:on('濒死-进入', function (dying)
    local player = dying.player
    local damage = dying.damage
    player:setTag('凶手', damage and damage.from)

    local current = player
    while player:getAttr('体力') < 1 do
        ---@type AskCard.Condition # 只要能救他的【桃】
        local condition = { name = '桃', targets = { player } }
        ---@type Card?
        local card = game:askCard(current, '使用', condition).card
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

game:on('濒死-离开', function (dying)
    dying.player:removeTag('凶手')
end)
