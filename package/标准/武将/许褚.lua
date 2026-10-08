-- 【许褚】（标准版）：魏 · 男 · 体力上限 4

Hero '许褚'
    : kingdom '魏'
    : sex '男'
    : hp(4)
    : skills { '裸衣' }

-- 一只「延时类状态」：本回合你使用【杀】或【决斗】造成的伤害 +1
-- 载在状态上而不是技能上 ⇒ 发动之后即使失去技能，这个效果照旧执行（规则集 Chapter1/Section2）
Buff '裸衣'
    : on('获得', function (buff)
        buff:bindGC(buff.owner:on('伤害-来源-生效前', function (damage)
            local name = damage.card?.name
            if name == '杀' or name == '决斗' then
                damage.amount = damage.amount + 1
            end
        end))
    end)

-- 【裸衣】摸牌阶段，你可以少摸一张牌，然后本回合你使用【杀】或【决斗】对目标角色造成伤害时，此伤害 +1。
Skill '裸衣'
    : event('阶段-开始', function (skill, phase)
        if phase.name ~= '摸牌' then
            return
        end
        skill:tryCast(function ()
            phase:bindGC(skill.owner:addAttr('摸牌数', -1))
            skill.owner.turn:bindGC(skill.owner:addBuff('裸衣'))
        end)
    end)
