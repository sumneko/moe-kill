game:on('卡牌-答复', function (ctx)
    if ctx.reason == '打出' and ctx.card then
        local owner = ctx.parent                       -- 有父就暂存在那次结算的临时区（它的收尾送弃牌）
        game:moveCard(ctx.card, owner and owner:getTempZone() or '弃牌')
    end
end)
