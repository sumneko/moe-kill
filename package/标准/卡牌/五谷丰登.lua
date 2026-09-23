-- 【五谷丰登】（标准版）
-- 出牌阶段，对所有角色使用。你亮出牌堆顶等同于目标角色数的牌，然后每名目标角色获得其中一张；
-- 使用结算结束后，将其中剩余的牌置入弃牌堆。

Card '五谷丰登'
    : extends '锦囊牌'
    : on('获取目标', function (ctx)
        return game.desk.alivePlayers
    end)
    : on('结算前', function (ctx)
        game:moveCard(game:getZone('抽牌'):draw(#ctx.targets), ctx:getTempZone())
    end)
    : on('生效', function (ctx)
        local revealed = assert(ctx.parent):getTempZone():list()
        local card = game:askCard(ctx.target, '五谷丰登', { cards = revealed }).card
        if not card then
            return
        end
        game:moveCard(card, assert(ctx.target:getZone('手牌'), '目标没有手牌区'))
    end)
