-- 【杀】（标准版）
-- 出牌阶段，对你攻击范围内的一名其他角色使用：该角色需打出一张【闪】来抵消，否则受到你造成的 1 点伤害。

Card '杀'
    : extends '基本牌'
    : limit('出牌', 1)
    : targets {
        filter = function (player, plan)
            local user  = plan.user
            local range = user:getAttr('攻击范围')
            return player ~= user
               and user:isInRange(player, range, plan.useOptions)
        end,
    }
    : on('生效', function (cardEffect)
        local target = cardEffect.target
        if game:askOffsetCard(target, '杀', { name = '闪' }).success then
            return
        end
        game:damage(cardEffect.user, target, 1, cardEffect.card)
    end)
