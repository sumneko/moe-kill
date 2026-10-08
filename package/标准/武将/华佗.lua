-- 【华佗】（标准版）：群 · 男 · 体力上限 3

Hero '华佗'
    : kingdom '群'
    : sex '男'
    : hp(3)
    : skills { '青囊', '急救' }

-- 【青囊】出牌阶段限一次，你可以弃置一张手牌并选择一名已受伤的角色，然后其回复 1 点体力。
Skill '青囊'
    : limit('出牌', 1)
    : cards { zone = '手牌' }
    : targets { filter = function (player)
        return player:getLostHp() > 0
    end }
    : on('使用', function (cast)
        local target = cast.use.targets[1]
        if not target then
            return
        end
        game:moveCard(cast.use.cards, '弃牌')
        game:heal(target, 1)
    end)

-- 【急救】你的回合外，你可以将一张红色牌当【桃】使用。
Skill '急救'
    : viewAs('桃', { color = '红', zone = rule.ownZones }, function (ask, skill)
        return skill.owner.turn == nil
    end)
