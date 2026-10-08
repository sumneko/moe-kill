-- 【曹操】（标准版）：魏 · 男 · 体力上限 4

Hero '曹操'
    : kingdom '魏'
    : sex '男'
    : hp(4)
    : skills { '奸雄', '护驾' }

-- 【奸雄】当你受到伤害后，你可以获得对你造成伤害的牌。
Skill '奸雄'
    : auto(true)
    : on('被动', function (skill, host)
        local owner = skill.owner
        host:bindGC(owner:on('伤害-目标-生效后', function (damage)
            -- 能拿几张拿几张：已经不在原处的那些（被人拿走 / 被挪走）就不要了
            local cards = damage.cardsInPlace
            if #cards == 0 then
                return
            end
            if not skill:confirm() then
                return
            end
            skill:cast(function ()
                game:moveCard(cards, owner:getZone('手牌'))
            end)
        end))
    end)

-- 【护驾】主公技，当你需要使用或打出【闪】时，你可以令其他魏势力角色选择是否打出一张【闪】（视为由你使用或打出）。
Skill '护驾'
    : auto(true)
    : tags '主公技'
    : viewAs('闪', nil, function (ask, skill)
        if not skill:confirm() then
            return
        end
        local helpers = table.filter(game.desk.alivePlayers, function (player)
            return player ~= skill.owner and player.kingdom == skill.owner.kingdom
        end)
        for helper in game.desk:actionOrder(helpers, skill.owner) do
            local help = game:askCard(helper, '护驾', { name = '闪' })
            if help.card then
                game:moveCard(help.cards, ask:getTempZone())
                return help.cards
            end
        end
    end)
