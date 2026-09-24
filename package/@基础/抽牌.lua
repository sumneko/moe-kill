-- 摸牌：从抽牌堆顶抽 count 张给这个玩家（默认进他的手牌）
game:on('摸牌-生效', function (draw)
    game:drawCards(draw.player, draw.count)
end)
