-- 【刘备】（标准版）：蜀 · 男 · 体力上限 4

Hero '刘备'
    : kingdom '蜀'
    : sex '男'
    : hp(4)
    : skills { '仁德', '激将' }

-- 【仁德】出牌阶段，你可以将至少一张手牌任意分配给其他角色。你于本阶段内以此法给出的手牌首次达到两张或更多后，你回复 1 点体力。
-- 描述已按 `references/武将牌/标准包.md` 校对；效果待实现（需要主动技的发动入口）
Skill '仁德'

-- 【激将】主公技，当你需要使用或打出【杀】时，你可以令其他蜀势力角色选择是否打出一张【杀】（视为由你使用或打出）。
Skill '激将'
    : auto(true)
    : tags '主公技'
    : on('被动', function (skill, host)
        local owner = skill.owner
        local viewAs = owner:addViewAs('杀', skill)
            : on('发动', function (ask)
                if not skill:confirm() then
                    return
                end
                local helpers = table.filter(game.desk.alivePlayers, function (player)
                    return player ~= owner and player.kingdom == owner.kingdom
                end)
                for helper in game.desk:actionOrder(helpers, owner) do
                    local help = game:askCard(helper, '激将', { name = '杀' })
                    if help.card then
                        game:moveCard(help.cards, ask:getTempZone())
                        return help.cards
                    end
                end
            end)
        host:bindGC(viewAs)
    end)
