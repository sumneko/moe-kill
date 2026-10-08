-- 【黄盖】（标准版）：吴 · 男 · 体力上限 4

Hero '黄盖'
    : kingdom '吴'
    : sex '男'
    : hp(4)
    : skills { '苦肉' }

-- 【苦肉】出牌阶段，你可以失去 1 点体力，然后摸两张牌。
Skill '苦肉'
    : on('使用', function (cast)
        local owner = cast.from
        owner:loseHp(1)
        if owner:isAlive() then
            owner:draw(2)
        end
    end)
