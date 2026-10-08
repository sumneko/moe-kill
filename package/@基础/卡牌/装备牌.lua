-- 装备牌模板：继承它就有「装备」分类、不指定目标、只从手牌里用（使用）
-- 通用的使用处理写在基类上：「使用」钩子里把这牌放进它分类对应的那个装备子区（一个子区只装一张）
-- 被动随子区启停：进了「本人的、与分类对应的」子区才启用（效果写在各类别基类的「被动」里）
Card '装备牌'
    : kind '装备'
    : targets { min = 0, max = 0 }
    : zone '手牌'
    : on('进入区域', function (card, zone)
        local owner = zone.owner
        if owner and owner:equipZoneOf(card) == zone then
            card:enablePassive()
        end
    end)
    : on('离开区域', function (card, zone)
        local owner = zone.owner
        if owner and owner:equipZoneOf(card) == zone then
            card:disablePassive()
        end
    end)
    : on('使用', function (useCard)
        useCard.user:equipCard(useCard.card)
    end)
