-- 【麒麟弓】（标准版）
-- 当你使用【杀】对目标角色造成伤害时，你可以弃置其装备区里的一张坐骑牌。
-- 攻击范围 5

Card '麒麟弓'
    : extends '武器牌'
    : value('攻击范围', 5)
    : on('被动', function (card, zone, host)
        local owner = zone.owner
        if not owner then
            return
        end
        host:bindGC(owner:on('伤害-来源-开始', function (damage)
            -- 渠道：这次伤害得是本人用出去的【杀】造成的、且打的就是那张杀的目标（【决斗】这些不算）
            local cardEffect = damage.parent
            if cardEffect?.kind ~= 'cardEffect' then
                return
            end
            ---@cast cardEffect CardEffect
            if cardEffect.card.name ~= '杀'
            or cardEffect.target ~= damage.to then
                return
            end
            local mounts = table.filter(damage.to.equipCards, function (equip)
                return equip:isKind('坐骑')
            end)
            if #mounts == 0 then
                return
            end
            local discarded = game:askCard(owner, '麒麟弓', { card = mounts }).card
            if not discarded then
                return
            end
            card:cast(function ()
                game:moveCard(discarded, '弃牌')
            end)
        end))
    end)
