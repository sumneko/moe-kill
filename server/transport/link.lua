--- 一条双向的消息通道：读一条 / 写一条（帧与连接由实现自己管 —— TCP / 内存……）
---@class Link
---@field read async fun(self: Link, n?: integer): string?, string? # 读 `n` 个字节（不够就挂起）；不给 `n` 就把能读的全读走（完全没有数据就挂起）；断开或出错时给空 + 原因
---@field write fun(self: Link, text: string): boolean, string? # 发一条消息：失败给 false + 原因
---@field close? fun(self: Link, reason?: string) # 关掉它（可选 —— 有这一手的实现才写）

--- 内存里的链接（一对互相连通 —— 本地回环与测试用）
---@class MemoryLink : Link
---@field package other MemoryLink # 对面那一端
---@field package buffer string # 还没被读走的字节
---@field package waiter? fun() # 正在等数据的那个读者
---@field package closed boolean
---@field package reason? string
local MemoryLink = Class 'MemoryLink'

function MemoryLink:__init()
    self.buffer = ''
end

---@param text string
---@return boolean
---@return string?
function MemoryLink:write(text)
    if self.closed then
        return false, self.reason or '链接已关闭'
    end
    local other = self.other
    if other.closed then
        return false, other.reason or '对端已关闭'
    end
    other.buffer = other.buffer .. text
    other:wake()
    return true
end

--- 读 `n` 个字节（不够就挂起）；不给 `n` 就把能读的全读走（完全没有数据就挂起）
---@param n? integer
---@return string?
---@return string?
function MemoryLink:read(n)
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
        if self.closed then
            return nil, self.reason or '链接已关闭'
        end
        moe.await.yield(function (resume)
            self.waiter = resume
        end)
    end
end

--- 关掉这条链接（两端一起 —— 断开是双向的）
---@param reason? string
function MemoryLink:close(reason)
    local other = self.other
    if self.closed and other.closed then
        return
    end
    local text = reason or '链接已关闭'
    self.closed  = true
    self.reason  = text
    other.closed = true
    other.reason = text
    self:wake()
    other:wake()
end

---@private
function MemoryLink:wake()
    local waiter = self.waiter
    self.waiter = nil
    if waiter then
        waiter()
    end
end

---@class Link.API
moe.link = {}

--- 造一对互相连通的链接
---@return MemoryLink
---@return MemoryLink
function moe.link.pair()
    local a = New 'MemoryLink' ()
    local b = New 'MemoryLink' ()
    a.other = b
    b.other = a
    return a, b
end

return moe.link
