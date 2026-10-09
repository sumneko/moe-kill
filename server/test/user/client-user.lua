local lt = require 'test.ltest'

--- 收消息的登记台（用例自己收，不摸内部字节）
---@param method string
---@return any[] # 收到的那些载荷
---@return fun() # 撤销登记
local function collect(method)
    local got = {}
    local undo = moe.client.register(method, function (_, params)
        got[#got + 1] = params
    end)
    return got, undo
end

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

---@param count integer
---@return Game
local function newGame(count)
    return moe.game.create {
        seats   = count,
        random  = moe.random.create(1),
        sources = { lt.cardSource },
    }
end

--- 造一个还没坐下的玩家
---@param game Game
---@return Player
local function newPlayer(game)
    return moe.player.create(game, { attributes = game:getAttributeSystem():createInstance() })
end

---@async
lt.test('ClientUser：坐下之后收到 Player.Update', function ()
    local _, back = connect()
    local got, undo = collect('Player.Update')
    local game = newGame(2)
    local player = newPlayer(game)
    player:setUser(New 'ClientUser' (back))

    game.desk:sit(1, player)
    moe.await.sleep(0)

    lt.assertEquals('收到一条', 1, #got)
    undo()
    local players = got[1].players
    lt.assertEquals('一条里一个玩家', 1, #players)
    lt.assertEquals('就是刚坐下的那个', player.id, players[1].id)
    lt.assertEquals('用户名（没给就是空串）', '', players[1].userName)
    lt.assertEquals('座位号', 1, players[1].seat)
end)

---@async
lt.test('ClientUser：改 custom 收到 Player.UpdateCustom', function ()
    local _, back = connect()
    local got, undo = collect('Player.UpdateCustom')
    local game = newGame(2)
    local player = newPlayer(game)
    player:setUser(New 'ClientUser' (back))
    game.desk:sit(1, player)
    moe.await.sleep(0)

    player.custom.proxy.heroName = '刘备'
    moe.await.sleep(0)

    lt.assertEquals('收到一条', 1, #got)
    undo()
    lt.assertEquals('发给哪个玩家的', player.id, got[1].id)
    lt.assertEquals('字段跟过来了', '刘备', got[1].custom.heroName)
end)

---@async
lt.test('ClientUser：同一笔调度里写几次也只发一条', function ()
    local _, back = connect()
    local got, undo = collect('Player.UpdateCustom')
    local game = newGame(2)
    local player = newPlayer(game)
    player:setUser(New 'ClientUser' (back))
    game.desk:sit(1, player)
    moe.await.sleep(0)

    player.custom.proxy.heroName = '刘备'
    player.custom.proxy.identity = '主公'
    moe.await.sleep(0)

    lt.assertEquals('只发了一条', 1, #got)
    undo()
    lt.assertEquals('两个字段都在同一条里', '主公', got[1].custom.identity)
    lt.assertEquals('先写的也在', '刘备', got[1].custom.heroName)
end)

---@async
lt.test('ClientUser：发过就清了，不会重复发', function ()
    local _, back = connect()
    local got, undo = collect('Player.UpdateCustom')
    local game = newGame(2)
    local player = newPlayer(game)
    player:setUser(New 'ClientUser' (back))
    game.desk:sit(1, player)
    moe.await.sleep(0)

    player.custom.proxy.heroName = '刘备'
    moe.await.sleep(0)
    lt.assertEquals('发了一条', 1, #got)
    undo()

    moe.await.sleep(0)
    lt.assertEquals('再空转也不会重发', 1, #got)
end)

---@async
lt.test('ClientUser：别人只看得到公开字段', function ()
    local _, back = connect()
    local got, undo = collect('Player.UpdateCustom')
    local game = newGame(2)
    local a = newPlayer(game)
    local b = newPlayer(game)
    game.desk:sit(1, a)
    game.desk:sit(2, b)
    b:setUser(New 'ClientUser' (back))
    moe.await.sleep(0)

    a.custom.proxy.heroName = '刘备'
    a.custom:setVisible('heroName', true)
    a.custom.proxy.identity = '主公'
    moe.await.sleep(0)

    lt.assertEquals('收到一条', 1, #got)
    undo()
    lt.assertEquals('是 a 的 custom', a.id, got[1].id)
    lt.assertEquals('公开字段看得见', '刘备', got[1].custom.heroName)
    lt.assertEquals('隐藏字段看不见', nil, got[1].custom.identity)
end)

---@async
lt.test('ClientUser：没有 User 的玩家不下发', function ()
    local _, back = connect()
    local got, undo = collect('Player.UpdateCustom')
    local game = newGame(2)
    local a = newPlayer(game)
    local b = newPlayer(game)
    game.desk:sit(1, a)
    game.desk:sit(2, b)
    moe.await.sleep(0)

    a.custom.proxy.heroName = '刘备'
    moe.await.sleep(0)

    lt.assertEquals('谁也没收到', 0, #got)
    undo()
end)