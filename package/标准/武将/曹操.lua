-- 【曹操】（标准版）：魏 · 男 · 体力上限 4
-- 【奸雄】当你受到伤害后，你可以获得对你造成伤害的牌。

Hero '曹操'
    : kingdom '魏'
    : sex '男'
    : hp(4)
    : skills { '奸雄', '护驾' }

Skill '奸雄'
    : auto(true)
    : on('被动', function (skill, host)
        local owner = skill.owner
        host:bindGC(owner:on('伤害-目标-结束', function (damage)
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
