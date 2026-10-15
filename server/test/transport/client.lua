local lt = require 'test.ltest'

---@type integer # 协议里的长度头占几个字节
local HEADER_SIZE = 4

--- 照协议给一条消息套上长度头（测试自己拼，不借产品代码）
---@param text string
---@return string
local function frame(text)
    return string.pack('>I4', #text) .. text
end

--- 造一对对接好的客户端（都已起读循环）
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

---@async
lt.test('客户端：通知能过去', function ()
    local front = connect()
    local got
    local undo = moe.client.register('测试/通知', function (client, params)
        got = params
    end)

    front:notify('测试/通知', { n = 1 })
    lt.assertEquals('后端收到了', 1, got.n)
    undo()
end)

---@async
lt.test('客户端：请求能来回', function ()
    local front = connect()
    local undo = moe.client.register('测试/加法', function (client, params)
        return params.a + params.b
    end)

    local result, err = front:awaitRequest('测试/加法', { a = 1, b = 2 })
    lt.assertEquals('没有失败', nil, err)
    lt.assertEquals('结果', 3, result)
    undo()
end)

---@async
lt.test('客户端：处理器可以 await', function ()
    local front = connect()
    local undo = moe.client.register('测试/慢', function (client, params)
        moe.await.sleep(0)
        return '慢结果'
    end)

    local result, err = front:awaitRequest('测试/慢', {})
    lt.assertEquals('没有失败', nil, err)
    lt.assertEquals('结果', '慢结果', result)
    undo()
end)

---@async
lt.test('客户端：请求也可以用回调收结果', function ()
    local front = connect()
    local undo = moe.client.register('测试/回声', function (client, params)
        return params
    end)

    local got
    local task = front:request('测试/回声', { x = 9 }, function (result, err)
        got = result
    end)
    task:await()
    lt.assertEquals('回调拿到了', 9, assert(got).x)
    undo()
end)

---@async
lt.test('客户端：没注册的方法回「没有这个方法」', function ()
    local front = connect()

    local result, err = front:awaitRequest('没人/注册', {})
    lt.assertEquals('没有结果', nil, result)
    lt.assertEquals('错误码', moe.jsonrpc.METHOD_NOT_FOUND, (assert(err)).code)
end)

---@async
lt.test('客户端：撤销注册之后就没有这个方法了', function ()
    local front = connect()
    local undo = moe.client.register('测试/临时', function ()
        return 1
    end)
    undo()

    local result, err = front:awaitRequest('测试/临时', {})
    lt.assertEquals('没有结果', nil, result)
    lt.assertEquals('错误码', moe.jsonrpc.METHOD_NOT_FOUND, (assert(err)).code)
end)

lt.test('客户端：同一个方法重复注册会报错', function ()
    local undo = moe.client.register('测试/重复', function ()
    end)

    lt.assertError('重复注册报错', function ()
        moe.client.register('测试/重复', function ()
        end)
    end)
    undo()
end)

---@async
lt.test('客户端：断开时还在等的请求以「连接断开」收尾', function ()
    local front = connect()
    local undo = moe.client.register('测试/不答', function (client, params)
        moe.await.sleep(10)
    end)

    local task = front:request('测试/不答', {})
    front:close('测试断开')

    local result, err = task:await()
    lt.assertEquals('没有结果', nil, result)
    lt.assertEquals('原因', '测试断开', assert(err).message)
    undo()
end)

---@async
lt.test('客户端：不认识的结果只丢掉，后面的照常', function ()
    local front, back = connect()
    -- 后端侧那条链路上冒充一条「id 没发过」的响应
    back.link:write(frame(moe.jsonrpc.encodeResult(12345, '谁要的')))

    local undo = moe.client.register('测试/照常', function ()
        return 'ok'
    end)
    local result, err = front:awaitRequest('测试/照常', {})
    lt.assertEquals('照常拿到结果', 'ok', result)
    lt.assertEquals('没有失败', nil, err)
    undo()
end)

---@async
lt.test('客户端：粘在一起的帧也各解一条', function ()
    local front, back = connect()
    local got = {}
    local undo = moe.client.register('测试/粘包', function (client, params)
        got[#got + 1] = params.n
    end)

    local one = frame(moe.jsonrpc.encodeCall(nil, '测试/粘包', { n = 1 }))
    local two = frame(moe.jsonrpc.encodeCall(nil, '测试/粘包', { n = 2 }))
    back.link:write(one .. two)

    lt.assertEquals('两条都收到了', 2, #got)
    lt.assertEquals('第一条', 1, got[1])
    lt.assertEquals('第二条', 2, got[2])
    undo()
end)

---@async
lt.test('客户端：头和正文分两批到也接得上', function ()
    local front, back = connect()
    local got
    local undo = moe.client.register('测试/半包', function (client, params)
        got = params
    end)

    local data = frame(moe.jsonrpc.encodeCall(nil, '测试/半包', { n = 7 }))
    back.link:write(data:sub(1, HEADER_SIZE))
    lt.assertEquals('只有头的时候还没解出来', nil, got)
    back.link:write(data:sub(HEADER_SIZE + 1))
    lt.assertEquals('正文到手就解出来了', 7, assert(got).n)
    undo()
end)

---@async
lt.test('客户端：发不出去 = 这条连接坏了，就地收摊', function ()
    local front, back = connect()
    -- 把「后端 → 前端」这条写弄坏（对端已经关了的样子）
    back.link.write = function ()
        return false, '对端关闭了连接'
    end

    lt.assertEquals('通知发不出去', false, back:notify('测试/通知', { n = 1 }))
    lt.assertEquals('这条连接就地收摊', true, back.closed)
    lt.assertEquals('收摊之后发什么都不再往外走', false, back:notify('测试/通知', { n = 2 }))

    front:close('用例收摊')
    back:close('用例收摊')
end)

---@async
lt.test('客户端：发不出去也要先让出一笔调度（别把事件循环饿死）', function ()
    local front, back = connect()
    back.link.write = function ()
        return false, '对端关闭了连接'
    end

    ---@type string[]
    local order = {}
    moe.await.wake(function ()
        order[#order + 1] = '排在后面的那个'
    end)
    local task = back:request('测试/回声', {})
    local _, err = task:await()
    lt.assertEquals('这次请求没成', '对端关闭了连接', assert(err).message)
    lt.assertEquals('让出过一笔：排在后面的先跑了', 1, #order)

    front:close('用例收摊')
    back:close('用例收摊')
end)
