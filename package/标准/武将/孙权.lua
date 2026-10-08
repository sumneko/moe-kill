-- 【孙权】（标准版）：吴 · 男 · 体力上限 4

Hero '孙权'
    : kingdom '吴'
    : sex '男'
    : hp(4)
    : skills { '制衡', '救援' }

-- 【制衡】出牌阶段限一次，你可以弃置任意张牌，然后摸等量的牌。
Skill '制衡'
    : limit('出牌', 1)
    : cards { zone = rule.ownZones, max = 1000 }
    : on('使用', function (cast)
        game:moveCard(cast.use.cards, '弃牌')
        cast.from:draw(#cast.use.cards)
    end)

-- 【救援】主公技，其他吴势力角色使用【桃】令你回复体力时，回复值 +1。
Skill '救援'
    : tags '主公技'
    : on('被动', function (skill, host)
        local owner = skill.owner
        host:bindGC(owner:on('治疗-目标-生效前', function (heal)
            local from = heal.from
            if not from or from == owner or from.kingdom ~= '吴' then
                return
            end
            if heal.card?.name ~= '桃' then
                return
            end
            skill:cast(function ()
                heal.amount = heal.amount + 1
            end)
        end))
    end)
