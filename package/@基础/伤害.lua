game:on('伤害-生效', function (damage)
    damage.to:addAttr('体力', -damage.amount)
end)
