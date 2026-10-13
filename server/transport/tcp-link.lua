--- TCP 上的消息通道：`bee.socket` 是非阻塞的（`false` = 等待中），等可读 / 可写挂在事件循环的 epoll 上

local epoll = require 'bee.epoll'

---@class TcpLink : Link
---@field private fd bee.socket.fd # 这条连接
---@field private buffer string # 已经收下、还没被读走的字节
---@field private queue string[] # 等着发出去的（一条一个 —— 帧不许交错）
---@field private sending boolean # 写协程在跑吗
---@field private waiting integer # 正在等的事件位（0 = 没人在等）
---@field private readResume? fun() # 正在等可读的那个协程
---@field private writeResume? fun() # 正在等可写的那个协程
---@field private watch? LoopWaiter.Watch
---@field private closing boolean
---@field private reason? string
local TcpLink = Class 'TcpLink'

---@param fd bee.socket.fd
function TcpLink:__init(fd)
    self.fd      = fd
    self.buffer  = ''
    self.queue   = {}
    self.waiting = 0
end

---@private
--- 按「有没有人在等」挂上 / 改 / 撤下事件源（没人在等就撤掉 —— 否则可读的 fd 会让事件循环空转）
function TcpLink:applyWatch()
    if self.waiting == 0 then
        if self.watch then
            moe.loopWaiter.unwatch(self.watch)
            self.watch = nil
        end
        return
    end
    if self.watch then
        moe.loopWaiter.modify(self.watch, self.waiting)
    else
        self.watch = moe.loopWaiter.watch(self.fd, function (events)
            self:onEvent(events)
        end, self.waiting)
    end
end

---@private
---@param events integer
function TcpLink:onEvent(events)
    if events & epoll.EPOLLIN ~= 0 then
        local resume = self.readResume
        if resume then
            self.readResume = nil
            resume()
        end
    end
    if events & epoll.EPOLLOUT ~= 0 then
        local resume = self.writeResume
        if resume then
            self.writeResume = nil
            resume()
        end
    end
end

---@private
--- 挂起当前协程，等这个事件就绪（醒来之后调用方自己重试）
---@param flag integer # `epoll.EPOLLIN` 或 `epoll.EPOLLOUT`
function TcpLink:waitEvent(flag)
    local isRead = flag == epoll.EPOLLIN
    self.waiting = self.waiting | flag
    self:applyWatch()
    moe.await.yield(function (resume)
        if isRead then
            self.readResume = resume
        else
            self.writeResume = resume
        end
    end)
    self.waiting = self.waiting & ~flag
    self:applyWatch()
end

--- 读 `n` 个字节（不够就等）；不给 `n` 就把能读的全读走（完全没有数据就等）
---@param n? integer
---@return string?
---@return string?
function TcpLink:read(n)
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
        local data, err = self.fd:recv()
        if data == false then
            self:waitEvent(epoll.EPOLLIN)
        elseif data == nil then
            self:close(err or '对端已关闭')
        else
            self.buffer = self.buffer .. data
        end
    end
end

--- 把刚读出来的字节退回去（它们会出现在下一次读取的最前面）
---@param text string
function TcpLink:unread(text)
    self.buffer = text .. self.buffer
end

--- 发一条消息（收下就返回；真正发出去由内部的写协程按顺序做 —— 同时写会把帧撕开）
---@param text string
---@return boolean
---@return string?
function TcpLink:write(text)
    if self.closing then
        return false, self.reason or '链接已关闭'
    end
    self.queue[#self.queue + 1] = text
    if not self.sending then
        self.sending = true
        moe.await.call(function ()
            self:flush()
            self.sending = false
        end)
    end
    return true
end

---@private
--- 把排着的消息一条一条发完（发不完就等可写）
function TcpLink:flush()
    while #self.queue > 0 and not self.closing do
        local text = self.queue[1]
        local sent = 0
        while sent < #text do
            local count, err = self.fd:send(text:sub(sent + 1))
            if count == false or count == 0 then
                self:waitEvent(epoll.EPOLLOUT)
                if self.closing then
                    return
                end
            elseif count == nil then
                self:close(err or '发送失败')
                return
            else
                sent = sent + count
            end
        end
        table.remove(self.queue, 1)
    end
end

---@private
--- 关闭前把排着的消息尽力送出去（送不动就算了 —— 这会儿不能等）
function TcpLink:drain()
    while #self.queue > 0 do
        local text  = self.queue[1]
        local count = self.fd:send(text)
        if not count or count == 0 then
            return
        end
        if count >= #text then
            table.remove(self.queue, 1)
        else
            self.queue[1] = text:sub(count + 1)
        end
    end
end

--- 关掉这条链接（还挂着的读写都会收到「链接已关闭」）
---@param reason? string
function TcpLink:close(reason)
    if self.closing then
        return
    end
    self.closing = true
    self.reason  = reason or '链接已关闭'
    self.waiting = 0
    self:applyWatch()
    self:drain()
    self.fd:shutdown()
    self.fd:close()
    local resume = self.readResume
    self.readResume = nil
    if resume then
        resume()
    end
    resume = self.writeResume
    self.writeResume = nil
    if resume then
        resume()
    end
end

--- 把一条已经连上的 TCP 套接字包成链接
---@param fd bee.socket.fd
---@return TcpLink
function moe.link.tcp(fd)
    return New 'TcpLink' (fd)
end

return moe.link
