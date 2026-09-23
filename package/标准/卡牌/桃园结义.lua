-- 【桃园结义】（标准版）
-- 出牌阶段，对所有角色使用。每名目标角色回复 1 点体力。

Card '桃园结义'
    : extends '锦囊牌'
    : on('获取目标', function (ctx)
        return game.desk.alivePlayers
    end)
    : on('生效', function (ctx)
        game:heal(ctx.target, 1)
    end)
