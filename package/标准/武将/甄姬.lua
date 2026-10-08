-- 【甄姬】（标准版）：魏 · 女 · 体力上限 3

Hero '甄姬'
    : kingdom '魏'
    : sex '女'
    : hp(3)
    : skills { '洛神', '倾国' }

-- 【洛神】准备阶段开始时，你可以进行判定：若结果为黑色，判定牌生效后你获得之，然后你可以重复此流程。
Skill '洛神'
    : globalEvent('判定-后', function (skill, judge)
        local card = judge.card
        if judge.reason == '洛神' and card and card.color == '黑' then
            -- 判定牌还在这次判定的临时区里，趁收尾送弃牌之前搬进手牌
            skill:cast(function ()
                game:moveCard(card, skill.owner:getZone('手牌'))
            end)
        end
    end)
    : event('阶段-开始', function (skill, phase)
        if phase.name ~= '准备' then
            return
        end
        -- 上限 1000 次，防止答复不前进时死循环
        for _ = 1, 1000 do
            -- 每问一次就是一次发动：这次发动做的事 = 判定（判黑才算成功）
            local cast = skill:tryCast(function ()
                return game:judge(skill.owner, '洛神').card?.color == '黑'
            end)
            if not cast or not cast.result then
                break
            end
        end
    end)

-- 【倾国】你可以将一张黑色手牌当【闪】使用或打出。
Skill '倾国'
    : viewAs('闪', { condition = { color = '黑', zone = '手牌' } })
