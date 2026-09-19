rule:on('游戏-开始', function (ctx)
    local cardTable = rule:getValue('牌表')
    if not cardTable then
        error('没有牌表：需要一个内容包提供牌表（例如 标准）')
    end

    local deck = ctx.room:createZone('抽牌堆', true)
    for _, entry in ipairs(cardTable) do
        for _ = 1, entry.count do
            deck:put(ctx.room:createCard(entry.name))
        end
    end
    deck:shuffle()
end)
