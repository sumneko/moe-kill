-- 【黄月英】（标准版）：蜀 · 女 · 体力上限 3

Hero '黄月英'
    : kingdom '蜀'
    : sex '女'
    : hp(3)
    : skills { '集智', '奇才' }

-- 【集智】当你使用非转化的普通锦囊牌时，你可摸一张牌。
Skill '集智'
    : auto(true)
    : on('被动', function (skill, host)
        local owner = skill.owner
        host:bindGC(owner:on('卡牌-结算前', function (useCard)
            if useCard.card.virtual then
                return
            end
            if not useCard.card:isKind('非延时锦囊') then
                return
            end
            skill:tryCast(function ()
                owner:draw(1)
            end)
        end))
    end)

-- 【奇才】锁定技，你使用锦囊牌无距离限制。
Skill '奇才'
    : tags '锁定技'
    : on('被动', function (skill, host)
        local owner = skill.owner
        host:bindGC(owner:on('卡牌-来源-使用选项', function (check)
            if check.card:isKind('锦囊') then
                return { ignoreDistance = true }
            end
        end))
    end)
