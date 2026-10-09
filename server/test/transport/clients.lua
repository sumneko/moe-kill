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

---@async
lt.test('集合：登记之后广播发得出去', function ()
    local _, back = connect()
    local got, undo = collect('测试/广播')
    local clients = moe.clients.create()
    clients:add(back)

    clients:broadcast('测试/广播', function ()
        return { n = 1 }
    end)
    moe.await.sleep(0)

    lt.assertEquals('收到一条', 1, #got)
    lt.assertEquals('载荷传过去了', 1, got[1].n)
    undo()
end)

---@async
lt.test('集合：撤销登记之后就发不到了', function ()
    local _, back = connect()
    local got, undo = collect('测试/广播')
    local clients = moe.clients.create()
    local remove = clients:add(back)

    remove()
    remove()
    clients:broadcast('测试/广播', function ()
        return { n = 1 }
    end)
    moe.await.sleep(0)

    lt.assertEquals('一条都没收到', 0, #got)
    undo()
end)

---@async
lt.test('集合：注销过的也发不到', function ()
    local _, back = connect()
    local got, undo = collect('测试/广播')
    local clients = moe.clients.create()
    clients:add(back)
    clients:remove(back)

    clients:broadcast('测试/广播', function ()
        return { n = 1 }
    end)
    moe.await.sleep(0)

    lt.assertEquals('一条都没收到', 0, #got)
    undo()
end)

---@async
lt.test('集合：载荷按连接各造一份', function ()
    local _, backA = connect()
    local _, backB = connect()
    local got, undo = collect('测试/广播')
    local clients = moe.clients.create()
    clients:add(backA)
    clients:add(backB)

    clients:broadcast('测试/广播', function (client)
        return { mine = client == backA }
    end)
    moe.await.sleep(0)

    local mine, other = 0, 0
    for _, params in ipairs(got) do
        if params.mine then
            mine = mine + 1
        else
            other = other + 1
        end
    end
    lt.assertEquals('两条各自造了一份', 2, #got)
    lt.assertEquals('A 那份按 A 算', 1, mine)
    lt.assertEquals('B 那份按 B 算', 1, other)
    undo()
end)

---@async
lt.test('集合：载荷造出来是空的那条就跳过', function ()
    local _, backA = connect()
    local _, backB = connect()
    local got, undo = collect('测试/广播')
    local clients = moe.clients.create()
    clients:add(backA)
    clients:add(backB)

    clients:broadcast('测试/广播', function (client)
        if client == backA then
            return { n = 1 }
        end
        return nil
    end)
    moe.await.sleep(0)

    lt.assertEquals('只收到 A 那条', 1, #got)
    lt.assertEquals('就是 A 的', 1, got[1].n)
    undo()
end)
