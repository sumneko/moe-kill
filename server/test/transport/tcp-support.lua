--- 走真 TCP 的用例的辅助：起本地监听、等一件 IO 事件

local socket = require 'bee.socket'

---@class Test.TcpSupport
local M = {}

--- 起一个本地监听（端口让系统分一个空闲的）
---@return bee.socket.fd
---@return integer
function M.listenOn()
    local listener = assert(socket.create 'tcp')
    listener:option('reuseaddr', 1)
    assert(listener:bind('127.0.0.1', 0))
    assert(listener:listen(4))
    local _, port = listener:info('socket'):value()
    return listener, port
end

--- 让事件循环跑几轮，直到 `step()` 不再是「等待中」（`false`）
---@async
---@param step fun(): any
---@return any
function M.spin(step)
    for _ = 1, 500 do
        local value = step()
        if value ~= false then
            return value
        end
        moe.await.sleep(0)
    end
    error('等 IO 等到超时了')
end

--- 连一对：返回「监听侧收到的那个 fd」与「拨号的那端」（监听套接字用完就关）
---@async
---@return bee.socket.fd
---@return bee.socket.fd
function M.connectPair()
    local listener, port = M.listenOn()
    local dialer = assert(socket.create 'tcp')
    M.spin(function () return dialer:connect('127.0.0.1', port) end)
    local fd = M.spin(function () return listener:accept() end)
    listener:close()
    return assert(fd), dialer
end

--- 发一条带长度头的消息（发不完就接着发 —— `send` 可能只发一部分）
---@async
---@param fd bee.socket.fd
---@param text string
function M.sendFrame(fd, text)
    local frame = string.pack('>I4', #text) .. text
    local sent  = 0
    while sent < #frame do
        local count = M.spin(function () return fd:send(frame:sub(sent + 1)) end)
        if count == 0 then
            moe.await.sleep(0)
        elseif count == nil then
            error('发不出去')
        else
            sent = sent + count
        end
    end
end

--- 收满 `n` 个字节（凑不够就等）
---@async
---@param fd bee.socket.fd
---@param n integer
---@return string?
function M.recvExact(fd, n)
    local got = ''
    while #got < n do
        local chunk = M.spin(function () return fd:recv(n - #got) end)
        if not chunk then
            return nil
        end
        got = got .. chunk
    end
    return got
end

--- 收一条带长度头的消息
---@async
---@param fd bee.socket.fd
---@return string?
function M.readFrame(fd)
    local head = M.recvExact(fd, 4)
    if not head then
        return nil
    end
    return M.recvExact(fd, (string.unpack('>I4', head)))
end

--- 读到指定号的那条回应（中间的通知跳过）
---@async
---@param fd bee.socket.fd
---@param id integer
---@return Jsonrpc.Message
function M.readResult(fd, id)
    while true do
        local text = assert(M.readFrame(fd), '连接断了')
        local message = assert(moe.jsonrpc.decode(text))
        if message.id == id then
            return message
        end
    end
end

--- 读到服务端发来的某个请求（中间的通知、回应全跳过）
---@async
---@param fd bee.socket.fd
---@param method string
---@return Jsonrpc.Message
function M.readMethod(fd, method)
    while true do
        local text = assert(M.readFrame(fd), '连接断了')
        local message = assert(moe.jsonrpc.decode(text))
        if message.method == method and message.id ~= nil then
            return message
        end
    end
end

return M
