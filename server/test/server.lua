local lt      = require 'test.ltest'
local support = require 'test.transport.tcp-support'
local ws      = require 'test.transport.ws-client'
local socket  = require 'bee.socket'

---@async
--- 连一条真 TCP 到这台服务器上（用完自己关）
---@return bee.socket.fd
local function dialServer()
    local _, port = moe.server._listener:info('socket'):value()
    local dialer = assert(socket.create 'tcp')
    support.spin(function () return dialer:connect('127.0.0.1', port) end)
    return dialer
end

lt.test('服务器：起一局，一条真连接坐进来就拿到自己的快照', function ()
    moe.server.start {
        port     = 0,
        seats    = 4,
        packages = { '身份场', '标准' },
    }

    local dialer = dialServer()
    local _ <close> = moe.util.defer(function () dialer:close() end)

    support.sendFrame(dialer, assert(moe.jsonrpc.encodeCall(1, 'Game.Join', { name = '甲' })))
    local snapshot = assert(support.readResult(dialer, 1).result)
    lt.assertEquals('坐进来了', 1, #snapshot.players)
    lt.assertEquals('名字带上了', '甲', snapshot.players[1].base.userName)
    lt.assertEquals('还没坐满，没人在回合里', nil, snapshot.turnPlayer)
end)

lt.test('服务器：真连接坐满就开局，再来的要不到位置', function ()
    -- 上一条用例已坐了 1 个，这里再坐 3 个就满了（4 人局：身份配置里最小的一档）
    local dialers = {}
    local _ <close> = moe.util.defer(function ()
        for _, fd in ipairs(dialers) do
            fd:close()
        end
    end)

    local last
    for i = 1, 3 do
        local fd = dialServer()
        dialers[#dialers + 1] = fd
        support.sendFrame(fd, assert(moe.jsonrpc.encodeCall(100 + i, 'Game.Join', { name = '玩家' .. i })))
        last = fd
    end

    -- 坐满就开局：开局第一步是问选将（服务端发来的请求）
    support.readMethod(assert(last), 'Ask.Hero')

    local extra = dialServer()
    dialers[#dialers + 1] = extra
    support.sendFrame(extra, assert(moe.jsonrpc.encodeCall(200, 'Game.Join', { name = '多的' })))
    local err = assert(support.readResult(extra, 200).error)
    lt.assertEquals('说清是这条请求做不了', moe.jsonrpc.INVALID_REQUEST, err.code)
    lt.assertEquals('原因是坐满了', '座位已经坐满', err.message)
end)

lt.test('服务器：网页那条路（WebSocket 握手 + 掩码帧）一样接得进来', function ()
    -- 上面两条已经坐满了，这条要的是「协议层通得了、业务层照旧回错」
    local dialer = dialServer()
    local _ <close> = moe.util.defer(function () dialer:close() end)

    ws.handshake(dialer)
    ws.sendMessage(dialer, assert(moe.jsonrpc.encodeCall(300, 'Game.Join', { name = '网页' })))

    local message = assert(moe.jsonrpc.decode(assert(ws.readMessage(dialer))))
    local err = assert(message.error)
    lt.assertEquals('业务层的错误照旧', moe.jsonrpc.INVALID_REQUEST, err.code)
    lt.assertEquals('原因是坐满了', '座位已经坐满', err.message)
end)
