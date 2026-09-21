---@alias Server.Phase 'pending' | 'running' | 'finished' | 'aborted' | 'destroyed'

---@class Server.Handler
---@field run async fun(self: Server.Handler, session: Server.Session)

---@class Server.Request
---@field kind string
---@field payload? table

---@class Server.Event
---@field kind string
---@field payload? table

---@class Server.Waiter
---@field resume fun(ok: boolean, ...)
---@field timer? Timer

---@class Server.Session
---@field private reason? string
---@field private events Server.Event[]
---@field private pendingRequest? Server.Request
---@field private waiter? Server.Waiter
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

---@private
---@param ok boolean
---@param ... any
---@return boolean
function Session:wake(ok, ...)
    local waiter = self.waiter
    if not waiter then
        return false
    end
    self.pendingRequest = nil
    self.waiter = nil
    if waiter.timer then
        waiter.timer:remove()
        waiter.timer = nil
    end
    waiter.resume(ok, ...)
    return true
end

---@param handler Server.Handler
function Session:__init(handler)
    self.handler = handler
    self.phase   = Phase.PENDING
    self.events  = {}
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
    if self.waiter then
        self:wake(false, '会话已结束')
    end
end

---@param reason? string
function Session:abort(reason)
    self:checkPhase('中止', Phase.PENDING, Phase.RUNNING)
    self.phase  = Phase.ABORTED
    self.reason = reason
    if self.waiter then
        self:wake(false, reason or '会话已中止')
    end
end

---@return boolean
function Session:destroy()
    if self.phase == Phase.DESTROYED then
        return false
    end
    self.phase = Phase.DESTROYED
    unregister(self)
    if self.waiter then
        self:wake(false, '会话已销毁')
    end
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
    if self.pendingRequest then
        error('已存在等待中的决策请求', 2)
    end
    if not coroutine.isyieldable() then
        error('决策请求必须在会话协程内发起', 2)
    end
    self.pendingRequest = {
        kind    = kind,
        payload = payload,
    }
    local settled = table.pack(moe.await.yield(function (resume)
        ---@type Server.Waiter
        local waiter = {
            resume = resume,
        }
        self.waiter = waiter
        if timeout then
            waiter.timer = moe.timer.wait(timeout, function ()
                self:wake(false, '决策等待超时')
            end)
        end
    end))
    if not settled[1] then
        error(settled[2], 0)
    end
    return table.unpack(settled, 2, settled.n)
end

---@return Server.Request?
function Session:getPendingRequest()
    return self.pendingRequest
end

---@param ... any
function Session:submit(...)
    self:checkPhase('提交输入', Phase.RUNNING)
    if not self.waiter then
        error('当前没有等待中的决策请求', 2)
    end
    self:wake(true, ...)
end

---@param reason? string
function Session:cancelRequest(reason)
    self:checkPhase('取消决策请求', Phase.RUNNING)
    if not self.waiter then
        error('当前没有等待中的决策请求', 2)
    end
    self:wake(false, reason or '决策请求已取消')
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
    ---@type Server.Event[]
    local snapshot = {}
    return table.move(self.events, 1, #self.events, 1, snapshot)
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
