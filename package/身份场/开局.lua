-- 开局：按人数把身份发下去（主公坐 1 号位）、给主公加体力上限
game:on('游戏-开始', function ()
    local seats  = game.desk.players
    local config = game:getValue('身份配置')
    local entries = assert(config and config[#seats], '身份配置里没有 {} 人局' % { #seats })

    local pool = {}
    for _, entry in ipairs(entries) do
        local count = entry.count - (entry.identity == '主公' and 1 or 0)
        for _ = 1, count do
            pool[#pool + 1] = entry.identity
        end
    end
    assert(#pool == #seats - 1, '身份配置与 {} 人局对不上：除了主公还差 {} 个人' % { #seats, #pool })
    game.random:shuffle(pool)

    for i = 2, #seats do
        seats[i]:setIdentity(pool[i - 1])
    end

    local lord = seats[1]
    lord:setIdentity('主公')

    local bonus = game:getValue('主公额外体力') or 0
    if bonus ~= 0 then
        lord:addAttr('体力上限', bonus)
        lord:addAttr('体力', bonus)
    end
end)
