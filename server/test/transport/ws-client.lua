--- 用例里那个最小的 WebSocket 客户端：自己写握手与帧（**不复用生产代码的编解码** —— 两边互为对照）

local support = require 'test.transport.tcp-support'

---@class Test.WsClient
local M = {}

--- 掩码写死（出问题好复现）
local MASK = '\x37\xFA\x21\x3D'

--- 客户端给的握手 key（RFC 6455 的例子 —— 应答就是那个固定的 accept 值）
local KEY = 'dGhlIHNhbXBsZSBub25jZQ=='

--- 二进制帧（RFC 6455）
local BINARY = 0x2

---@param payload string
---@return string
local function mask(payload)
    local bytes = { payload:byte(1, -1) }
    for i = 1, #bytes do
        bytes[i] = bytes[i] ~ MASK:byte((i - 1) % 4 + 1)
    end
    return string.char(table.unpack(bytes))
end

--- 发一帧（客户端方向 —— 一律带掩码；`fin` 给 false 就是分片的第一段）
---@async
---@param fd bee.socket.fd
---@param opcode integer
---@param payload string
---@param fin? boolean
function M.sendFrame(fd, opcode, payload, fin)
    local first = opcode
    if fin ~= false then
        first = first | 0x80
    end
    local length = #payload
    local head
    if length < 126 then
        head = string.char(first, 0x80 | length)
    elseif length < 65536 then
        head = string.char(first, 0x80 | 126) .. string.pack('>I2', length)
    else
        head = string.char(first, 0x80 | 127) .. string.pack('>I8', length)
    end
    support.sendText(fd, head .. MASK .. mask(payload))
end

--- 收一帧（服务端来的帧一律不带掩码）
---@async
---@param fd bee.socket.fd
---@return integer? # 帧类型
---@return string? # 载荷
function M.readFrame(fd)
    local head = support.recvExact(fd, 2)
    if not head then
        return nil
    end
    local first, second = head:byte(1, 2)
    if second & 0x80 ~= 0 then
        error('服务端发来的帧不该带掩码')
    end
    local length = second & 0x7F
    if length == 126 then
        length = string.unpack('>I2', (assert(support.recvExact(fd, 2), '连接断了')))
    elseif length == 127 then
        length = string.unpack('>I8', (assert(support.recvExact(fd, 8), '连接断了')))
    end
    local payload = support.recvExact(fd, length)
    if payload == nil then
        return nil
    end
    return first & 0x0F, payload
end

--- 发一条消息：跟裸帧那条路一样是「4 字节长度头 + 正文」，只是再套一层 WebSocket 帧
---@async
---@param fd bee.socket.fd
---@param text string
function M.sendMessage(fd, text)
    M.sendFrame(fd, BINARY, string.pack('>I4', #text) .. text)
end

--- 收一条消息（剥掉长度头）
---@async
---@param fd bee.socket.fd
---@return string?
function M.readMessage(fd)
    local _, payload = M.readFrame(fd)
    if not payload then
        return nil
    end
    return payload:sub(5, 4 + (string.unpack('>I4', payload)))
end

--- 走一遍握手，返回状态行与应答头（头名小写）
---@async
---@param fd bee.socket.fd
---@param path? string
---@return string # 状态行
---@return table<string, string> # 应答头
function M.handshake(fd, path)
    support.sendText(fd, ('GET {} HTTP/1.1\r\n'
        .. 'Host: localhost\r\n'
        .. 'Upgrade: websocket\r\n'
        .. 'Connection: Upgrade\r\n'
        .. 'Sec-WebSocket-Key: {}\r\n'
        .. 'Sec-WebSocket-Version: 13\r\n'
        .. '\r\n') % { path or '/', KEY })
    local head = support.readUntil(fd, '\r\n\r\n')
    local lines = {}
    for line in head:gmatch('[^\r\n]+') do
        lines[#lines + 1] = line
    end
    local headers = {}
    for i = 2, #lines do
        local name, value = lines[i]:match('^([^:]+):%s*(.*)$')
        if name then
            headers[name:lower()] = value
        end
    end
    return assert(lines[1]), headers
end

return M
