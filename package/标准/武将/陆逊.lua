-- 【陆逊】（标准版）：吴 · 男 · 体力上限 3

Hero '陆逊'
    : kingdom '吴'
    : sex '男'
    : hp(3)
    : skills { '谦逊', '连营' }

-- 【谦逊】锁定技，你不能被选择为【顺手牵羊】与【乐不思蜀】的目标。
Skill '谦逊'
    : tags '锁定技'
    : event('卡牌-目标-能否指定', function (skill, plan)
        local name = plan.card.name
        if name == '顺手牵羊' or name == '乐不思蜀' then
            return '谦逊'
        end
    end)

-- 【连营】当你失去手牌后，若你没有手牌，你可以摸一张牌。
Skill '连营'
    : auto(true)
    : event('卡牌-离开区域', function (skill, card, zone)
        local owner = skill.owner
        -- 只有「我的手牌离开」才算失去手牌；目的地不看（被拿走 / 给出 / 使用 / 打出 / 弃置都算）
        if zone ~= owner:getZone('手牌') then
            return
        end
        -- 一次搬空手牌时内核先摘完再逐张发事件 ⇒ 第一张触发摸牌后手牌就不再为空，不会重复发动
        if owner:getZone('手牌'):count() > 0 then
            return
        end
        skill:tryCast(function ()
            owner:draw(1)
        end)
    end)
