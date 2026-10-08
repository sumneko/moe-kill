-- 【司马懿】（标准版）：魏 · 男 · 体力上限 3

Hero '司马懿'
    : kingdom '魏'
    : sex '男'
    : hp(3)
    : skills { '鬼才', '反馈' }

-- 【鬼才】当一名角色的判定牌生效前，你可以打出一张手牌代替之。
Skill '鬼才'
    : auto(true)
    : on('被动', function (skill, host)
        local owner = skill.owner
        host:bindGC(game:on('判定-前', function (judge)
            if owner:getZone('手牌'):count() == 0 then
                return
            end
            if not skill:confirm() then
                return
            end
            skill:cast(function ()
                local card = game:askCard(owner, '鬼才', { zone = '手牌' }).card
                if card then
                    judge:replace(card)
                end
            end)
        end))
    end)

-- 【反馈】当你受到伤害后，你可以获得伤害来源的一张牌。
Skill '反馈'
    : auto(true)
    : on('被动', function (skill, host)
        local owner = skill.owner
        host:bindGC(owner:on('伤害-目标-结束', function (damage)
            local from = damage.from
            if not from or not from:hasCard() then
                return
            end
            if not skill:confirm() then
                return
            end
            skill:cast(function ()
                local card = game:askCard(owner, '反馈', { zone = from:getZones() }).card
                if card then
                    game:moveCard(card, owner:getZone('手牌'))
                end
            end)
        end))
    end)
