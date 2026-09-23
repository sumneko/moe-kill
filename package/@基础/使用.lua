
-- 用过的牌：结算开始时放进这次用牌自己的临时处理区（收尾时统一送弃牌堆）
game:on('卡牌-结算前', function (useCard)
    game:moveCard(useCard.card, useCard:getTempZone())
end)
