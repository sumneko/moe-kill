game:on('游戏-开始', function ()
    local cardTable = game:getValue('牌表')
    if not cardTable then
        error('没有牌表：需要一个内容包提供牌表（例如 标准）')
    end

    local deck = game:createZone('抽牌', true)
    ---@type Card[]
    local cards = {}
    for _, entry in ipairs(cardTable) do
        cards[#cards + 1] = game:createCard(entry.name, entry.suit, entry.point)
    end
    game:moveCard(cards, deck)
    deck:shuffle()

    local discard = game:createZone('弃牌')
    for _, player in ipairs(game.desk.players) do
        player:addZone('手牌')
    end

    deck:setShortageHandler(function (zone)     -- 抽牌堆空了：把弃牌全部洗回来
        if discard:count() == 0 then
            game:endGame { side = '平局', reason = '牌堆与弃牌堆都没有牌' }
            return
        end
        game:moveCard(discard:list(), zone)
        zone:shuffle()
    end)
end)
