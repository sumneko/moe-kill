-- 伤害：扣体力；扣到 ≤0 就进濒死（时序上濒死早于 '伤害-后'）
game:on('伤害-生效', function (damage)
    local to = damage.to
    to:addAttr('体力', -damage.amount)
    if to:getAttr('体力') <= 0 then
        game:enterDying(to, damage)
    end
end)
