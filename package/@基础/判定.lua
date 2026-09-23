-- 判定：从抽牌堆顶翻一张，放进这次判定自己的临时处理区
game:on('判定-亮牌', function (judge)
    local deck = assert(game:getZone('抽牌'), '局上没有抽牌区')
    ---@cast deck OrderedZone
    local cards = deck:draw(1)          -- 不够时由牌区上挂的回调补（洗回弃牌）
    if #cards > 0 then
        game:moveCard(cards[1], judge:getTempZone())   -- 判定牌暂存在这次判定的临时区里
        judge.card = cards[1]
    end
end)
