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

--- 跑到条件成立为止（开局是延后一笔调度才跑的，流程又要好几笔调度才走到第一个回合）
---@async
---@param check fun(): boolean
local function spinUntil(check)
    for _ = 1, 200 do
        if check() then
            return
        end
        moe.await.sleep(0)
    end
    error('等了 200 笔调度还没等到')
end

---@async
lt.test('房间：客户端坐进来就拿到自己的快照', function ()
    local game = openRoom()
    local front, back = connect()

    local result, err = front:awaitRequest('Game.Join', { name = '甲' })
    lt.assertEquals('没出错', nil, err)
    assert(result, '没拿到快照')
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

    -- 选将要有人答，流程才走得下去（跟 flow-sync 那条「真跑一局」同一招）
    local _ <close> = moe.client.register('Ask.Hero', function (_, params)
        return { heroes = { params.heroes[1] } }
    end)

    local first = assert(fronts[1]):awaitRequest('Game.Join', { name = '甲' })
    lt.assertEquals('第一个进来还没开局', nil, game.turnPlayer)
    local last
    for i = 2, 4 do
        last = assert(fronts[i]):awaitRequest('Game.Join', {})
    end
    spinUntil(function () return game.turnPlayer ~= nil end)

    lt.assertEquals('四个座位都有人', 4, #game.desk.players)
    lt.assertEquals('身份都定了', true, game.desk.players[1].custom.identity ~= nil)
    lt.assertEquals('轮次挂上了', true, game.turnPlayer ~= nil)
    lt.assertEquals('坐满那一下最后进来的那位也拿到快照', 4, #assert(last).players)
    assert(first, '没拿到快照')
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

    local result, err = assert(fronts[5]):awaitRequest('Game.Join', { name = '丙' })
    lt.assertEquals('没有结果', nil, result)
    lt.assertEquals('错误码', moe.jsonrpc.INVALID_REQUEST, assert(err).code)
    lt.assertEquals('错在哪说清楚', '座位已经坐满', assert(err).message)
    close(game, clients)
    drain()
end)

---@async
lt.test('房间：还没开局就坐进来 ⇒ 回具体的错误', function ()
    local saved = moe.room._game
    moe.room._game = nil

    local front, back = connect()
    local result, err = front:awaitRequest('Game.Join', {})

    moe.room._game = saved
    lt.assertEquals('没有结果', nil, result)
    lt.assertEquals('错误码', moe.jsonrpc.INVALID_REQUEST, assert(err).code)
    lt.assertEquals('错在哪说清楚', '还没有开局', assert(err).message)
    front:close('用例收摊')
    back:close('用例收摊')
    drain()
end)

---@async
lt.test('房间：有人坐进来就广播房间状态', function ()
    local game = openRoom()
    local front, back = connect()

    ---@type Proto.Notify.Room.Update?
    local got = nil
    local _ <close> = moe.client.register('Room.Update', function (_, params)
        ---@cast params Proto.Notify.Room.Update
        got = params
    end)

    local result, err = front:awaitRequest('Game.Join', { name = '甲' })
    lt.assertEquals('没出错', nil, err)
    assert(result, '没拿到快照')
    lt.assertEquals('快照里知道自己是谁', result.players[1].base.id, result.me)

    drain()
    lt.assertEquals('收到房间状态', 4, assert(got, '没收到房间状态').seats)
    lt.assertEquals('已经坐了一个', 1, #assert(got).players)
    lt.assertEquals('报的是那个人的名字', '甲', assert(got).players[1].userName)

    close(game, { back })
    drain()
end)

---@async
lt.test('重开：原班人马重坐、配置与包沿用、种子另取', function ()
    local game = openRoom(7)
    ---@type Client[]
    local clients = {}
    ---@type Client[]
    local fronts = {}
    for i = 1, 4 do
        local front, back = connect()
        fronts[i] = front
        clients[#clients + 1] = front
        clients[#clients + 1] = back
    end
    -- 重开后新局会自动开局，选将得有人答
    local _ <close> = moe.client.register('Ask.Hero', function (_, params)
        return { heroes = { params.heroes[1] } }
    end)
    for i = 1, 4 do
        assert(fronts[i]):awaitRequest('Game.Join', { name = '玩家' .. i })
    end
    spinUntil(function () return game.turnPlayer ~= nil end)

    game:endGame { side = '平局', reason = '用例收摊' }
    local result, err = assert(fronts[1]):awaitRequest('Game.Restart', {})
    lt.assertEquals('没出错', nil, err)
    lt.assertEquals('收条是一张表', 'table', type(result))

    local next = assert(moe.room._game, '没接上新局')
    lt.assertNotEquals('换了一局', game, next)
    lt.assertEquals('座位数沿用', 4, next.desk:getCount())
    lt.assertEquals('包清单沿用', '身份场,标准', table.concat(next.list, ','))
    lt.assertEquals('包来源沿用', table.concat(game.sources, ','), table.concat(next.sources, ','))
    lt.assertEquals('种子另取（上一局 + 1）', 8, moe.room._seed)
    ---@type table<string, true>
    local seenName = {}
    for i = 1, 4 do
        local before = assert(game.desk:getPlayer(i)):getName()
        local after  = assert(next.desk:getPlayer(i)):getName()
        lt.assertEquals('座位 ' .. i .. ' 还是原来那个人', before, after)
        local name = assert(after, '座位 ' .. i .. ' 上没人')
        lt.assertEquals('一个座位一个人（名字不重复）', nil, seenName[name])
        seenName[name] = true
    end

    spinUntil(function () return next.turnPlayer ~= nil end)
    lt.assertEquals('新局跑起来了（身份都定了）', true, next.desk.players[1].custom.identity ~= nil)

    close(next, clients)
    drain()
end)

---@async
lt.test('重开：这一局还没结束就重开 ⇒ 回错且什么都没改', function ()
    local game = openRoom()
    local front, back = connect()
    assert(front:awaitRequest('Game.Join', { name = '甲' }))

    local result, err = front:awaitRequest('Game.Restart', {})
    lt.assertEquals('没有结果', nil, result)
    lt.assertEquals('错误码', moe.jsonrpc.INVALID_REQUEST, assert(err).code)
    lt.assertEquals('错在哪说清楚', '这一局还没结束', assert(err).message)
    lt.assertEquals('还是原来那一局', game, moe.room._game)
    lt.assertEquals('种子没动', 1, moe.room._seed)

    close(game, { front, back })
    drain()
end)

---@async
lt.test('重开：每条连接各收到一条 Game.Restarted，各自认自己的座位', function ()
    local game = openRoom()
    ---@type Client[]
    local clients = {}
    ---@type Client[]
    local fronts = {}
    for i = 1, 4 do
        local front, back = connect()
        fronts[i] = front
        clients[#clients + 1] = front
        clients[#clients + 1] = back
    end

    local _ <close> = moe.client.register('Ask.Hero', function (_, params)
        return { heroes = { params.heroes[1] } }
    end)
    ---@type table<Client, Proto.SnapShot>
    local got = {}
    local _ <close> = moe.client.register('Game.Restarted', function (client, params)
        ---@cast params Proto.SnapShot
        got[client] = params
    end)

    for i = 1, 4 do
        assert(fronts[i]):awaitRequest('Game.Join', { name = '玩家' .. i })
    end

    game:endGame { side = '平局', reason = '用例收摊' }
    local _, err = assert(fronts[1]):awaitRequest('Game.Restart', {})
    lt.assertEquals('重开没出错', nil, err)
    drain()

    ---@type table<integer, true>
    local seenSeat = {}
    local seatCount = 0
    for i = 1, 4 do
        local snapshot = got[fronts[i]]
        lt.assertNotEquals('第 ' .. i .. ' 条连接收到快照', nil, snapshot)
        lt.assertEquals('快照里人人都在', 4, #assert(snapshot).players)
        local me = assert(snapshot).me
        lt.assertNotEquals('知道自己是哪个座位', nil, me)
        if not seenSeat[assert(me)] then
            seenSeat[assert(me)] = true
            seatCount = seatCount + 1
        end
    end
    lt.assertEquals('四条连接各认一个不同的座位（按各自视角裁过）', 4, seatCount)

    close(assert(moe.room._game), clients)
    drain()
end)
