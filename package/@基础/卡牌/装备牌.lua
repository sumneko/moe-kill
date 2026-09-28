-- 装备牌模板：继承它就有「装备」分类、不指定目标、只从手牌里用（使用）
-- 通用的使用处理写在基类上：「使用」钩子里按分类找到槽位、用一次挪牌的结算装进那个槽位（加成由各类别基类的「进入区域」管）
Card '装备牌'
    : kind '装备'
    : noTarget()
    : zone '手牌'
    : on('使用', function (useCard)
        local card = useCard.card
        local zone = useCard.user:getZone('装备')
        -- 按分类找槽位：找到就装，没有对应槽位就不装（牌随收尾进弃牌堆）
        for _, slot in ipairs(zone.slots) do
            if card:isKind(slot) then
                game:moveCardWithSlot(card, zone, slot)
                return
            end
        end
    end)
