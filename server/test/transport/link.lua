local lt = require 'test.ltest'

lt.test('链接：写进去读得到', function ()
    local a, b = moe.link.pair()

    lt.assertEquals('写成功', true, a:write('你好'))
    lt.assertEquals('对面读得到', '你好', b:read())
end)

lt.test('链接：按字节读也是先写先读', function ()
    local a, b = moe.link.pair()
    a:write('一')
    a:write('二')

    lt.assertEquals('先写先读', '一', b:read(3))
    lt.assertEquals('后写的后读', '二', b:read(3))
end)

---@async
lt.test('链接：没数据时读会挂起，写进来才回来', function ()
    local a, b = moe.link.pair()
    local got
    ---@async
    moe.await.call(function ()
        got = b:read()
    end)

    lt.assertEquals('还没读到', nil, got)
    a:write('来了')
    lt.assertEquals('写进来就读到了', '来了', got)
end)

---@async
lt.test('链接：关掉一端，另一端读到空 + 原因', function ()
    local a, b = moe.link.pair()
    local got, err
    ---@async
    moe.await.call(function ()
        got, err = b:read()
    end)

    a:close('对面跑了')
    lt.assertEquals('读不到东西', nil, got)
    lt.assertEquals('原因', '对面跑了', err)
end)

lt.test('链接：关掉之后写不出去', function ()
    local a, b = moe.link.pair()
    a:close()

    local ok, err = a:write('还在吗')
    lt.assertEquals('写失败', false, ok)
    lt.assertEquals('有原因', true, err ~= nil)
end)

lt.test('链接：可以读指定字节数', function ()
    local a, b = moe.link.pair()
    a:write('hello')

    lt.assertEquals('先读三个字节', 'hel', b:read(3))
    lt.assertEquals('再读两个', 'lo', b:read(2))
end)

---@async
lt.test('链接：字节不够时读会挂起', function ()
    local a, b = moe.link.pair()
    a:write('ab')
    local got
    ---@async
    moe.await.call(function ()
        got = b:read(3)
    end)

    lt.assertEquals('还差一个字节', nil, got)
    a:write('c')
    lt.assertEquals('凑够就回来了', 'abc', got)
end)

lt.test('链接：字节可以跨消息拼', function ()
    local a, b = moe.link.pair()
    a:write('ab')
    a:write('cd')

    lt.assertEquals('跨两条消息读三个字节', 'abc', b:read(3))
    lt.assertEquals('没读完的那条剩下一个', 'd', b:read())
end)

lt.test('链接：不给字节数就把能读的全读走', function ()
    local a, b = moe.link.pair()
    a:write('ab')
    a:write('cd')

    lt.assertEquals('一次读走全部', 'abcd', b:read())
end)

lt.test('链接：关掉之后剩下没读的照旧读得到', function ()
    local a, b = moe.link.pair()
    a:write('最后一条')
    a:close()

    lt.assertEquals('剩下的还读得到', '最后一条', b:read())
    lt.assertEquals('读干净了才给空', nil, (b:read()))
end)
