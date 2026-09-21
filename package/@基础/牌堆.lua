game:on('游戏-开始', function ()
    local cardTable = game:getValue('牌表')
    if not cardTable then
        error('没有牌表：需要一个内容包提供牌表（例如 标准）')
    end

    local deck = game:createZone('抽牌', true)
    ---@type Card[]
    local cards = {}
    for _, entry in ipairs(cardTable) do
        for _ = 1, entry.count do
            cards[#cards + 1] = game:createCard(entry.name)
        end
    end
    game:moveCard(cards, deck)
    deck:shuffle()

    game:createZone('弃牌')
    game:createZone('处理')
    for _, player in ipairs(game.desk.players) do
        player:addZone('手牌')
    end
end)
