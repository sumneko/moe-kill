-- 判定：从抽牌堆顶翻一张，放进这次判定自己的临时处理区
game:on('判定-亮牌', function (judge)
    local deck = assert(game:getZone('抽牌'), '局上没有抽牌区')
    ---@cast deck OrderedZone
    -- 不够时由牌区上挂的回调补（洗回弃牌）
    local cards = deck:draw(1)
    if #cards > 0 then
        game:moveCard(cards[1], judge:getTempZone())
        judge.card = cards[1]
    end
end)
