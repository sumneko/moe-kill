-- 【桃】（标准版）
-- 出牌阶段，对自己使用：回复 1 点体力；或令一名处于濒死状态的角色回复 1 点体力。

Card '桃'
    : extends '基本牌'
    : targets {
        filter = function (player, plan)
            local user = plan.user
            if player == user and user:getAttr('体力') > 0 and user:getAttr('体力') < user:getAttr('体力上限') then
                return true
            end
            return player:getAttr('体力') <= 0
        end,
    }
    : on('生效', function (cardEffect)
        game:heal(cardEffect.target, 1, cardEffect.user, cardEffect.card)
    end)
