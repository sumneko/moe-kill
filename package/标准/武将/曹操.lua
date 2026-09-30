-- 【曹操】（标准版）：魏 · 男 · 体力上限 4
-- 【奸雄】当你受到伤害后，你可以获得对你造成伤害的牌。

Hero '曹操'
    : kingdom '魏'
    : sex '男'
    : hp(4)
    : skills { '奸雄', '护驾' }

Skill '奸雄'
    : kind '被动'
    : on('被动', function (skill, host)
        local owner = skill.owner
        host:bindGC(owner:on('伤害-目标-结束', function (damage)
            local card = damage.card
            if not card then
                return
            end
            -- 不答 = 不发动
            if game:askChoice(owner, '奸雄', { '发动' }).choice ~= '发动' then
                return
            end
            game:moveCard(card, owner:getZone('手牌'))
        end))
    end)
