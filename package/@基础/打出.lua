game:on('卡牌-答复', function (ctx)
    if ctx.reason == '打出' and ctx.card then
        game:moveCard(ctx.card, '处理')
    end
end)

game:on('卡牌-答复后', function (ctx)
    if ctx.reason == '打出' and ctx.card then
        game:moveCard(ctx.card, '弃牌')
    end
end)
