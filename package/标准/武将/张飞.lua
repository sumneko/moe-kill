-- 【张飞】（标准版）：蜀 · 男 · 体力上限 4

Hero '张飞'
    : kingdom '蜀'
    : sex '男'
    : hp(4)
    : skills { '咆哮' }

-- 【咆哮】锁定技，出牌阶段，你使用【杀】无次数限制。
Skill '咆哮'
    : tags '锁定技'
    : on('被动', function (skill, host)
        host:bindGC(skill.owner:addLimit('杀', '出牌', 1000))
    end)
