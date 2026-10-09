-- 【郭嘉】（标准版）：魏 · 男 · 体力上限 3

Hero '郭嘉'
    : kingdom '魏'
    : sex '男'
    : hp(3)
    : skills { '天妒', '遗计' }

-- 【天妒】当你的判定牌生效后，你可以获得之。
Skill '天妒'
    : auto(true)
    : event('判定-后', function (skill, judge)
        local card = judge.card
        if not card then
            return
        end
        skill:tryCast(function ()
            -- 判定牌还在这次判定的临时区里，趁收尾送弃牌之前搬进手牌
            game:moveCard(card, skill.owner:getZone('手牌'))
        end)
    end)

-- 【遗计】当你受到 1 点伤害后，你可以观看牌堆顶的两张牌并任意分配它们。
Skill '遗计'
    : auto(true)
    : event('伤害-目标-生效后', function (skill, damage)
        -- 「1 点伤害」是粒度 ⇒ 受 N 点就发动 N 轮
        for _ = 1, damage.amount do
            skill:tryCast(function (cast)
                -- 观看 = 抽到自己这轮的临时区；可见性只给他（分完 / 取消后不会剩牌）
                local shown = cast:getTempZone()
                shown:setVisible(skill.owner)
                game:drawCards(skill.owner, 2, shown)
                -- 上限 1000 次，防止答复不前进时死循环
                for _ = 1, 1000 do
                    if shown:count() == 0 then
                        break
                    end
                    local ask = game:askCardWithTarget(skill.owner, '遗计', {
                        card = {
                            zone = shown,
                            min  = 1,
                            max  = shown:count(),
                        },
                    })
                    if #ask.cards == 0 then
                        -- 取消 = 剩下的全归自己
                        game:moveCard(shown:list(), skill.owner:getZone('手牌'))
                        break
                    end
                    game:moveCard(ask.cards, assert(ask.target):getZone('手牌'))
                end
            end)
        end
    end)
