game:on('游戏-开始', function ()
    local cardTable = game:getValue('牌表')
    if not cardTable then
        error('没有牌表：需要一个内容包提供牌表（例如 标准）')
    end

    local deck = game:createZone('抽牌堆', true)
    for _, entry in ipairs(cardTable) do
        for _ = 1, entry.count do
            deck:put(game:createCard(entry.name))
        end
    end
    deck:shuffle()

    game:createZone('弃牌堆')
    for _, player in ipairs(game:getDesk():getPlayers()) do
        player:addZone('手牌')
    end
end)

game:on('卡牌-结算后', function (ctx)
    game:getZone('弃牌堆'):put(ctx.card)
end)
