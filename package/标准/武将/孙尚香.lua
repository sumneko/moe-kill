-- 【孙尚香】（标准版）：吴 · 女 · 体力上限 3

Hero '孙尚香'
    : kingdom '吴'
    : sex '女'
    : hp(3)
    : skills { '枭姬', '结姻' }

-- 【枭姬】当你失去一张装备区的装备牌后，你可以摸两张牌。
Skill '枭姬'
    : auto(true)
    : event('卡牌-离开区域', function (skill, card, zone)
        -- 只有「本人的、与这张牌分类对应的那个子区」才算失去装备（照装备模板的判法）
        if zone.owner?:equipZoneOf(card) ~= zone then
            return
        end
        skill:tryCast(function ()
            skill.owner:draw(2)
        end)
    end)

-- 【结姻】出牌阶段限一次，你可以弃置两张手牌并选择一名已受伤的男性角色，然后你与其各回复 1 点体力。
Skill '结姻'
    : limit('出牌', 1)
    : cards { zone = '手牌', min = 2, max = 2 }
    : targets {
        filter = function (player, skill)
            return player ~= skill.owner
               and player.sex == '男'
               and player:getLostHp() > 0
        end,
    }
    : on('使用', function (cast)
        local target = cast.use.targets[1]
        if not target then
            return
        end
        game:moveCard(cast.use.cards, '弃牌')
        game:heal(cast.from, 1)
        game:heal(target, 1)
    end)
