-- 坐骑牌：被动生效时，把这张牌的距离修正写进持有者的属性（进攻马读自己那头、防御马读别人那头）
-- 两种马功能一模一样（只是进不同的槽、改不同的修正），所以具体马只要 extends 其中一个即可
Depends { './装备牌' }

Card '坐骑牌'
    : extends '装备牌'
    : addKind '坐骑'
    : on('被动', function (card, zone, host)
        local name = card:isKind('进攻马') and '进攻修正' or '防御修正'
        host:bindGC(zone.owner:addAttr(name, card:getValue('距离修正')))
    end)

-- 进攻马（-1 马）：计算自己到别人的距离时减
Card '进攻马'
    : extends '坐骑牌'
    : addKind '进攻马'
    : value('距离修正', -1)

-- 防御马（+1 马）：别人计算到自己的距离时加
Card '防御马'
    : extends '坐骑牌'
    : addKind '防御马'
    : value('距离修正', 1)
