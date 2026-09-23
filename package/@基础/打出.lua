-- 打出的牌：答复里给出的牌放进发起那次结算的临时处理区（最外层询问没有父结算就直接送弃牌堆）
game:on('卡牌-答复', function (ctx)
    if ctx.reason == '打出' and ctx.card then
        local owner = ctx.parent
        game:moveCard(ctx.card, owner and owner:getTempZone() or '弃牌')
    end
end)
