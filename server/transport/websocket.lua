--- WebSocket 协议（RFC 6455）：握手与帧的编解码 —— 纯函数，收发归 `ws-link.lua`

local digest = require 'bee.digest'

--- 握手拿它跟客户端给的 key 拼起来算摘要（RFC 6455 写死的）
local GUID = '258EAFA5-E914-47DA-95CA-C5AB0DC85B11'

--- 客户端的握手请求
---@class Websocket.Request
---@field method string # 请求行里的方法（只认 GET）
---@field target string # 请求行里的路径
---@field headers table<string, string> # 头名统一小写；同名的取第一个

--- 一帧
---@class Websocket.Frame
---@field fin boolean # 这是这条消息的最后一段吗
---@field opcode integer
---@field payload string # 按掩码还原过的

---@class Websocket.API
moe.websocket = {}

moe.websocket.CONTINUATION = 0x0
moe.websocket.TEXT         = 0x1
moe.websocket.BINARY       = 0x2
moe.websocket.CLOSE        = 0x8
moe.websocket.PING         = 0x9
moe.websocket.PONG         = 0xA

--- 客户端发的载荷是掩过的，加掩与还原是同一件事（异或）
---@param payload string
---@param mask string # 4 字节
---@return string
local function applyMask(payload, mask)
    local bytes = { payload:byte(1, -1) }
    for i = 1, #bytes do
        bytes[i] = bytes[i] ~ mask:byte((i - 1) % 4 + 1)
    end
    return string.char(table.unpack(bytes))
end

--- 解帧器：喂字节进去、一帧一帧取出来（服务端方向 —— 客户端来的帧必须带掩码）
---@class Websocket.Decoder
---@field private buffer string # 收下还没解成帧的字节
local Decoder = Class 'Websocket.Decoder'

function Decoder:__init()
    self.buffer = ''
end

--- 喂进刚收到的字节
---@param text string
function Decoder:feed(text)
    self.buffer = self.buffer .. text
end

--- 取下一帧（字节不够就给空 —— 要数据是调用方的事；帧本身不合法给原因）
---@return Websocket.Frame?
---@return string?
function Decoder:next()
    local buffer = self.buffer
    if #buffer < 2 then
        return nil
    end
    local first, second = buffer:byte(1, 2)
    local opcode = first & 0x0F
    local fin    = first & 0x80 ~= 0
    if first & 0x70 ~= 0 then
        return nil, '帧头留了扩展位'
    end
    if second & 0x80 == 0 then
        return nil, '客户端来的帧必须带掩码'
    end
    local pos    = 3
    local length = second & 0x7F
    if length == 126 then
        if #buffer < pos + 1 then
            return nil
        end
        length = string.unpack('>I2', buffer, pos)
        pos = pos + 2
    elseif length == 127 then
        if #buffer < pos + 7 then
            return nil
        end
        length = string.unpack('>I8', buffer, pos)
        pos = pos + 8
    end
    if opcode >= 0x8 then
        if not fin then
            return nil, '控制帧不许分片'
        end
        if length > 125 then
            return nil, '控制帧最多 125 字节'
        end
    end
    if #buffer < pos + 3 then
        return nil
    end
    local mask = buffer:sub(pos, pos + 3)
    pos = pos + 4
    if #buffer < pos + length - 1 then
        return nil
    end
    local payload = applyMask(buffer:sub(pos, pos + length - 1), mask)
    self.buffer = buffer:sub(pos + length)
    return {
        fin     = fin,
        opcode  = opcode,
        payload = payload,
    }
end

--- 新造一个解帧器
---@return Websocket.Decoder
function moe.websocket.decoder()
    return New 'Websocket.Decoder' ()
end

--- 编一帧（`mask` 给了 4 字节就上掩码 = 客户端方向；不给就不掩 = 服务端方向）
---@param opcode integer
---@param payload string
---@param mask? string
---@return string
function moe.websocket.encodeFrame(opcode, payload, mask)
    local length = #payload
    local second
    local extend = ''
    if length < 126 then
        second = length
    elseif length < 65536 then
        second = 126
        extend = string.pack('>I2', length)
    else
        second = 127
        extend = string.pack('>I8', length)
    end
    local key = ''
    if mask then
        second  = second | 0x80
        key     = mask
        payload = applyMask(payload, mask)
    end
    return string.char(0x80 | opcode, second) .. extend .. key .. payload
end

--- 客户端给的 key 换成应答里的 accept 值（base64(sha1(key .. GUID))）
---@param key string
---@return string
function moe.websocket.acceptKey(key)
    return digest.base64(digest.sha1(key .. GUID))
end

--- 握手应答（101）
---@param key string
---@return string
function moe.websocket.acceptText(key)
    return 'HTTP/1.1 101 Switching Protocols\r\n'
        .. 'Upgrade: websocket\r\n'
        .. 'Connection: Upgrade\r\n'
        .. 'Sec-WebSocket-Accept: ' .. moe.websocket.acceptKey(key) .. '\r\n\r\n'
end

--- 握手不接受的应答
---@param status integer
---@param reason string
---@param headers? table<string, string>
---@return string
function moe.websocket.refuseText(status, reason, headers)
    local text = 'HTTP/1.1 {} {}\r\nConnection: close\r\nContent-Length: 0\r\n' % { status, reason }
    for name, value in pairs(headers or {}) do
        text = text .. '{}: {}\r\n' % { name, value }
    end
    return text .. '\r\n'
end

--- 解客户端的握手请求（`head` 是到空行为止的请求头 —— 不含末尾的空行）
---@param head string
---@return Websocket.Request?
---@return string?
function moe.websocket.parseRequest(head)
    local lines = {}
    for line in head:gmatch('[^\r\n]+') do
        lines[#lines + 1] = line
    end
    local startLine = lines[1]
    if not startLine then
        return nil, '请求头是空的'
    end
    local method, target = startLine:match('^(%u+)%s+(%S+)%s+HTTP/1%.[01]$')
    if not method then
        return nil, '认不出请求行'
    end
    if method ~= 'GET' then
        return nil, '握手得用 GET'
    end
    local headers = {}
    for i = 2, #lines do
        local name, value = lines[i]:match('^([^:]+):%s*(.-)%s*$')
        if name then
            name = name:lower()
            if headers[name] == nil then
                headers[name] = value
            end
        end
    end
    return {
        method  = method,
        target  = target,
        headers = headers,
    }
end

return moe.websocket
