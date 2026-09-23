game:on('濒死-进入', function (dying)
    local player  = dying.player
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
end)
