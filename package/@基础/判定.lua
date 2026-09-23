game:on('判定-亮牌', function (judge)
    local deck = assert(game:getZone('抽牌'), '局上没有抽牌区')
    ---@cast deck OrderedZone
    local cards = deck:draw(1)          -- 不够时由牌区上挂的回调补（洗回弃牌）
    if #cards > 0 then
        judge.card = cards[1]           -- 亮出：从抽牌堆取出 ⇒ 不属于任何区
    end
end)

game:on('判定-后', function (judge)
    ---@type Card[]
    local cards = {}
    for _, card in ipairs(judge.replaced) do
        cards[#cards + 1] = card
    end
    if judge.card then
        cards[#cards + 1] = judge.card
    end
    if #cards > 0 then
        game:moveCard(cards, '弃牌')
    end
end)
