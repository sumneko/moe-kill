Depends { '../基础' }

game:on('游戏-开始', function ()
    local seats  = game.desk.players
    local config = game:getValue('身份配置')
    local entries = config and config[#seats]
    if not entries then
        error('身份配置里没有 {} 人局' % { #seats })
    end

    local pool = {}
    for _, entry in ipairs(entries) do
        local count = entry.count - (entry.identity == '主公' and 1 or 0)
        for _ = 1, count do
            pool[#pool + 1] = entry.identity
        end
    end
    if #pool ~= #seats - 1 then
        error('身份配置与 {} 人局对不上：除了主公还差 {} 个人' % { #seats, #pool })
    end
    game.random:shuffle(pool)

    for i = 2, #seats do
        seats[i]:setTag('身份', pool[i - 1])
    end

    local lord = seats[1]
    lord:setTag('身份', '主公')

    local bonus = game:getValue('主公额外体力') or 0
    if bonus ~= 0 then
        lord:addAttr('体力上限', bonus)
        lord:addAttr('体力', bonus)
    end
end)
