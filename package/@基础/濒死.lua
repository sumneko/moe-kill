-- 濒死：从顺序锚点起按行动顺序求【桃】
game:on('濒死-进入', function (dying)
    local player  = dying.player
    local start   = assert(game.turnPlayer or game.lastTurnPlayer, '濒死结算要从顺序锚点起，但还没有任何人开始过回合')
    local current = start
    while player:getAttr('体力') < 1 do
        ---@type AskUseCard.Condition # 只要能救他的【桃】
        local condition = { name = '桃', target = player }
        if not game:askUseCard(current, '濒死', condition).useCard then
            current = assert(game.desk:getNext(current))
            if current == start then
                break
            end
        end
    end
end)
