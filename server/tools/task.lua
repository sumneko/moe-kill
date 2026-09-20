---@class Task : GCHost # 可等待的任务：驱动协程、交出结果、叫醒等待者
---@field context table # 任务上下文
---@field resolved boolean # 是否已经结完（完成或失败都算）
---@field result? any # 结果
---@field err? any # 失败
---@field private threads thread[] # 这个任务起的协程
---@field private awaitings fun(result: any, err: any)[] # 正在等它的那些协程
local M = Class 'Task'

Extends('Task', 'GCHost')

---@class Task.API
local API = {}

API.CLOSED   = 'closed'
API.CANCELED = 'canceled'
API.TIMEOUT  = 'timeout'

local errorHandler

---@param context? table
function M:__init(context)
    self.context   = context or {}
    self.resolved  = false
    self.threads   = {}
    self.awaitings = {}
end

---@private
function M:__del()
    for _, co in ipairs(self.threads) do
        if coroutine.status(co) == 'suspended' then
            coroutine.close(co)
        end
    end
end

--- 以「关闭」收尾（由 to-be-closed 变量关闭时触发）
---@param err? any
function M:__close(err)
    self:reject(err or API.CLOSED)
end

---@param callback fun(result: any)
---@return Task
function M:onResolved(callback)
    self._onResolved = callback
    if self.resolved then
        callback(self.result)
    end
    return self
end

---@param callback fun(err: any)
---@return Task
function M:onRejected(callback)
    self._onRejected = callback
    if self.resolved and self.err then
        callback(self.err)
    end
    return self
end

--- 完成这次任务
---@param result? any
function M:resolve(result)
    if self.resolved then
        return
    end
    self.resolved = true
    self.result   = result
    if self._onResolved then
        self._onResolved(result)
    end
    self:resolveAwaitings()
    Delete(self)
end

--- 让这次任务失败
---@param err any
function M:reject(err)
    if self.resolved then
        return
    end
    self.resolved = true
    self.err      = err
    if self._onRejected then
        self._onRejected(err)
    end
    self:resolveAwaitings()
    Delete(self)
end

--- 到点还没结完就以「超时」失败
---@param timeout number
function M:setTimeout(timeout)
    self:bindGC(moe.timer.wait(timeout, function ()
        self:reject(API.TIMEOUT)
    end))
end

---@private
function M:resolveAwaitings()
    for _, resume in ipairs(self.awaitings) do
        resume(self.result, self.err)
    end
end

---@type table<thread, Task>
local taskMap = setmetatable({}, { __mode = 'k' })

--- 起一个协程跑这次任务；跑完自动完成，报错记成失败
---@param func fun(task: Task)
---@return Task
function M:execute(func)
    local co
    ---@async
    moe.await.call(function ()
        co = coroutine.running()
        taskMap[co] = self
        table.insert(self.threads, co)
        xpcall(func, function (err)
            if errorHandler then
                errorHandler(err)
            end
            self:reject(err)
        end, self)
        self:resolve()
    end)
    if co and self.resolved and coroutine.status(co) == 'suspended' then
        -- 任务已经结完了，但执行体还挂着（例如它被取消）：收掉它，让退栈发生
        coroutine.close(co)
    end
    return self
end

--- 让出一个调度
---@async
function M:delay()
    if coroutine.isyieldable() then
        moe.await.sleep(0)
    end
end

--- 等它结完
---@async
---@return any # 结果
---@return any # 失败
function M:await()
    if self.resolved then
        return self.result, self.err
    end
    return moe.await.yield(function (resume)
        self.awaitings[#self.awaitings+1] = resume
    end)
end

--- 设置全局错误处理器（自动失败前先调它）
---@param handler? fun(err: any): any
function API.setErrorHandler(handler)
    errorHandler = handler
end

---@param context? table
---@return Task
function API.create(context)
    return New 'Task' (context)
end

---@return Task? # 当前协程属于哪个任务
function API.getCurrentTask()
    return taskMap[coroutine.running()]
end

return API
