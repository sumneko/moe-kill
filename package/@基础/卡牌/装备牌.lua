-- 装备牌模板：继承它就有「装备」分类、不指定目标、只从手牌里用（使用）
-- 通用的使用效果写在基类上：结算后按分类找到槽位、放进装备区、按数据加修正
Card '装备牌'
    : kind '装备'
    : noTarget()
    : zone '手牌'
    : on('结算后', function (useCard)
        local card = useCard.card
        local def  = assert(game:getCard(card:getLabel()), '装备牌得有个内容定义')
        local zone = assert(useCard.user:getZone('装备'), '装备牌得有个装备区')
        for _, slot in ipairs(zone.slots) do
            if def:isKind(slot) then
                zone:putInto(slot, card)
                equip(useCard.user, card)
                return
            end
        end
        error('「{}」的分类没有对应的槽位' % { def.fullName }, 2)
    end)
