-- 【青龙偃月刀】（标准版）
-- 当你使用的【杀】被【闪】抵消时，你可以对相同的目标再使用一张【杀】。
-- 攻击范围 3

Card '青龙偃月刀'
    : extends '武器牌'
    : value('攻击范围', 3)
    : event('效果-来源-被抵消', function (card, ask)
        if ask.reason ~= '杀' or ask.card?.name ~= '闪' then
            return
        end
        local killer = ask.parent
        if not killer or killer.kind ~= 'cardEffect' then
            return
        end
        ---@cast killer CardEffect
        local zone  = assert(card:getZone())
        local owner = assert(zone.owner)
        -- 再对其使用一张【杀】：无视距离、不受次数限制、不计入次数（不答 = 不发动）
        card:cast(function ()
            game:askUseCard(owner, '青龙偃月刀', { name = '杀', target = killer.target }, {
                ignoreDistance = true,
                ignoreUseLimit = true,
                notCounted     = true,
            })
        end)
    end)
