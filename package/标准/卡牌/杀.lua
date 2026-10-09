-- 【杀】（标准版）
-- 出牌阶段，对你攻击范围内的一名其他角色使用：该角色需打出一张【闪】来抵消，否则受到你造成的 1 点伤害。

Card '杀'
    : extends '基本牌'
    : limit('出牌', 1)
    : targets {
        filter = function (player, plan)
            return player ~= plan.user
               and plan.user:isInRange(player, nil, plan.useOptions)
        end,
    }
    : on('生效', function (cardEffect, useCard)
        local ask = game:askOffsetCard(cardEffect.target, '杀', { name = '闪' }, { responseTo = useCard })
        if ask.success then
            return
        end
        game:damage(cardEffect.user, cardEffect.target, 1, cardEffect.card)
    end)
