--- WebSocket 上的那条 Link：握手 + 帧的收发（底下垫一条字节通道，通常是 `TcpLink`）

--- 握手请求头最多收这么多字节（再多就不是握手了）
local MAX_HEAD = 8192

--- 关闭码（RFC 6455）
local NORMAL      = 1000
local PROTOCOL    = 1002
local UNSUPPORTED = 1003

--- WebSocket 上的消息通道：对上层仍是「读字节 / 写消息」，帧与握手在这里消化
--- 分片不记账（续帧的载荷接着攒就是了）；文本帧不收（这条通道是字节流，发二进制）
---@class WsLink : Link
---@field private link Link # 内层那条字节通道
---@field private decoder Websocket.Decoder
---@field private buffer string # 已经解出来的、还没被读走的字节
---@field private closing boolean
---@field private reason? string
local WsLink = Class 'WsLink'

---@param link Link
---@param rest string # 跟着握手一起收到的字节（客户端可能不等应答就把帧发来了）
function WsLink:__init(link, rest)
    self.link    = link
    self.decoder = moe.websocket.decoder()
    self.buffer  = ''
    self.decoder:feed(rest)
end

--- 发一条消息（编成一条二进制帧）
---@param text string
---@return boolean
---@return string?
function WsLink:write(text)
    if self.closing then
        return false, self.reason or '链接已关闭'
    end
    return self.link:write(moe.websocket.encodeFrame(moe.websocket.BINARY, text))
end

--- 读 `n` 个字节（不够就等）；不给 `n` 就把能读的全读走（完全没有数据就等）
---@param n? integer
---@return string?
---@return string?
function WsLink:read(n)
    while true do
        if n then
            if #self.buffer >= n then
                local text = self.buffer:sub(1, n)
                self.buffer = self.buffer:sub(n + 1)
                return text
            end
        elseif self.buffer ~= '' then
            local text = self.buffer
            self.buffer = ''
            return text
        end
        if self.closing then
            return nil, self.reason or '链接已关闭'
        end
        self:receive()
    end
end

--- 关掉它（给对端一条正常关闭帧）
---@param reason? string
function WsLink:close(reason)
    self:shutdown(NORMAL, reason or '链接已关闭')
end

--- 收数据：控制帧当场处理掉，数据帧的载荷攒进缓冲
---@private
function WsLink:receive()
    while true do
        local frame = self:nextFrame()
        if not frame then
            return
        end
        local opcode = frame.opcode
        if opcode == moe.websocket.BINARY or opcode == moe.websocket.CONTINUATION then
            self.buffer = self.buffer .. frame.payload
            return
        end
        if opcode == moe.websocket.PING then
            self.link:write(moe.websocket.encodeFrame(moe.websocket.PONG, frame.payload))
        elseif opcode == moe.websocket.PONG then
            -- 本工程不主动 ping，pong 当没看见
        elseif opcode == moe.websocket.CLOSE then
            self:shutdown(NORMAL, '对端关闭了连接')
            return
        elseif opcode == moe.websocket.TEXT then
            self:shutdown(UNSUPPORTED, '这条通道是字节流，请发二进制帧')
            return
        else
            self:shutdown(PROTOCOL, '不认识的帧类型')
            return
        end
    end
end

--- 解出下一帧（字节不够就往下读 —— 读到一帧或连接没了为止）
---@private
---@return Websocket.Frame?
function WsLink:nextFrame()
    while true do
        local frame, frameErr = self.decoder:next()
        if frame then
            return frame
        end
        if frameErr then
            self:shutdown(PROTOCOL, frameErr)
            return nil
        end
        local chunk, readErr = self.link:read()
        if not chunk then
            self:shutdown(NORMAL, readErr or '链接已关闭')
            return nil
        end
        self.decoder:feed(chunk)
    end
end

--- 关掉它：先给对端一条带码的关闭帧，再关掉底下的连接
---@private
---@param code integer
---@param reason string
function WsLink:shutdown(code, reason)
    if self.closing then
        return
    end
    self.closing = true
    self.reason  = reason
    self.link:write(moe.websocket.encodeFrame(moe.websocket.CLOSE, string.pack('>I2', code)))
    self.link:close(reason)
end

--- 读握手请求头（读到空行为止）；顺带把跟着一起收到的字节还回来
---@async
---@param link Link
---@return string? # 请求头（不含末尾的空行）
---@return string # 后面那些字节
---@return string? # 读不到的原因
local function readHead(link)
    local head = ''
    while true do
        local index = head:find('\r\n\r\n', 1, true)
        if index then
            return head:sub(1, index - 1), head:sub(index + 4)
        end
        if #head > MAX_HEAD then
            return nil, '', '握手请求头太长了'
        end
        local chunk, readErr = link:read()
        if not chunk then
            return nil, '', readErr or '链接已关闭'
        end
        head = head .. chunk
    end
end

--- 谢绝这次握手（回一条 HTTP 应答再把连接关掉）
---@param link Link
---@param status integer
---@param reason string
---@param detail? string # 给连接那头与调用方的原因
---@param headers? table<string, string>
---@return string?
local function refuse(link, status, reason, detail, headers)
    link:write(moe.websocket.refuseText(status, reason, headers))
    link:close(detail)
    return detail
end

--- 握手：把一条刚连上的字节通道接成 WebSocket 链接（读请求头 → 回 101）
---@async
---@param link Link
---@return WsLink?
---@return string?
function moe.link.websocket(link)
    local head, rest, headErr = readHead(link)
    if not head then
        link:close(headErr)
        return nil, headErr
    end
    local request, parseErr = moe.websocket.parseRequest(head)
    if not request then
        return nil, refuse(link, 400, 'Bad Request', parseErr)
    end
    local key = request.headers['sec-websocket-key']
    if not key then
        return nil, refuse(link, 400, 'Bad Request', '握手没带 Sec-WebSocket-Key')
    end
    if request.headers['sec-websocket-version'] ~= '13' then
        return nil, refuse(link, 426, 'Upgrade Required', '只认 Sec-WebSocket-Version: 13',
            { ['Sec-WebSocket-Version'] = '13' })
    end
    link:write(moe.websocket.acceptText(key))
    return New 'WsLink' (link, rest)
end

return moe.link
