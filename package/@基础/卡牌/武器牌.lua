-- 武器牌：被动生效时，把这张牌的攻击范围写进持有者的属性（离开槽位时由装备模板停用被动、自动撤）
-- 牌上写的就是描述里的那个值；属性的默认 1 已经在了，所以加的是它与 1 的差值
Depends { './装备牌' }

Card '武器牌'
    : extends '装备牌'
    : addKind '武器'
    : on('被动', function (card, zone, host)
        local range = card:getValue('攻击范围')
        if not range then
            return
        end
        host:bindGC(zone.owner:addAttr('攻击范围', range - 1))
    end)
