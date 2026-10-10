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

--- 开一个四人房（身份配置只认 4 / 5 / 8 人局）
---@param seed? integer
---@return Game
local function openRoom(seed)
    return moe.room.open {
        seats    = 4,
        seed     = seed or 1,
        packages = { '身份场', '标准' },
    }
end

--- 收摊：结束这一局（流程就地收掉）并断开连接（别再往两边发消息）
---@param game Game
---@param clients Client[]
local function close(game, clients)
    game:endGame { side = '平局', reason = '用例收摊' }
    for _, client in ipairs(clients) do
        client:close('用例收摊')
    end
end

--- 把已经排队的消息跑完（否则会漏到后面的用例里）
---@async
local function drain()
    for _ = 1, 3 do
        moe.await.sleep(0)
    end
end

---@async
lt.test('房间：客户端坐进来就拿到自己的快照', function ()
    local game = openRoom()
    local front, back = connect()

    local result, err = front:awaitRequest('Game.Join', { name = '甲' })
    lt.assertEquals('没出错', nil, err)
    lt.assertEquals('只带自己一个玩家', 1, #result.players)
    lt.assertEquals('名字带上了', '甲', result.players[1].base.userName)
    lt.assertEquals('坐上 1 号位', 1, result.players[1].base.seat)
    lt.assertEquals('牌列表也在（开局前是空的）', true, result.cards ~= nil)
    lt.assertEquals('还没开局：牌堆里只有老底', true, game.turnPlayer == nil)
    close(game, { front, back })
    drain()
end)

---@async
lt.test('房间：坐满就开局', function ()
    local game = openRoom()
    ---@type Client[]
    local clients = {}
    ---@type Client[]
    local fronts = {}
    for i = 1, 4 do
        local front, back = connect()
        fronts[i]  = front
        clients[#clients + 1] = front
        clients[#clients + 1] = back
    end

    local first = assert(fronts[1]):awaitRequest('Game.Join', { name = '甲' })
    lt.assertEquals('第一个进来还没开局', nil, game.turnPlayer)
    for i = 2, 4 do
        assert(fronts[i]):awaitRequest('Game.Join')
    end
    moe.await.sleep(0)

    lt.assertEquals('四个座位都有人', 4, #game.desk.players)
    lt.assertEquals('身份都定了', true, game.desk.players[1].identity ~= nil)
    lt.assertEquals('轮次挂上了', true, game.turnPlayer ~= nil)
    lt.assertEquals('第一个进来那份只有自己', 1, #first.players)
    close(game, clients)
    drain()
end)

---@async
lt.test('房间：坐满了再进来要不到位置', function ()
    local game = openRoom()
    ---@type Client[]
    local clients = {}
    ---@type Client[]
    local fronts = {}
    for i = 1, 5 do
        local front, back = connect()
        fronts[i] = front
        clients[#clients + 1] = front
        clients[#clients + 1] = back
    end
    for i = 1, 4 do
        assert(fronts[i]):awaitRequest('Game.Join', { name = '玩家' .. i })
    end
    moe.await.sleep(0)

    lt.expectErrors(1)
    local result, err = assert(fronts[5]):awaitRequest('Game.Join', { name = '丙' })
    lt.assertEquals('没有结果', nil, result)
    lt.assertEquals('回了错误码', moe.jsonrpc.INTERNAL_ERROR, assert(err).code)
    close(game, clients)
    drain()
end)
