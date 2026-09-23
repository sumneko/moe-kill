-- 【桃】（标准版）
-- 出牌阶段，对自己使用：回复 1 点体力；或令一名处于濒死状态的角色回复 1 点体力。

Card '桃'
    : extends '基本牌'
    : on('获取目标', function (target)
        local user = target.user
        ---@type Player[]
        local targets = {}
        if user:getAttr('体力') > 0 and user:getAttr('体力') < user:getAttr('体力上限') then
            targets[#targets + 1] = user
        end
        for _, player in ipairs(game.desk.alivePlayers) do
            if player:getAttr('体力') <= 0 then
                targets[#targets + 1] = player
            end
        end
        return targets
    end)
    : on('生效', function (cardEffect)
        game:heal(cardEffect.target, 1)
    end)
