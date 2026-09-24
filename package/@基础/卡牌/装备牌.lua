-- 装备牌模板：继承它就有「装备」分类、不指定目标、只从手牌里用（使用）
-- 通用的使用效果写在基类上：结算后按分类找到槽位、放进装备区（加成由各类别基类的「进入区域」管）
Card '装备牌'
    : kind '装备'
    : noTarget()
    : zone '手牌'
    : on('结算后', function (useCard)
        local card = useCard.card
        local zone = useCard.user:getZone('装备')
        for _, slot in ipairs(zone.slots) do
            if card:isKind(slot) then
                zone:putInto(slot, card)
                return
            end
        end
        error('「{}」的分类没有对应的槽位' % { card.fullName }, 2)
    end)
