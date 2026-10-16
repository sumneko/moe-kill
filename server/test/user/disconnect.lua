local lt      = require 'test.ltest'
local support = require 'test.user.support'

---@async
lt.test('断线：连接收摊时，正挂在询问上的那一路会被叫醒（不是只记一笔）', function ()
    local game, players, fronts = support.newPackageGame()
    local me   = assert(players[1])
    local user = assert(me.user)
    ---@cast user ClientUser

    -- 客户端一直不答（挂住不回 —— 挂号在虚拟时钟下永远醒不过来）
    local _ <close> = moe.client.register('Ask.Select', function ()
        moe.await.sleep(1000)
    end)

    -- 真询问：这一路这时正挂在「等客户端答复」上
    local ask = moe.askCard.create { game = game, to = me, reason = '测试' }
    local pending = moe.task.create { ask = ask }
    pending:executeSync(function ()
        ask:apply():await()
    end)

    -- 前端刷新 / 掉线：那条连接收摊
    user.client:close('断线')

    local result, err = user:request('Ask.Select', { reason = '测试' }):await()
    lt.assertEquals('收摊后的新请求没有结果', nil, result)
    lt.assertEquals('原因说的是连接关了', '连接已关闭', assert(err).message)

    pending:await()
    lt.assertEquals('挂在询问上的那一路也收尾了', false, ask.success)
    lt.assertEquals('当「取消」处理', '取消', ask.err)
end)

---@async
lt.test('断线：请求的「主人」被收掉时，挂在它上面的那一路也会收尾', function ()
    local game, players, fronts = support.newPackageGame()
    local me   = assert(players[1])
    local user = assert(me.user)
    ---@cast user ClientUser

    -- 客户端一直不答（挂住不回 —— 挂号在虚拟时钟下永远醒不过来）
    local _ <close> = moe.client.register('Ask.Select', function ()
        moe.await.sleep(1000)
    end)

    local host = moe.gc.host()
    local request = user:request('Ask.Select', { reason = '测试' }, host)
    local pending = moe.task.create { request = request }
    pending:executeSync(function ()
        request:await()
    end)

    Delete(host)

    local result, err = request:await()
    lt.assertEquals('没有结果', nil, result)
    lt.assertEquals('原因说的是这次请求作废了', 'request canceled', assert(err).message)

    -- 挂在它上面的那一路是被「叫醒」的，让出一次才跑得完
    moe.await.sleep(0)
    lt.assertEquals('挂在它上面的那一路也收尾了', true, pending.resolved)
end)

---@async
lt.test('断线：收摊过的连接不再收新的通知', function ()
    local game, players, fronts = support.newPackageGame()
    local me   = assert(players[1])
    local user = assert(me.user)
    ---@cast user ClientUser

    local ok, err = user.client:notify('Room.Update', { seats = 4, players = {} })
    lt.assertEquals('好着呢', true, ok)
    lt.assertEquals('没有原因', nil, err)

    user.client:close('断线')

    local after, why = user.client:notify('Room.Update', { seats = 4, players = {} })
    lt.assertEquals('收摊后发不出去', false, after)
    lt.assertEquals('原因也给了', '连接已关闭', why)
end)
