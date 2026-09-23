game:on('效果-收尾', function (effect)
    local zone = effect.tempZone
    if zone and zone:count() > 0 then
        game:moveCard(zone:list(), '弃牌')
    end
end)
