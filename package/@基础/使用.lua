
game:on('卡牌-结算前', function (ctx)
    game:moveCard(ctx.card, ctx:getTempZone())
end)
