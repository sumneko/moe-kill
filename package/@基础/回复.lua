-- 回复：加体力（受上限约束）；体力回到正数就脱离濒死
game:on('回复-生效', function (heal)
    local to = heal.to
    to:addAttr('体力', heal.amount)
    local dying = game:getDying(to)
    if dying and to:getAttr('体力') > 0 then
        dying:leave()
    end
end)
