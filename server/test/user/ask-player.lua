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

--- 搭一个两人局：每人坐好、都接了客户端并接入下行
---@return Game
---@return Player[]
---@return Client[] # 后端侧（前端那半由用例自己收／答）
local function newGame()
    local game = moe.game.create {
        seats   = 2,
        random  = moe.random.create(1),
        sources = { lt.cardSource },
    }
    ---@type Player[]
    local players = {}
    ---@type Client[]
    local backs = {}
    for i = 1, 2 do
        local player = moe.player.create(game, { attributes = game:getAttributeSystem():createInstance() })
        local _, back = connect()
        game.desk:sit(i, player)
        player:setUser(New 'ClientUser' (game, back))
        assert(player.user):attach()
        players[i] = player
        backs[i]   = back
    end
    return game, players, backs
end

--- 替「他」答应答（注册一次，返回撤销函数；收尾写 `local _ <close> = reply(...)` 就行）
---@param answer fun(params: Proto.Request.Ask.Select): Proto.Result.Ask.Select?
---@return fun()
local function reply(answer)
    return moe.client.register('Ask.Select', function (_, params)
        ---@cast params Proto.Request.Ask.Select
        return answer(params)
    end)
end

---@async
lt.test('询问：要角色时问客户端，回包的 id 转回 Player', function ()
    local game, players = newGame()
    local me  = assert(players[1])
    local you = assert(players[2])

    ---@type Proto.Request.Ask.Select?
    local sent = nil
    local _ <close> = reply(function (params)
        sent = params
        return { player = { you.id } }
    end)

    local ask = moe.askPlayer.create {
        game      = game,
        to        = me,
        reason    = '突袭',
        condition = { player = you },
    }
    ask:apply():await()

    local params = assert(sent, '没问过客户端')
    lt.assertEquals('缘由原样带过去', '突袭', params.reason)
    local condition = assert(params.player, '该带上角色条件')
    lt.assertEquals('候选就一个', 1, #condition.ids)
    lt.assertEquals('候选是他', you.id, condition.ids[1])
    lt.assertEquals('个数区间带上了', 1, condition.min)
    lt.assertEquals('区间上限同默认', 1, condition.max)
    lt.assertEquals('可取消的请求带着号', true, params.cancelToken ~= nil)
    lt.assertEquals('这次成了', true, ask.success)
    lt.assertEquals('答复是他', you, ask.player)
end)

---@async
lt.test('询问：不限候选时把存活角色都列出来', function ()
    local game, players = newGame()
    local me = assert(players[1])

    local seen = 0
    local _ <close> = reply(function (params)
        seen = #assert(params.player).ids
        return { player = {} }
    end)

    local ask = moe.askPlayer.create {
        game   = game,
        to     = me,
        reason = '随便挑',
        condition = { min = 0, max = 1 },
    }
    ask:apply():await()

    lt.assertEquals('存活的两个都列出来了', 2, seen)
    lt.assertEquals('一个都不选也是合法答复', true, ask.success)
    lt.assertEquals('没选人', nil, ask.player)
end)

---@async
lt.test('询问：回包里的 id 不认 ⇒ 这次不算成立', function ()
    local game, players = newGame()
    local me = assert(players[1])

    local _ <close> = reply(function ()
        return { player = { 9999 } }
    end)

    local ask = moe.askPlayer.create {
        game   = game,
        to     = me,
        reason = '乱答',
        condition = { min = 0, max = 1 },
    }
    ask:apply():await()

    lt.assertEquals('这次没成', false, ask.success)
    lt.assertEquals('原因里说清楚了', true, tostring(ask.err):match('不在这一局里') ~= nil)
end)

---@async
lt.test('询问：客户端那边出错 ⇒ 就是答不出来（业务层不问原因）', function ()
    local game, players = newGame()
    local me = assert(players[1])

    lt.expectErrors(1)
    local _ <close> = moe.client.register('Ask.Select', function ()
        error('客户端自己炸了')
    end)

    local ask = moe.askPlayer.create {
        game      = game,
        to        = me,
        reason    = '测试',
        condition = { player = players[2] },
    }
    ask:apply():await()

    lt.assertEquals('这次不算成立', false, ask.success)
    lt.assertEquals('没拿到答复', nil, ask.player)
end)

---@async
lt.test('请求：宿主被收掉 ⇒ 叫停客户端，等待按「请求被取消」收', function ()
    local game, players = newGame()
    local user = assert(assert(players[1]).user)
    ---@cast user ClientUser

    ---@type integer?
    local token = nil
    ---@type Proto.Notify.Cancel?
    local stopped = nil
    local _ <close> = moe.client.register('Ask.Select', function (_, params)
        ---@cast params Proto.Request.Ask.Select
        token = params.cancelToken
        moe.await.sleep(10)
    end)
    local _ <close> = moe.client.register('Cancel', function (_, params)
        ---@cast params Proto.Notify.Cancel
        stopped = params
    end)

    local host    = moe.gc.host()
    local request = user:request('Ask.Select', {}, host)
    moe.await.sleep(0)
    lt.assertEquals('请求带上了取消号', true, token ~= nil)

    Delete(host)

    lt.assertEquals('叫停的正是那一次请求', token, assert(stopped, '该叫停客户端').cancelToken)
    local result, err = request:await()
    lt.assertEquals('没结果', nil, result)
    local canceled = assert(err, '该以失败收尾')
    lt.assertEquals('按「请求被取消」收', -1, canceled.code)
    lt.assertEquals('原因照协议写', 'request canceled', canceled.message)
    lt.assertEquals('任务没收掉：还等着那一包', true, IsValid(request))
end)

---@async
lt.test('请求：取消之后回包才到 ⇒ 结果不会被改回来', function ()
    local game, players = newGame()
    local user = assert(assert(players[1]).user)
    ---@cast user ClientUser

    ---@type fun()?
    local resumeAnswer = nil
    local _ <close> = moe.client.register('Ask.Select', function ()
        moe.await.yield(function (resume)
            resumeAnswer = resume
        end)
        return { player = {} }
    end)

    local host    = moe.gc.host()
    local request = user:request('Ask.Select', {}, host)
    moe.await.sleep(0)

    Delete(host)
    local _, err = request:await()
    lt.assertEquals('先按取消收', -1, assert(err).code)

    assert(resumeAnswer, '客户端还没收到请求')()
    moe.await.sleep(0)

    local _, again = request:await()
    lt.assertEquals('回包到达也改不回来', -1, assert(again).code)
    lt.assertEquals('那条账照常被回包清掉', false, IsValid(request))
end)

---@async
lt.test('请求：已经拿到结果就不叫停（收掉宿主也不发 Cancel）', function ()
    local game, players = newGame()
    local user = assert(assert(players[1]).user)
    ---@cast user ClientUser

    ---@type Proto.Notify.Cancel?
    local stopped = nil
    local _ <close> = moe.client.register('Cancel', function (_, params)
        ---@cast params Proto.Notify.Cancel
        stopped = params
    end)
    local _ <close> = moe.client.register('Ask.Select', function ()
        return { player = {} }
    end)

    local host    = moe.gc.host()
    local request = user:request('Ask.Select', {}, host)
    local result, err = request:await()
    lt.assertEquals('拿到了结果', 0, #(assert(result).player or {}))
    lt.assertEquals('没失败', nil, err)

    Delete(host)

    lt.assertEquals('结果已经定下 ⇒ 不叫停客户端', nil, stopped)
end)

---@async
lt.test('请求：不给宿主就不是可取消的请求（不带号）', function ()
    local game, players = newGame()
    local user = assert(assert(players[1]).user)
    ---@cast user ClientUser

    ---@type Proto.Request.Ask.Select?
    local sent = nil
    local _ <close> = moe.client.register('Ask.Select', function (_, params)
        ---@cast params Proto.Request.Ask.Select
        sent = params
        return { player = {} }
    end)

    local result = user:request('Ask.Select', {}, nil):await()
    lt.assertEquals('拿到了结果', 0, #(assert(result).player or {}))
    lt.assertEquals('没有取消号', nil, assert(sent, '没问到客户端').cancelToken)
end)
