-- 【乐不思蜀】（标准版）
-- 出牌阶段，对一名其他角色使用。将【乐不思蜀】放置于该角色的判定区里：若判定结果不为红桃，则跳过其下一个出牌阶段。

Card '乐不思蜀'
    : extends '延时锦囊牌'
    : on('获取目标', function (plan)
        return table.filter(game.desk.alivePlayers, function (player)
            return player ~= plan.user
        end)
    end)
    : on('判定结果', function (resolution)
        if resolution.judge?.card?.suit ~= '红桃' then
            resolution.player.turn:skipPhase('出牌')
        end
    end)
