-- 【过河拆桥】（标准版）
-- 出牌阶段，对一名区域里有牌的其他角色使用。你弃置其区域里的一张牌。
-- 服务器侧看得见所有牌（隐瞒是协议层的事）⇒ 目标的每个区都逐张当候选，挑中哪张就弃哪张。

Card '过河拆桥'
    : extends '锦囊牌'
    : targets {
        filter = function (player, plan)
            return player ~= plan.user and player:hasCard()
        end,
    }
    : on('生效', function (cardEffect)
        local card = game:askCard(cardEffect.user, '过河拆桥', { zone = cardEffect.target:getZones() }).card
        if not card then
            return
        end
        game:moveCard(card, '弃牌')
    end)
