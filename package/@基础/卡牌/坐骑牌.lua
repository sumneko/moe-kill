-- 坐骑牌：进坐骑槽时，把这张牌的距离修正写进持有者的属性（进攻马读自己那头、防御马读别人那头）
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
        local delta = card:getValue('距离修正')
        if not delta then
            return
        end
        card:withZone(zone.owner:getAttributes():addModifier(name, delta))
    end)
