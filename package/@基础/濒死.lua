game:on('濒死-进入', function (dying)
    local player  = dying.player
    local start   = game.turnPlayer
    if not start then
        error('濒死结算要从当前回合角色开始，但此刻不在任何角色的回合里', 2)
    end
    local current = start
    while player:getAttr('体力') < 1 do
        ---@type AskCard.Condition # 只要能救他的【桃】
        local condition = { name = '桃', targets = { player } }
        ---@type Card?
        local card = game:askCard(current, '使用', condition).card
        if card then
            game:useCard(current, card, { player })
        else
            current = assert(game.desk:getNext(current))
            if current == start then
                break
            end
        end
    end
end)
