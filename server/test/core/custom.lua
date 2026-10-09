local lt = require 'test.ltest'

---@param count integer
---@return Player[] # 按座位号升序
local function newPlayers(count)
    local game = moe.game.create {
        seats   = count,
        random  = moe.random.create(1),
        sources = { lt.cardSource },
    }
    local desk = game.desk
    local attributeSystem = game:getAttributeSystem()
    ---@type Player[]
    local players = {}
    for i = 1, count do
        local player = moe.player.create(game, { attributes = attributeSystem:createInstance() })
        desk:sit(i, player)
        players[i] = player
    end
    return players
end

lt.test('容器：写进去读得出来', function ()
    local players = newPlayers(1)
    local player = assert(players[1])

    player.custom.proxy.heroName = '刘备'
    lt.assertEquals('读得到', '刘备', player.custom.proxy.heroName)
    lt.assertEquals('底层表里也有', '刘备', assert(player.custom.raw).heroName)
    lt.assertEquals('没写过的键是空', nil, player.custom.proxy.identity)
end)

lt.test('容器：默认只有自己看得见', function ()
    local players = newPlayers(2)
    local a = assert(players[1])
    local b = assert(players[2])
    a.custom.proxy.heroName = '刘备'

    lt.assertEquals('自己看得见', true, a.custom:isVisible('heroName', a))
    lt.assertEquals('别人看不见', false, a.custom:isVisible('heroName', b))
end)

lt.test('容器：设了可见性就按它来', function ()
    local players = newPlayers(3)
    local a = assert(players[1])
    local b = assert(players[2])
    local c = assert(players[3])
    a.custom.proxy.heroName = '刘备'

    a.custom:setVisible('heroName', true)
    lt.assertEquals('所有人都看得见', true, a.custom:isVisible('heroName', b))
    lt.assertEquals('自己当然也看得见', true, a.custom:isVisible('heroName', a))

    a.custom:setVisible('heroName', { b })
    lt.assertEquals('点名的人看得见', true, a.custom:isVisible('heroName', b))
    lt.assertEquals('没点名的看不见', false, a.custom:isVisible('heroName', c))

    a.custom:setVisible('heroName', function (player)
        return player == c
    end)
    lt.assertEquals('谓词逐人现算', true, a.custom:isVisible('heroName', c))
    lt.assertEquals('谓词不认的人还是看不见', false, a.custom:isVisible('heroName', b))
end)

lt.test('容器：按视角挑出看得见的那些键', function ()
    local players = newPlayers(2)
    local a = assert(players[1])
    local b = assert(players[2])
    a.custom.proxy.heroName = '刘备'
    a.custom.proxy.identity = '主公'
    a.custom:setVisible('heroName', true)

    local mine = a.custom:allVisibles(a)
    lt.assertEquals('自己看得见武将名', '刘备', mine.heroName)
    lt.assertEquals('自己也看得见身份', '主公', mine.identity)

    local others = a.custom:allVisibles(b)
    lt.assertEquals('别人看得见武将名', '刘备', others.heroName)
    lt.assertEquals('别人看不见身份', nil, others.identity)
end)

lt.test('容器：没写过的键，谁问都是空表', function ()
    local players = newPlayers(2)
    local a = assert(players[1])
    local b = assert(players[2])

    lt.assertEquals('自己也没有', nil, a.custom:allVisibles(a).heroName)
    lt.assertEquals('别人更没有', nil, a.custom:allVisibles(b).heroName)
end)

lt.test('容器：写键会被 hook 看到', function ()
    local players = newPlayers(1)
    local player = assert(players[1])
    ---@type string?
    local seenKey
    ---@type any
    local seenValue
    player.custom.hook = function (key, value)
        seenKey   = key
        seenValue = value
    end

    player.custom.proxy.heroName = '刘备'
    lt.assertEquals('键传进来了', 'heroName', seenKey)
    lt.assertEquals('值传进来了', '刘备', seenValue)

    player.custom.proxy.heroName = '曹操'
    lt.assertEquals('再写一次照样通知', '曹操', seenValue)
end)
