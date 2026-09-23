-- 打出的牌：答复里给出的牌放进发起那次结算的临时处理区（最外层询问没有父结算就直接送弃牌堆）
game:on('卡牌-答复', function (askCard)
    if askCard.reason == '打出' and askCard.card then
        local owner = askCard.parent
        game:moveCard(askCard.card, owner and owner:getTempZone() or '弃牌')
    end
end)
