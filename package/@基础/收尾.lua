-- 效果收尾：把临时处理区里剩下的牌送进弃牌堆
game:on('效果-收尾', function (effect)
    local zone = effect.tempZone
    if zone and zone:count() > 0 then
        game:moveCard(zone:list(), '弃牌')
    end
end)
