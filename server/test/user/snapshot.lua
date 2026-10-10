local lt = require 'test.ltest'

--- 造一对对接好、都起了读循环的客户端
---@return Client # 前端侧
---@return Client # 后端侧
local function connect()
    local a, b = moe.link.pair()
    local front = moe.client.create(a)
    local back  = moe.client.create(b)
    front:start()
    back:start()
    return front, back
end

--- 搭一个两人局：每人坐好、都接了客户端并接入下行（外壳那步由用例代劳）
---@return Game
---@return Player[]
---@return Client[] # 前端侧（用例拿它发请求）
local function newGame()
    local game = moe.game.create {
        seats   = 2,
        random  = moe.random.create(1),
        sources = { lt.cardSource },
    }
    ---@type Player[]
    local players = {}
    ---@type Client[]
    local fronts = {}
    for i = 1, 2 do
        local player = moe.player.create(game, { attributes = game:getAttributeSystem():createInstance() })
        local front, back = connect()
        game.desk:sit(i, player)
        player:setUser(New 'ClientUser' (game, back))
        assert(player.user):attach()
        players[i] = player
        fronts[i]  = front
    end
    moe.snapshot.attach(game)
    return game, players, fronts
end

---@async
lt.test('快照：要一份整局快照（牌 + 玩家）', function ()
    local game, players, fronts = newGame()
    local me  = assert(players[1])
    local you = assert(players[2])

    game:getZone('弃牌'):accept(game:createCard('闪'))
    me.custom.proxy.heroName = '刘备'
    me.custom:setVisible('heroName', true)
    you.custom.proxy.heroName = '曹操'
    -- 让下一笔调度把增量发完，账里才有那张牌
    moe.await.sleep(0)

    local result, err = assert(fronts[1]):awaitRequest('Game.SnapShot')
    lt.assertEquals('没出错', nil, err)

    lt.assertEquals('两个玩家都在', 2, #result.players)
    lt.assertEquals('第一个是自己', me.id, result.players[1].base.id)
    lt.assertEquals('座位号对得上', 1, result.players[1].base.seat)
    lt.assertEquals('公开的自定义数据带上了', '刘备', result.players[1].custom.heroName)
    lt.assertEquals('别人没公开的不带', nil, result.players[2].custom.heroName)

    lt.assertEquals('牌也带上了', 1, #result.cards)
    lt.assertEquals('牌面在', '闪', assert(result.cards[1].face).name)
    lt.assertEquals('区域是弃牌堆', '弃牌', assert(result.cards[1].zone).name)
end)

---@async
lt.test('快照：各人看到的自定义数据不一样', function ()
    local _, players, fronts = newGame()
    local me = assert(players[1])
    me.custom.proxy.heroName = '刘备'

    local mine,  mineErr  = assert(fronts[1]):awaitRequest('Game.SnapShot')
    local yours, yoursErr = assert(fronts[2]):awaitRequest('Game.SnapShot')
    lt.assertEquals('自己没出错', nil, mineErr)
    lt.assertEquals('别人也没出错', nil, yoursErr)
    lt.assertEquals('自己看得见', '刘备', mine.players[1].custom.heroName)
    lt.assertEquals('别人看不见', nil, yours.players[1].custom.heroName)
end)

---@async
lt.test('快照：还没入座的连接要不到', function ()
    newGame()
    -- 「哪条连接没入座」是服务端自己知道的错：进日志、不回给客户端
    lt.expectErrors(1)
    local front = select(1, connect())
    local result, err = front:awaitRequest('Game.SnapShot')
    lt.assertEquals('没有结果', nil, result)
    lt.assertEquals('回了错误码', moe.jsonrpc.INTERNAL_ERROR, assert(err).code)
    lt.assertEquals('错在哪只进日志，线上只说「处理出错」', '处理这个方法时出错', err.message)
end)
