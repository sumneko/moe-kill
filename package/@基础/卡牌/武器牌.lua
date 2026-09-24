-- 武器牌：进武器槽时，把这张牌的攻击范围加成写进持有者的属性（离开装备区时自动撤）
Depends { './装备牌' }

Card '武器牌'
    : extends '装备牌'
    : addKind '武器'
    : on('进入区域', function (card, zone, slot)
        if slot ~= '武器' then
            return
        end
        local range = card:getValue('攻击范围')
        if not range then
            return
        end
        card:withZone(zone.owner:getAttributes():addModifier('攻击范围', range))
    end)
