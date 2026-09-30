-- 【青龙偃月刀】（标准版）
-- 当你使用的【杀】被【闪】抵消时，你可以对相同的目标再使用一张【杀】。
-- 攻击范围 3

Card '青龙偃月刀'
    : extends '武器牌'
    : value('攻击范围', 3)
    : on('被动', function (card, zone, host)
        local owner = zone.owner
        if not owner then
            return
        end
        host:bindGC(owner:on('效果-来源-被抵消', function (ask)
            if ask.reason ~= '杀' or ask.card?.name ~= '闪' then
                return
            end
            local killer = ask.parent
            if not killer or killer.kind ~= 'cardEffect' then
                return
            end
            ---@cast killer CardEffect
            -- 再对其使用一张【杀】：无视距离、不受次数限制、不计入次数（不答 = 不发动）
            game:askUseCard(owner, '青龙偃月刀', { name = '杀', target = killer.target }, {
                ignoreDistance = true,
                ignoreUseLimit = true,
                notCounted     = true,
            })
        end))
    end)
