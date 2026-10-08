-- 【刘备】（标准版）：蜀 · 男 · 体力上限 4

Hero '刘备'
    : kingdom '蜀'
    : sex '男'
    : hp(4)
    : skills { '仁德', '激将' }

-- 【仁德】出牌阶段，你可以将至少一张手牌任意分配给其他角色。你于本阶段内以此法给出的手牌首次达到两张或更多后，你回复 1 点体力。
Skill '仁德'
    : cards { zone = '手牌', max = 1000 }
    : targets { filter = function (player, skill)
        return player ~= skill.owner
    end }
    : on('使用', function (cast)
        local receiver = cast.use.targets[1]
        if not receiver then
            return
        end
        game:moveCard(cast.use.cards, receiver:getZone('手牌'))
        local phase = assert(cast.from:currentPhase())
        local given = phase:getTag('仁德') or 0
        local total = given + #cast.use.cards
        phase:setTag('仁德', total)
        if given < 2 and total >= 2 then
            game:heal(cast.from, 1)
        end
    end)

-- 【激将】主公技，当你需要使用或打出【杀】时，你可以令其他蜀势力角色选择是否打出一张【杀】（视为由你使用或打出）。
Skill '激将'
    : auto(true)
    : tags '主公技'
    : viewAs('杀', nil, function (ask, skill)
        if not skill:confirm() then
            return
        end
        local helpers = table.filter(game.desk.alivePlayers, function (player)
            return player ~= skill.owner and player.kingdom == skill.owner.kingdom
        end)
        for helper in game.desk:actionOrder(helpers, skill.owner) do
            local help = game:askCard(helper, '激将', { name = '杀' })
            if help.card then
                game:moveCard(help.cards, ask:getTempZone())
                return help.cards
            end
        end
    end)
