-- 【顺手牵羊】（标准版）
-- 出牌阶段，对距离 1 以内的一名区域里有牌的其他角色使用。你获得其区域里的一张牌。
-- 服务器侧看得见所有牌（隐瞒是协议层的事）⇒ 目标的每个区都逐张当候选，挑中哪张就获得哪张。

Card '顺手牵羊'
    : extends '锦囊牌'
    : targets {
        filter = function (player, plan)
            local user = plan.user
            return player ~= user
                and player:hasCard()
                and user:distance(player) <= 1
        end,
    }
    : on('生效', function (cardEffect)
        local card = game:askCard(cardEffect.user, '顺手牵羊', { zone = cardEffect.target:getZones() }).card
        if not card then
            return
        end
        game:moveCard(card, cardEffect.user:getZone('手牌'))
    end)
