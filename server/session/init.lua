---@alias Server.Phase 'pending' | 'running' | 'finished' | 'aborted' | 'destroyed'

---@class Server.Handler
---@field run async fun(self: Server.Handler, session: Server.Session)

---@class Server.Request
---@field kind string # 类型标识（驱动者据此决定怎么问）
---@field payload? table # 随请求带走的信息
---@field resume fun(ok: boolean, ...) # 内部用：挂起方（有答复 / 被取消 / 超时的时候叫醒它）
---@field timer? Timer # 内部用：这次请求的超时定时器

---@class Server.Event
---@field kind string
---@field payload? table

---@class Server.Session
---@field private reason? string
---@field private events Server.Event[]
---@field private pendingRequests Server.Request[] # 同时在等的请求（互不干扰，可以有好几条）
local Session = Class 'Server.Session'

---@type table<string, Server.Phase>
local Phase = {
    PENDING   = 'pending',
    RUNNING   = 'running',
    FINISHED  = 'finished',
    ABORTED   = 'aborted',
    DESTROYED = 'destroyed',
}

---@type Server.Session?
local currentSession

---@param session Server.Session
local function unregister(session)
    if currentSession == session then
        currentSession = nil
    end
end

---@param requests Server.Request[]
---@param request Server.Request
---@return integer? # 它排在第几条
local function findRequest(requests, request)
    for i = 1, #requests do
        if requests[i] == request then
            return i
        end
    end
end

---@private
---@param action string
---@param ... Server.Phase
function Session:checkPhase(action, ...)
    if self.phase == Phase.DESTROYED then
        error('会话已销毁，无法{}' % { action }, 3)
    end
    local expected = table.pack(...)
    for i = 1, expected.n do
        if self.phase == expected[i] then
            return
        end
    end
    error('会话当前阶段为 {}，无法{}' % { self.phase, action }, 3)
end

--- 定下一条请求：从等候名单摘掉、停掉它的超时、叫醒挂起方
---@private
---@param request Server.Request
---@param ok boolean
---@param ... any
---@return boolean # 它是否确实还在等
function Session:settle(request, ok, ...)
    local index = findRequest(self.pendingRequests, request)
    if not index then
        return false
    end
    table.remove(self.pendingRequests, index)
    local timer = request.timer
    if timer then
        timer:remove()
        request.timer = nil
    end
    request.resume(ok, ...)
    return true
end

--- 叫醒所有挂起方（会话结束 / 中止 / 销毁的时候）
---@private
---@param ok boolean
---@param ... any
function Session:wake(ok, ...)
    ---@type Server.Request[]
    local requests = moe.util.copy(self.pendingRequests)
    for _, request in ipairs(requests) do
        self:settle(request, ok, ...)
    end
end

---@param handler Server.Handler
function Session:__init(handler)
    self.handler = handler
    self.phase   = Phase.PENDING
    self.events  = {}
    self.pendingRequests = {}
end

---@return Server.Phase
function Session:getPhase()
    return self.phase
end

---@return string?
function Session:getAbortReason()
    return self.reason
end

function Session:start()
    self:checkPhase('启动', Phase.PENDING)
    self.phase = Phase.RUNNING
    ---@async
    moe.await.call(function ()
        local ok, err = xpcall(self.handler.run, log.error, self.handler, self)
        if not ok then
            if self.phase == Phase.RUNNING then
                self:abort(err)
            end
            return
        end
        if self.phase == Phase.RUNNING then
            self.phase = Phase.FINISHED
        end
    end)
end

function Session:finish()
    self:checkPhase('结束', Phase.RUNNING)
    self.phase = Phase.FINISHED
    self:wake(false, '会话已结束')
end

---@param reason? string
function Session:abort(reason)
    self:checkPhase('中止', Phase.PENDING, Phase.RUNNING)
    self.phase  = Phase.ABORTED
    self.reason = reason
    self:wake(false, reason or '会话已中止')
end

---@return boolean
function Session:destroy()
    if self.phase == Phase.DESTROYED then
        return false
    end
    self.phase = Phase.DESTROYED
    unregister(self)
    self:wake(false, '会话已销毁')
    return true
end

---@async
---@param kind string
---@param payload? table
---@param timeout? number
---@return ...
function Session:requestInput(kind, payload, timeout)
    self:checkPhase('请求输入', Phase.RUNNING)
    if type(kind) ~= 'string' or kind == '' then
        error('决策请求的类型标识必须是非空字符串', 2)
    end
    if not coroutine.isyieldable() then
        error('决策请求必须在会话协程内发起', 2)
    end

    ---@type Server.Request
    local request
    local settled = table.pack(moe.await.yield(function (resume)
        request = {
            kind    = kind,
            payload = payload,
            resume  = resume,
        }
        self.pendingRequests[#self.pendingRequests + 1] = request
        if timeout then
            request.timer = moe.timer.wait(timeout, function ()
                self:settle(request, false, '决策等待超时')
            end)
        end
    end))
    if not settled[1] then
        error(settled[2], 0)
    end
    return table.unpack(settled, 2, settled.n)
end

--- 读当前所有在等的请求（快照）
---@return Server.Request[]
function Session:getPendingRequests()
    return moe.util.copy(self.pendingRequests)
end

---@param request Server.Request
---@param ... any
function Session:submit(request, ...)
    self:checkPhase('提交输入', Phase.RUNNING)
    if not self:settle(request, true, ...) then
        error('没有这条等待中的决策请求', 2)
    end
end

---@param request Server.Request
---@param reason? string
function Session:cancelRequest(request, reason)
    self:checkPhase('取消决策请求', Phase.RUNNING)
    if not self:settle(request, false, reason or '决策请求已取消') then
        error('没有这条等待中的决策请求', 2)
    end
end

---@param kind string
---@param payload? table
function Session:emit(kind, payload)
    if self.phase == Phase.DESTROYED then
        error('会话已销毁，无法发出事件', 2)
    end
    self.events[#self.events + 1] = {
        kind    = kind,
        payload = payload,
    }
end

---@return Server.Event[]
function Session:getEvents()
    return moe.util.copy(self.events)
end

---@class Server
moe.server = {}

moe.server.Phase = Phase

moe.server.started = false

---@return boolean
function moe.server.start()
    if moe.server.started then
        return false
    end
    moe.server.started = true
    log.info('服务器已启动')
    return true
end

---@return boolean
function moe.server.stop()
    if not moe.server.started then
        return false
    end
    moe.server.started = false
    log.info('服务器已停止')
    return true
end

---@return boolean
function moe.server.isStarted()
    return moe.server.started
end

---@return Server.Session?
function moe.server.getSession()
    return currentSession
end

---@return boolean
function moe.server.hasSession()
    return currentSession ~= nil
end

---@param handler Server.Handler
---@return Server.Session
function moe.server.createSession(handler)
    if type(handler) ~= 'table' then
        error('逻辑处理器必须是 table', 2)
    end
    if type(handler.run) ~= 'function' then
        error('逻辑处理器必须实现 run 方法', 2)
    end
    if currentSession then
        error('已存在会话，需先销毁', 2)
    end
    local session = New 'Server.Session' (handler)
    currentSession = session
    return session
end

---@param session Server.Session
---@return boolean
function moe.server.destroySession(session)
    if Type(session) ~= 'Server.Session' then
        error('参数不是会话对象', 2)
    end
    if session.phase == Phase.DESTROYED then
        return false
    end
    if currentSession ~= session then
        error('该会话不是当前会话', 2)
    end
    return session:destroy()
end
