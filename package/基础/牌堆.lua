rule:on('游戏-开始', function (ctx)
    local cardTable = rule:getValue('牌表')
    if not cardTable then
        error('没有牌表：需要一个内容包提供牌表（例如 标准）')
    end
    local random = ctx.random
    if not random then
        error('建牌堆需要注入随机源')
    end

    local deck = core.orderedZone.create()
    for _, entry in ipairs(cardTable) do
        for _ = 1, entry.count do
            deck:put(core.card.create(entry.name))
        end
    end
    deck:shuffle(random)

    rule:setValue('牌堆', deck)
end)
