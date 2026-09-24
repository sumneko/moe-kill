-- 开局建牌堆：按牌表造牌并洗牌；手牌标暗；抽牌堆不够时把弃牌洗回来（洗不回来就地判平局）
game:on('游戏-开始', function ()
    local cardTable = game:getValue('牌表')
    if not cardTable then
        error('没有牌表：需要一个内容包提供牌表（例如 标准）')
    end

    local deck    = game:getZone('抽牌')
    local discard = game:getZone('弃牌')
    ---@type Card[]
    local cards = {}
    for _, entry in ipairs(cardTable) do
        cards[#cards + 1] = game:createCard(entry.name, entry.suit, entry.point)
    end
    game:moveCard(cards, deck)
    deck:shuffle()

    for _, player in ipairs(game.desk.players) do
        player:getZone('手牌'):setVisible(false)
    end

    deck:setShortageHandler(function (zone)
        if discard:count() == 0 then
            game:endGame { side = '平局', reason = '牌堆与弃牌堆都没有牌' }
            return
        end
        game:moveCard(discard:list(), zone)
        zone:shuffle()
    end)
end)
