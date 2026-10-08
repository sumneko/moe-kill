-- 【司马懿】（标准版）：魏 · 男 · 体力上限 3

Hero '司马懿'
    : kingdom '魏'
    : sex '男'
    : hp(3)
    : skills { '鬼才', '反馈' }

-- 【鬼才】当一名角色的判定牌生效前，你可以打出一张手牌代替之。
Skill '鬼才'
    : auto(true)
    : globalEvent('判定-前', function (skill, judge)
        if skill.owner:getZone('手牌'):count() == 0 then
            return
        end
        skill:tryCast(function ()
            local card = game:askCard(skill.owner, '鬼才', { zone = '手牌' }).card
            if card then
                judge:replace(card)
            end
        end)
    end)

-- 【反馈】当你受到伤害后，你可以获得伤害来源的一张牌。
Skill '反馈'
    : auto(true)
    : event('伤害-目标-生效后', function (skill, damage)
        local from = damage.from
        if not from or not from:hasCard() then
            return
        end
        skill:tryCast(function ()
            local card = game:askCard(skill.owner, '反馈', { zone = from:getZones(), cancelable = false }).card
            if card then
                game:moveCard(card, skill.owner:getZone('手牌'))
            end
        end)
    end)
