-- 判定：从抽牌堆顶翻一张，放进这次判定自己的临时处理区
game:on('判定-亮牌', function (judge)
    -- 不够时由牌区上挂的回调补（洗回弃牌）
    local cards = game:drawCards(judge.player, 1, judge:getTempZone())
    if #cards > 0 then
        judge.card = cards[1]
    end
end)
