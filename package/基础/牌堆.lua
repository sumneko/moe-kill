rule:on('游戏-开始', function (ctx)
    local 牌表 = rule:getValue('牌表')
    if not 牌表 then
        error('没有牌表：需要一个内容包提供牌表（例如 标准）')
    end
    local 随机源 = ctx.random
    if not 随机源 then
        error('建牌堆需要注入随机源')
    end

    local 牌堆 = core.orderedZone.create()
    for _, 种类 in ipairs(牌表) do
        for _ = 1, 种类.张数 do
            牌堆:put(core.card.create(种类.名))
        end
    end
    牌堆:shuffle(随机源)

    rule:setValue('牌堆', 牌堆)
end)
