-- 【丈八蛇矛】（标准版）
-- 你可以将两张手牌当【杀】使用或打出。
-- 攻击范围 3

Card '丈八蛇矛'
    : extends '武器牌'
    : value('攻击范围', 3)
    : on('被动', function (card, zone, host)
        local owner = zone.owner
        if not owner then
            return
        end
        host:bindGC(owner:addViewAs('杀', card, { zone = '手牌', min = 2 }))
    end)
