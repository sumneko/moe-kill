-- 开局：`'游戏-准备'` 里定身份与坐次、`'游戏-开始'` 里给主公加体力上限
-- 载荷可以带 `config.identities`（座位号 → 身份，**要么不给、要么给全**）与 `config.seats`（**按坐次给全**的一列玩家）
-- 顺序：**先按当前座位定身份 → 再排坐次**；坐次没给就洗一遍（经典洗牌，两两交换）再把主公换到 1 号位
-- 坐次给了就照它排（此时**不**保证主公在 1 号位 —— 允许让非主公玩家开第一回合）
game:on('游戏-准备', function (event)
    local config = event.config or {}
    local desk   = game.desk
    local count  = #desk.players

    -- ① 身份：给了就照给（要求给全、不再校验「身份配置」 —— 全是主公也接受）；没给才随机（1 号位 = 主公）
    local given = config.identities
    if given then
        for i = 1, count do
            local identity = given[i]
            assert(identity, '身份要给全：第 {} 个座位没给' % { i })
            desk:getPlayer(i):setIdentity(identity)
        end
    else
        local identityConfig = game:getValue('身份配置')
        local entries = assert(identityConfig and identityConfig[count], '身份配置里没有 {} 人局' % { count })

        ---@type 身份场.身份[]
        local pool = {}
        for _, entry in ipairs(entries) do
            local free = entry.count - (entry.identity == '主公' and 1 or 0)
            for _ = 1, free do
                pool[#pool + 1] = entry.identity
            end
        end
        assert(#pool == count - 1, '身份配置与 {} 人局对不上：除了主公还差 {} 个' % { count, #pool })
        game.random:shuffle(pool)

        for i = 2, count do
            desk:getPlayer(i):setIdentity(pool[i - 1])
        end
        desk:getPlayer(1):setIdentity('主公')
    end

    -- ② 坐次：给了就照它排（要求给全）；没给就洗一遍，最后把主公换到 1 号位
    local order = config.seats
    if order then
        assert(#order == count, '坐次要给全：{} 人局要给 {} 个' % { count, count })
        for i = 1, count do
            local wanted = order[i]
            if desk:getPlayer(i) ~= wanted then
                local index = assert(desk:getIndex(wanted), '坐次里有一位不在这局里')
                desk:swap(i, index)
            end
        end
        return
    end

    -- 经典洗牌：从后往前，每一步和随机一个座位交换
    for i = count, 2, -1 do
        desk:swap(i, game.random:nextInt(1, i))
    end
    -- 洗过之后主公不一定在 1 号位 ⇒ 换回来（没有主公就不管）
    for i = 1, count do
        if desk:getPlayer(i).identity == '主公' then
            if i ~= 1 then
                desk:swap(1, i)
            end
            break
        end
    end
end)

game:on('游戏-开始', function ()
    local lord  = game.desk.players[1]
    local bonus = game:getValue('主公额外体力') or 0
    if bonus ~= 0 then
        lord:addAttr('体力上限', bonus)
        lord:addAttr('体力', bonus)
    end
end)
