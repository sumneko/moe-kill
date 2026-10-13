local lt      = require 'test.ltest'
local support = require 'test.user.support'

---@async
lt.test('时限：到点还没回就按超时收尾（多等 1 秒）', function ()
    local game, players, fronts = support.newPackageGame()
    local me   = assert(players[1])
    local user = assert(me.user)
    ---@cast user ClientUser

    ---@type Proto.Notify.Cancel?
    local stopped = nil
    local _ <close> = moe.client.register('Cancel', function (_, params)
        ---@cast params Proto.Notify.Cancel
        stopped = params
    end)
    -- 客户端一直不答（挂住不回 —— 挂号在虚拟时钟下永远醒不过来）
    local _ <close> = moe.client.register('Ask.Select', function ()
        moe.await.sleep(1000)
    end)

    local request = user:request('Ask.Select', { reason = '测试', timeLimit = 0.5 }, moe.gc.host())
    moe.await.sleep(0)

    test.advance(0.8)
    moe.await.sleep(0)
    lt.assertEquals('还没到点', false, request.resolved)

    test.advance(1.0)
    moe.await.sleep(0)
    lt.assertEquals('到点了', true, request.resolved)

    local result, err = request:await()
    lt.assertEquals('没有结果', nil, result)
    lt.assertEquals('错误码是超时', -3, assert(err).code)
    lt.assertEquals('错误里说清了', 'timeout', err.message)
    lt.assertEquals('顺带叫停了客户端', true, stopped ~= nil)
end)

---@async
lt.test('时限：按时答上就不算超时（计时器跟着请求一起拆）', function ()
    local game, players, fronts = support.newPackageGame()
    local me   = assert(players[1])
    local user = assert(me.user)
    ---@cast user ClientUser

    local _ <close> = moe.client.register('Ask.Select', function ()
        return { player = { me.id } }
    end)

    local request = user:request('Ask.Select', { reason = '测试', timeLimit = 0.5 }, moe.gc.host())
    local result  = request:await()
    lt.assertEquals('答上了', true, result ~= nil)

    test.advance(10)
    moe.await.sleep(0)
    lt.assertEquals('推再多时钟也不改结果', nil, request.err)
end)

---@async
lt.test('时限：询问自带默认 10 秒，内容侧可以写自己的', function ()
    local game, players, fronts = support.newPackageGame()
    local me = assert(players[1])

    ---@type Proto.Request.Ask.Hero?
    local sent = nil
    local _ <close> = moe.client.register('Ask.Hero', function (_, params)
        ---@cast params Proto.Request.Ask.Hero
        sent = params
        -- 记下来就不答了（挂住不回）
        moe.await.sleep(1000)
    end)

    -- 不答：到点自己按超时收尾（多等 1 秒）
    local ask = moe.askHero.create { game = game, to = me, reason = '选将' }
    ask:apply()
    moe.await.sleep(0)
    lt.assertEquals('带的是默认时限', 10, assert(sent).timeLimit)

    test.advance(11 + 1)
    moe.await.sleep(0)
    ask:await()
    lt.assertEquals('这次没成', false, ask.success)
    lt.assertEquals('当「取消」处理（业务层不问原因）', '取消', ask.err)

    -- 内容侧在条件里写自己的时限
    local custom = moe.askHero.create {
        game      = game,
        to        = me,
        reason    = '选将',
        condition = { timeLimit = 0.5 },
    }
    custom:apply()
    moe.await.sleep(0)
    lt.assertEquals('带的是它写的那个', 0.5, assert(sent).timeLimit)
    custom:cancel('用例收摊')
end)

---@async
lt.test('时限：超时之后客户端才回包 ⇒ 丢掉，后面的照常', function ()
    local game, players, fronts = support.newPackageGame()
    local me   = assert(players[1])
    local user = assert(me.user)
    ---@cast user ClientUser

    -- 客户端拖到过了时限才回包
    local _ <close> = moe.client.register('Ask.Select', function ()
        moe.await.sleep(2)
        return { player = { me.id } }
    end)
    local _ <close> = moe.client.register('Ask.Choice', function ()
        return { choice = 1 }
    end)

    local request = user:request('Ask.Select', { reason = '测试', timeLimit = 0.5 }, moe.gc.host())
    moe.await.sleep(0)

    -- 推过时限（1.5 秒），也把客户端那个 2 秒的挂号一并推到点 ⇒ 回包必然晚到
    test.advance(2)
    for _ = 1, 3 do
        moe.await.sleep(0)
    end
    lt.assertEquals('还是按超时收尾', -3, assert(request.err).code)

    -- 账没被搅乱：后面照常问照常收
    local second = user:request('Ask.Choice', {
        reason    = '测试',
        options   = { '甲' },
        timeLimit = 5,
    }, moe.gc.host()):await()
    lt.assertEquals('后面那次照常收到回包', 1, assert(second).choice)
end)

---@async
lt.test('时限：牌条件上的时限也透得过去（归一化不丢）', function ()
    local game, players, fronts = support.newPackageGame()
    local me = assert(players[1])
    support.giveCard(game, me, '杀', '黑桃', 7)

    ---@type Proto.Request.Ask.Select?
    local sent = nil
    local _ <close> = moe.client.register('Ask.Select', function (_, params)
        ---@cast params Proto.Request.Ask.Select
        sent = params
        return {}
    end)

    local ask = moe.askCard.create {
        game      = game,
        to        = me,
        reason    = '弃牌',
        condition = { zone = '手牌', timeLimit = 0.5 },
    }
    ask:apply():await()

    lt.assertEquals('时限透到协议上了', 0.5, assert(sent).timeLimit)
end)
