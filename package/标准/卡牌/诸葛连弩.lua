-- 【诸葛连弩】（标准版）
-- 出牌阶段，你可以使用任意数量的【杀】。
-- 攻击范围 1

Card '诸葛连弩'
    : extends '武器牌'
    : value('攻击范围', 1)
    : on('被动', function (card, zone, host)
        local owner = zone.owner
        if not owner then
            return
        end
        host:bindGC(owner:addLimit('杀', '出牌', 1000))
    end)
