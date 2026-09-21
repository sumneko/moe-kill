game:on('回复-生效', function (heal)
    heal.to:addAttr('体力', heal.amount)
end)
