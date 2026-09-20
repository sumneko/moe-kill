
game:on('卡牌-结算前', function (ctx)
    game:moveCard(ctx.card, '处理')
end)

game:on('卡牌-结算后', function (ctx)
    game:moveCard(ctx.card, '弃牌')
end)
