-- 摸牌：从抽牌堆顶取 count 张，整批放进该玩家的手牌
game:on('摸牌', function (draw)
    local deck = assert(game:getZone('抽牌'), '局上没有抽牌区')
    ---@cast deck OrderedZone
    -- 不够时由牌区上挂的回调补（洗回弃牌）
    local cards = deck:draw(draw.count)
    if #cards > 0 then
        game:moveCard(cards, draw.player:getZone('手牌'))
    end
end)
