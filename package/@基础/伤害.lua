game:on('伤害-生效', function (damage)
    local to = damage.to
    to:addAttr('体力', -damage.amount)
    if to:getAttr('体力') <= 0 then
        game:enterDying(to, damage)
    end
end)
