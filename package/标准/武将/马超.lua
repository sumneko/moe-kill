-- 【马超】（标准版）：蜀 · 男 · 体力上限 4

Hero '马超'
    : kingdom '蜀'
    : sex '男'
    : hp(4)
    : skills { '马术', '铁骑' }

-- 【马术】锁定技，你与其他角色的距离 -1。
Skill '马术'
    : tags '锁定技'
    : on('被动', function (skill, host)
        host:bindGC(skill.owner:addAttr('进攻修正', -1))
    end)

-- 【铁骑】当你指定【杀】的目标后，你可以进行判定：若结果为红色，该角色不能使用【闪】响应此【杀】。
Skill '铁骑'
    : on('被动', function (skill, host)
        local owner = skill.owner
        host:bindGC(owner:on('卡牌-来源-指定目标后', function (useCard, target)
            if useCard.card.name ~= '杀' then
                return
            end
            skill:tryCast(function ()
                local judge = game:judge(owner, '铁骑')
                if judge.card?.color ~= '红' then
                    return
                end
                useCard:addUseOptions { unrespondable = target }
            end)
        end))
    end)
