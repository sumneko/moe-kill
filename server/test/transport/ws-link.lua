local lt      = require 'test.ltest'
local support = require 'test.transport.tcp-support'
local ws      = require 'test.transport.ws-client'

--- 连一对并做完握手：返回服务端这侧的链接、客户端那端、客户端看到的应答
---@async
---@return WsLink
---@return bee.socket.fd
---@return table # `.status` / `.headers`
local function upgradePair()
    local fd, dialer = support.connectPair()
    local answer = {}
    moe.await.call(function ()
        answer.status, answer.headers = ws.handshake(dialer)
    end)
    local link, err = moe.link.websocket(moe.link.tcp(fd))
    support.spin(function () return answer.status ~= nil end)
    return assert(link, err), dialer, answer
end

--- 让服务端那侧去读（控制帧只有读的时候才处理）
---@param link WsLink
---@return table # `.text` / `.err`
local function readInBackground(link)
    local result = {}
    moe.await.call(function ()
        result.text, result.err = link:read()
    end)
    return result
end

lt.test('WebSocket 链路：握手回 101，accept 值跟 RFC 的例子一样', function ()
    local link, dialer, answer = upgradePair()
    local _ <close> = moe.util.defer(function ()
        link:close()
        dialer:close()
    end)

    lt.assertEquals('状态行', 'HTTP/1.1 101 Switching Protocols', answer.status)
    lt.assertEquals('Upgrade 头', 'websocket', answer.headers['upgrade'])
    lt.assertEquals('accept 值', 's3pPLMBiTxaQ9kYGzzhZRbK+xOo=', answer.headers['sec-websocket-accept'])
end)

lt.test('WebSocket 链路：写过去对面收到一条二进制帧', function ()
    local link, dialer = upgradePair()
    local _ <close> = moe.util.defer(function ()
        link:close()
        dialer:close()
    end)

    lt.assertEquals('发得出去', true, link:write '你好')
    local opcode, payload = ws.readFrame(dialer)
    lt.assertEquals('是二进制帧', moe.websocket.BINARY, opcode)
    lt.assertEquals('载荷一模一样', '你好', payload)
end)

lt.test('WebSocket 链路：对面发来的掩码帧解得开，当字节流读', function ()
    local link, dialer = upgradePair()
    local _ <close> = moe.util.defer(function ()
        link:close()
        dialer:close()
    end)

    ws.sendFrame(dialer, moe.websocket.BINARY, 'ab')
    ws.sendFrame(dialer, moe.websocket.BINARY, 'c')
    lt.assertEquals('先读两个字节', 'ab', link:read(2))
    lt.assertEquals('下一帧的字节排在后头', 'c', link:read(1))
end)

lt.test('WebSocket 链路：大载荷两头一起走（126 / 127 两种长度形式）', function ()
    local link, dialer = upgradePair()
    local _ <close> = moe.util.defer(function ()
        link:close()
        dialer:close()
    end)

    local short  = string.rep('a', 125)
    local medium = string.rep('b', 300)
    local large  = string.rep('c', 70000)
    local got = {}
    moe.await.waitAll {
        function ()
            for i = 1, 3 do
                got[i] = select(2, ws.readFrame(dialer))
            end
        end,
        function ()
            link:write(short)
            link:write(medium)
            link:write(large)
        end,
    }
    lt.assertEquals('125 字节那一帧', short, got[1])
    lt.assertEquals('300 字节那一帧', medium, got[2])
    lt.assertEquals('70000 字节那一帧', large, got[3])
end)

lt.test('WebSocket 链路：分片的消息接着攒（当一股字节流）', function ()
    local link, dialer = upgradePair()
    local _ <close> = moe.util.defer(function ()
        link:close()
        dialer:close()
    end)

    local text = '前半' .. '后半'
    local got = {}
    moe.await.waitAll {
        function ()
            local chunks = {}
            local size = 0
            while size < #text do
                local chunk = link:read(#text - size)
                if not chunk then
                    return
                end
                chunks[#chunks + 1] = chunk
                size = size + #chunk
            end
            got.text = table.concat(chunks)
        end,
        function ()
            ws.sendFrame(dialer, moe.websocket.BINARY, '前半', false)
            ws.sendFrame(dialer, moe.websocket.CONTINUATION, '后半', true)
        end,
    }
    lt.assertEquals('两段拼起来', text, got.text)
end)

lt.test('WebSocket 链路：ping 回 pong，pong 当没看见', function ()
    local link, dialer = upgradePair()
    local _ <close> = moe.util.defer(function ()
        link:close()
        dialer:close()
    end)

    local got = readInBackground(link)
    ws.sendFrame(dialer, moe.websocket.PING, '在吗')
    local opcode, payload = ws.readFrame(dialer)
    lt.assertEquals('回的是 pong', moe.websocket.PONG, opcode)
    lt.assertEquals('载荷原样带回来', '在吗', payload)

    ws.sendFrame(dialer, moe.websocket.PONG, '随便')
    ws.sendFrame(dialer, moe.websocket.BINARY, '接着来')
    support.spin(function () return got.text ~= nil end)
    lt.assertEquals('pong 不挡后面的数据', '接着来', got.text)
end)

lt.test('WebSocket 链路：对面发关闭帧 ⇒ 回一条关闭帧并断开', function ()
    local link, dialer = upgradePair()
    local _ <close> = moe.util.defer(function ()
        link:close()
        dialer:close()
    end)

    local got = readInBackground(link)
    ws.sendFrame(dialer, moe.websocket.CLOSE, string.pack('>I2', 1000))
    local opcode = ws.readFrame(dialer)
    lt.assertEquals('回了一条关闭帧', moe.websocket.CLOSE, opcode)
    support.spin(function () return got.err ~= nil end)
    lt.assertEquals('读这边给空 + 原因', '对端关闭了连接', got.err)
    lt.assertEquals('连接也断了', nil, support.recvExact(dialer, 1))
end)

lt.test('WebSocket 链路：对面发没掩码的帧 ⇒ 回 1002 并断开', function ()
    local link, dialer = upgradePair()
    local _ <close> = moe.util.defer(function ()
        link:close()
        dialer:close()
    end)

    local got = readInBackground(link)
    support.sendText(dialer, '\x82\x03abc')
    local opcode, payload = ws.readFrame(dialer)
    lt.assertEquals('回的是关闭帧', moe.websocket.CLOSE, opcode)
    lt.assertEquals('码是协议错', 1002, string.unpack('>I2', assert(payload)))
    support.spin(function () return got.err ~= nil end)
    lt.assertEquals('原因说清了', '客户端来的帧必须带掩码', got.err)
end)

lt.test('WebSocket 链路：对面发文本帧 ⇒ 回 1003 并断开', function ()
    local link, dialer = upgradePair()
    local _ <close> = moe.util.defer(function ()
        link:close()
        dialer:close()
    end)

    local got = readInBackground(link)
    ws.sendFrame(dialer, moe.websocket.TEXT, '这是文本')
    local opcode, payload = ws.readFrame(dialer)
    lt.assertEquals('回的是关闭帧', moe.websocket.CLOSE, opcode)
    lt.assertEquals('码是不收这种数据', 1003, string.unpack('>I2', assert(payload)))
    support.spin(function () return got.err ~= nil end)
    lt.assertEquals('原因说清了', '这条通道是字节流，请发二进制帧', got.err)
end)

lt.test('嗅探：裸帧客户端照旧给一条 TCP 链路', function ()
    local fd, dialer = support.connectPair()
    local _ <close> = moe.util.defer(function ()
        dialer:close()
    end)

    support.sendFrame(dialer, '你好')
    local link, err = moe.link.accept(fd)
    lt.assertEquals('接成了', nil, err)
    local got = assert(link)
    lt.assertEquals('认成了裸帧', 'TcpLink', Type(got))
    lt.assertEquals('长度头没被吃掉', 6, string.unpack('>I4', assert(got:read(4))))
    lt.assertEquals('正文还在', '你好', got:read(6))
end)

lt.test('嗅探：HTTP 请求走 WebSocket 握手', function ()
    local fd, dialer = support.connectPair()
    local _ <close> = moe.util.defer(function ()
        dialer:close()
    end)

    local answer = {}
    moe.await.call(function ()
        answer.status = ws.handshake(dialer)
    end)
    local link, err = moe.link.accept(fd)
    lt.assertEquals('接成了', nil, err)
    lt.assertEquals('认成了 WebSocket', 'WsLink', Type(assert(link)))
    support.spin(function () return answer.status ~= nil end)
    lt.assertEquals('握手成了', 'HTTP/1.1 101 Switching Protocols', answer.status)
end)

lt.test('嗅探：版本不是 13 ⇒ 回 426 并断开', function ()
    local fd, dialer = support.connectPair()
    local _ <close> = moe.util.defer(function ()
        dialer:close()
    end)

    local answer = {}
    moe.await.call(function ()
        support.sendText(dialer, 'GET / HTTP/1.1\r\nSec-WebSocket-Key: abc\r\nSec-WebSocket-Version: 8\r\n\r\n')
        answer.head = support.readUntil(dialer, '\r\n\r\n')
    end)
    local link, err = moe.link.accept(fd)
    lt.assertEquals('没接成', nil, link)
    lt.assertEquals('给了原因', '只认 Sec-WebSocket-Version: 13', err)
    support.spin(function () return answer.head ~= nil end)
    lt.assertNotEquals('回的是 426', nil, assert(answer.head):find('426', 1, true))
end)
