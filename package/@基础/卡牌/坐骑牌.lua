-- 坐骑牌：进坐骑槽时，把这张牌的距离修正写进持有者的属性（进攻马读自己那头、防御马读别人那头）
-- 两种马功能一模一样（只是进不同的槽、改不同的修正），所以具体马只要 extends 其中一个即可
Depends { './装备牌' }

---@type table<string, string> # 槽位名 → 哪条修正属性
local ATTRS = {
    进攻马 = '进攻修正',
    防御马 = '防御修正',
}

Card '坐骑牌'
    : extends '装备牌'
    : addKind '坐骑'
    : on('进入区域', function (card, zone, slot)
        local name = slot and ATTRS[slot]
        if not name then
            return
        end
        card:withZone(zone.owner:getAttributes():addModifier(name, card:getValue('距离修正')))
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
