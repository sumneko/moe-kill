local lt = require 'test.ltest'

lt.test('websocket：握手应答里的 accept 值对上 RFC 6455 的例子', function ()
    local key = 'dGhlIHNhbXBsZSBub25jZQ=='
    lt.assertEquals('accept 值', 's3pPLMBiTxaQ9kYGzzhZRbK+xOo=', moe.websocket.acceptKey(key))

    local text = moe.websocket.acceptText(key)
    lt.assertEquals('状态行', 'HTTP/1.1 101 Switching Protocols', text:match '^[^\r\n]+')
    lt.assertNotEquals('带了 accept 那一行', nil,
        text:find('Sec-WebSocket-Accept: s3pPLMBiTxaQ9kYGzzhZRbK+xOo=', 1, true))
    lt.assertEquals('以空行收尾', '\r\n\r\n', text:sub(-4))
end)

lt.test('websocket：解客户端的握手请求', function ()
    local request, err = moe.websocket.parseRequest(
        'GET /a/b HTTP/1.1\r\nHost: x\r\nUpgrade: WebSocket\r\nSec-WebSocket-Key: k\r\nSec-WebSocket-Version: 13')
    lt.assertEquals('解开了', nil, err)
    local got = assert(request)
    lt.assertEquals('方法', 'GET', got.method)
    lt.assertEquals('路径', '/a/b', got.target)
    lt.assertEquals('头名统一小写', 'WebSocket', got.headers['upgrade'])
    lt.assertEquals('带横线的头名', 'k', got.headers['sec-websocket-key'])

    lt.assertEquals('不是 GET 就不认', '握手得用 GET', select(2, moe.websocket.parseRequest 'POST / HTTP/1.1'))
    lt.assertEquals('请求行认不出', '认不出请求行', select(2, moe.websocket.parseRequest '随便什么'))
    lt.assertEquals('空的也报得出来', '请求头是空的', select(2, moe.websocket.parseRequest ''))
end)

lt.test('websocket：编出来的帧跟 RFC 6455 里写的一样', function ()
    lt.assertEquals('没掩码的 Hello（RFC 那个例子是文本帧）', '\x81\x05Hello',
        moe.websocket.encodeFrame(moe.websocket.TEXT, 'Hello'))
    lt.assertEquals('掩过的 Hello', '\x81\x85\x37\xFA\x21\x3D\x7F\x9F\x4D\x51\x58',
        moe.websocket.encodeFrame(moe.websocket.TEXT, 'Hello', '\x37\xFA\x21\x3D'))
    lt.assertEquals('二进制帧换成 0x82 开头', '\x82\x05Hello',
        moe.websocket.encodeFrame(moe.websocket.BINARY, 'Hello'))

    lt.assertEquals('125 字节还是一个字节的长度', 2 + 125,
        #moe.websocket.encodeFrame(moe.websocket.BINARY, string.rep('a', 125)))

    local medium = moe.websocket.encodeFrame(moe.websocket.BINARY, string.rep('b', 256))
    lt.assertEquals('126 加两字节长度', '\x82\x7E\x01\x00', medium:sub(1, 4))
    lt.assertEquals('整帧长度', 4 + 256, #medium)

    local large = moe.websocket.encodeFrame(moe.websocket.BINARY, string.rep('c', 65536))
    lt.assertEquals('127 加八字节长度', '\x82\x7F\x00\x00\x00\x00\x00\x01\x00\x00', large:sub(1, 10))
    lt.assertEquals('整帧长度', 10 + 65536, #large)
end)

lt.test('websocket：解帧对上 RFC 6455 的例子（一个一个字节喂也解得开）', function ()
    local decoder = moe.websocket.decoder()
    decoder:feed '\x81\x85\x37\xFA\x21\x3D\x7F\x9F\x4D\x51\x58'
    local frame = assert(decoder:next(), '这一帧该解得开')
    lt.assertEquals('是收尾的一帧', true, frame.fin)
    lt.assertEquals('是文本帧（RFC 那个例子就是）', moe.websocket.TEXT, frame.opcode)
    lt.assertEquals('载荷还原了', 'Hello', frame.payload)
    lt.assertEquals('解完就没了', nil, decoder:next())

    local bytes = moe.websocket.encodeFrame(moe.websocket.BINARY, '你好', '\x37\xFA\x21\x3D')
    decoder = moe.websocket.decoder()
    for i = 1, #bytes - 1 do
        decoder:feed(bytes:sub(i, i))
        lt.assertEquals('第 {} 个字节还凑不齐', nil, decoder:next())
    end
    decoder:feed(bytes:sub(#bytes))
    lt.assertEquals('凑齐了就解得开', '你好', assert(decoder:next()).payload)
end)

lt.test('websocket：不合法的帧要给原因', function ()
    local mask = '\x37\xFA\x21\x3D'

    local decoder = moe.websocket.decoder()
    decoder:feed '\x82\x03abc'
    lt.assertEquals('没带掩码', '客户端来的帧必须带掩码', select(2, decoder:next()))

    decoder = moe.websocket.decoder()
    decoder:feed(string.char(0xC2, 0x83) .. mask .. 'abc')
    lt.assertEquals('留了扩展位', '帧头留了扩展位', select(2, decoder:next()))

    decoder = moe.websocket.decoder()
    decoder:feed(string.char(0x09, 0x83) .. mask .. 'abc')
    lt.assertEquals('控制帧分片', '控制帧不许分片', select(2, decoder:next()))

    decoder = moe.websocket.decoder()
    decoder:feed(string.char(0x89, 0x80 | 126) .. string.pack('>I2', 200) .. mask .. string.rep('a', 200))
    lt.assertEquals('控制帧太长', '控制帧最多 125 字节', select(2, decoder:next()))
end)
