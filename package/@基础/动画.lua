-- 给客户端播动画的节拍（服务器让出时间，客户端才有机会把这一段播出来）

game:on('卡牌-答复', function (askCard)
    if askCard.kind == 'askPlayCard' then
        game:animSleep(1)
    end
end)
