local lt = require 'test.ltest'

lt.test('JSON-RPC：编一次调用再解回来', function ()
    local message = assert(moe.jsonrpc.decode(moe.jsonrpc.encodeCall(1, '测试/方法', { a = 1 })))

    lt.assertEquals('id 带回来了', 1, message.id)
    lt.assertEquals('方法名带回来了', '测试/方法', message.method)
    lt.assertEquals('参数带回来了', 1, message.params.a)
end)

lt.test('JSON-RPC：不给 id 就是通知', function ()
    local message = assert(moe.jsonrpc.decode(moe.jsonrpc.encodeCall(nil, '测试/通知')))

    lt.assertEquals('没有 id', nil, message.id)
    lt.assertEquals('方法名在', '测试/通知', message.method)
end)

lt.test('JSON-RPC：成功响应（结果为空也编成 null）', function ()
    local text    = moe.jsonrpc.encodeResult(7, nil)
    local message = assert(moe.jsonrpc.decode(text))

    lt.assertEquals('响应里带着 null', true, text:find('"result":null', 1, true) ~= nil)
    lt.assertEquals('id 对得上', 7, message.id)
    lt.assertEquals('没有 error', nil, message.error)
end)

lt.test('JSON-RPC：错误响应', function ()
    local message = assert(moe.jsonrpc.decode(moe.jsonrpc.encodeError(3, moe.jsonrpc.METHOD_NOT_FOUND, '没有这个方法')))
    local err = assert(message.error)

    lt.assertEquals('错误码', moe.jsonrpc.METHOD_NOT_FOUND, err.code)
    lt.assertEquals('说明', '没有这个方法', err.message)
end)

lt.test('JSON-RPC：错误响应没有 id 时编成 null', function ()
    local text = moe.jsonrpc.encodeError(nil, moe.jsonrpc.PARSE_ERROR, '解析不了')

    lt.assertEquals('id 写的是 null', true, text:find('"id":null', 1, true) ~= nil)
end)

lt.test('JSON-RPC：解不开的消息给空 + 原因', function ()
    local message, err = moe.jsonrpc.decode('这不是 json')

    lt.assertEquals('没有消息', nil, message)
    lt.assertEquals('有原因', true, err ~= nil)
end)

lt.test('JSON-RPC：不是对象的消息也给空', function ()
    local message = moe.jsonrpc.decode('"就是一个字符串"')

    lt.assertEquals('没有消息', nil, message)
end)
