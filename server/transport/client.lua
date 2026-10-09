--- 收到某条连接上的调用时跑哪个处理器：**全局一张表**（与具体连接无关 —— 重连不用重注册）
---@alias Client.Handler async fun(client: Client, params: any): any

---@type integer # 长度头占几个字节
local HEADER_SIZE = 4

--- 长度头里那个字节数（头 = 4 字节大端无符号，长度不含头本身）
---@param head string
---@return integer
local function decodeFrameLength(head)
    return (string.unpack('>I4', head))
end

--- 给一条消息套上长度头
---@param text string
---@return string
local function encodeFrame(text)
    return string.pack('>I4', #text) .. text
end

--- 一个客户端在后端的代理：一条连接 + 一个 JSON-RPC 端点
---@class Client : Class.Base
---@field link Link # 它走的那条连接
---@field closed boolean # 这条连接收摊了吗
---@field private nextId integer # 出站请求的号（一条连接上一个递增计数器）
---@field private pendings table<integer|string, Task> # 出去了还没回来的那些请求
---@field private task? Task # 读循环
local M = Class 'Client'

---@param link Link
function M:__init(link)
    self.link     = link
    self.closed   = false
    self.nextId   = 0
    self.pendings = {}
end

--- 起读循环：不断读消息交出去，连接断开就收摊
---@return Task
function M:start()
    local task = self.task
    if task then
        return task
    end
    task = moe.task.create { client = self }
    self.task = task
    -- 内联跑到第一个挂起点（读循环一上来就挂在「等消息」上）—— 返回时循环已经就绪
    ---@async
    task:executeSync(function ()
        while true do
            -- 4 字节长度头 → 正文（凑不够就由 link 那头挂着等）
            local head, headErr = self.link:read(HEADER_SIZE)
            if not head then
                self:close(headErr or '连接已断开')
                return
            end
            local text, textErr = self.link:read(decodeFrameLength(head))
            if not text then
                self:close(textErr or '连接已断开')
                return
            end
            self:onMessage(text)
        end
    end)
    return task
end

--- 处理一条从连接上读到的消息
---@param text string
function M:onMessage(text)
    local message, decodeErr = moe.jsonrpc.decode(text)
    if not message then
        self:send(moe.jsonrpc.encodeError(nil, moe.jsonrpc.PARSE_ERROR, '这条消息解析不了', decodeErr))
        return
    end
    if message.method then
        ---@cast message JSONRPC.Request
        if message.id ~= nil then
            self:dispatchCall(message)
        else
            ---@cast message JSONRPC.Notify
            self:dispatchNotification(message)
        end
        return
    end
    ---@cast message JSONRPC.Result|JSONRPC.Error
    if message.id ~= nil then
        self:settleCall(message)
    end
end

--- 收摊：标记关闭，把还在等的请求全部以「连接断开」收尾
---@param reason? string
function M:close(reason)
    if self.closed then
        return
    end
    self.closed = true
    local text = reason or '连接已关闭'
    for id, task in pairs(self.pendings) do
        self.pendings[id] = nil
        task:reject(text)
        Delete(task)
    end
    -- 连接那头没断的话（比如被直接关掉），把它也叫醒
    local link = self.link
    if link.close then
        link:close(text)
    end
end

--- 发一个通知
---@param method string
---@param params? any
---@return boolean
---@return string?
function M:notify(method, params)
    if self.closed then
        return false, '连接已关闭'
    end
    return self:send(moe.jsonrpc.encodeCall(nil, method, params))
end

--- 发一个请求（返回它这次的任务；给了 `callback` 就同时挂上，参数同 `Task:await` 的两个返回值）
---@param method string
---@param params? any
---@param callback? fun(result: any, err: any)
---@return Task
function M:request(method, params, callback)
    self.nextId = self.nextId + 1
    local id   = self.nextId
    local task = moe.task.create { client = self, id = id }
    if callback then
        task:onResolved(function (result)
            callback(result, nil)
        end)
        task:onRejected(function (err)
            callback(nil, err)
        end)
    end
    self.pendings[id] = task
    local ok, err = self:send(moe.jsonrpc.encodeCall(id, method, params))
    if not ok then
        self.pendings[id] = nil
        task:reject(err or '发送失败')
        Delete(task)
    end
    return task
end

--- 发一个请求并等它回来（拿不到就给空 + 原因，不抛）
---@async
---@param method string
---@param params? any
---@return any # 结果
---@return any # 失败的原因（没有就是空）
function M:awaitRequest(method, params)
    return self:request(method, params):await()
end

--- 发一条消息（套上长度头；发不出去只记一条日志 —— 连接坏了由读循环那头收摊）
---@private
---@param text string
---@return boolean
---@return string?
function M:send(text)
    local ok, err = self.link:write(encodeFrame(text))
    if not ok then
        log.warn('往客户端发消息失败：{}' % { err or '未知原因' })
    end
    return ok, err
end

--- 入站请求：交给注册的处理器，结果编成响应发回去（处理器另起一个协程跑，读循环不被它挡住）
---@private
---@param message JSONRPC.Request
function M:dispatchCall(message)
    local method  = assert(message.method)
    local id      = assert(message.id)
    local handler = moe.client._handlers[method]
    if not handler then
        self:send(moe.jsonrpc.encodeError(id, moe.jsonrpc.METHOD_NOT_FOUND, '没有「{}」这个方法' % { method }))
        return
    end
    local client  = self
    local params  = message.params
    ---@async
    moe.await.call(function ()
        local ok, result = xpcall(handler, log.error, client, params)
        if not ok then
            self:send(moe.jsonrpc.encodeError(id, moe.jsonrpc.INTERNAL_ERROR, '处理这个方法时出错'))
            return
        end
        self:send(moe.jsonrpc.encodeResult(id, result))
    end)
end

--- 入站通知：交给注册的处理器（没有地方回答，出错只记日志）
---@private
---@param message JSONRPC.Notify
function M:dispatchNotification(message)
    local method  = assert(message.method)
    local handler = moe.client._handlers[method]
    if not handler then
        log.warn('收到没注册过的通知「{}」' % { method })
        return
    end
    local client = self
    local params = message.params
    ---@async
    moe.await.call(function ()
        xpcall(handler, log.error, client, params)
    end)
end

--- 出站请求回来了：把等它的那个任务交出去
---@private
---@param message JSONRPC.Result|JSONRPC.Error
function M:settleCall(message)
    local id   = assert(message.id)
    local task = self.pendings[id]
    if not task then
        log.warn('收到不认识的结果（id = {}）' % { tostring(id) })
        return
    end
    self.pendings[id] = nil
    if message.error then
        ---@cast message JSONRPC.Error
        task:reject(message.error)
    else
        ---@cast message JSONRPC.Result
        task:resolve(message.result)
    end
    Delete(task)
end

---@class Client.API
moe.client = {}

--- 所有连接共用一张方法表（`register` 注册进来的都在这儿）
---@type table<string, Client.Handler>
moe.client._handlers = moe.client._handlers or {}

--- 注册一个方法（客户端的请求与通知都走它）；返回撤销这次注册的函数
---@param method string
---@param handler Client.Handler
---@return fun()
function moe.client.register(method, handler)
    if type(method) ~= 'string' or method == '' then
        error('方法名必须是非空字符串', 2)
    end
    if moe.client._handlers[method] then
        error('方法「{}」已经注册过了' % { method }, 2)
    end
    moe.client._handlers[method] = handler
    local removed = false
    return function ()
        if removed then
            return
        end
        removed = true
        moe.client._handlers[method] = nil
    end
end

--- 建一个客户端代理
---@param link Link
---@return Client
function moe.client.create(link)
    return New 'Client' (link)
end

return moe.client
