-- 【吕蒙】（标准版）：吴 · 男 · 体力上限 4

Hero '吕蒙'
    : kingdom '吴'
    : sex '男'
    : hp(4)
    : skills { '克己' }

-- 【克己】若你未于出牌阶段内使用或打出过【杀】，你可以跳过弃牌阶段。
Skill '克己'
    : auto(true)
    : event('阶段-结束', function (skill, phase)
        if phase.name ~= '出牌' then
            return
        end
        if phase:getUseCount('杀') > 0 or phase:getPlayCount('杀') > 0 then
            return
        end
        skill:tryCast(function ()
            local turn = skill.owner.turn
            if turn then
                turn:skipPhase('弃牌')
            end
        end)
    end)
