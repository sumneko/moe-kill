---@class Task : GCHost # 可等待的任务：驱动协程、交出结果、叫醒等待者
---@field context table # 任务上下文
---@field resolved boolean # 结果是否已经定下
---@field result? any # 结果
---@field err? any # 失败
---@field private thread? thread # 这个任务的协程（一个任务只驱动一次）
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
    self.awaitings = {}
end

--- 收口：定结果 → 叫回调 → 叫醒等它的人 → 收掉自己的执行体（只有 `Delete` 会走到这里）
---@private
function M:__del()
    self:reject(API.CLOSED)
    if self.err == nil then
        if self._onResolved then
            self._onResolved(self.result)
        end
    else
        if self._onRejected then
            self._onRejected(self.err)
        end
    end
    self:resolveAwaitings()

    local co = self.thread
    if not co then
        return
    end
    if co == coroutine.running() then
        -- 自己就是那个执行体：交给下一个调度再关（当场关会把这一帧后面的一起丢掉）
        moe.await.wake(function ()
            coroutine.close(co)
        end)
    elseif coroutine.status(co) == 'suspended' then
        coroutine.close(co)
    end
end

--- 以「关闭」收尾（由 to-be-closed 变量关闭时触发）
---@param err? any
function M:__close(err)
    self:cancel(err or API.CLOSED)
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

--- 完成这次任务：只把结果记下来，收口交给 `Delete`（见 `__del`）
---@param result? any
function M:resolve(result)
    if self.resolved then
        return
    end
    self.resolved = true
    self.result   = result
end

--- 让这次任务失败：只把原因记下来，收口交给 `Delete`（见 `__del`）
---@param err any
function M:reject(err)
    if self.resolved then
        return
    end
    self.resolved = true
    self.err      = err
end

--- 停掉这次任务：优先级最高（结果已经定过也强行改成「取消」），当场收口；已经删除过（收口过）就不再动
---@param err? any
function M:cancel(err)
    if not IsValid(self) then
        return
    end
    self.resolved = true
    self.result   = nil
    self.err      = err or API.CANCELED
    Delete(self)
    if self.thread == coroutine.running() then
        -- 自己就是那个执行体：收口时已登记「下一笔关掉它」，就此让出（不会再被唤醒）
        if coroutine.isyieldable() then
            coroutine.yield()
        end
    end
end

--- 到点还没结完就以「超时」停掉
---@param timeout number
function M:setTimeout(timeout)
    self:bindGC(moe.timer.wait(timeout, function ()
        self:cancel(API.TIMEOUT)
    end))
end

---@private
function M:resolveAwaitings()
    local result, err = self.result, self.err
    for _, resume in ipairs(self.awaitings) do
        -- 不内联恢复：登记到下一笔调度，C 栈深度与逻辑深度脱钩（见 architecture.md 第 12 节）
        moe.await.wake(function ()
            resume(result, err)
        end)
    end
end

---@type table<thread, Task>
local taskMap = setmetatable({}, { __mode = 'k' })

--- 起一个协程立即跑这次任务；跑完自动完成（执行体的返回值就是结果），报错记成失败
---@param func fun(task: Task): any
---@return Task
function M:executeSync(func)
    self.parent = coroutine.running()

    ---@async
    moe.await.call(function ()
        self.thread = coroutine.running()
        taskMap[self.thread] = self
        local ok, result = xpcall(func, function (err)
            if errorHandler then
                errorHandler(err)
            end
            self:reject(err)
        end, self)
        if ok then
            self:resolve(result)
        end
        Delete(self)
    end)

    return self
end

--- 起一个协程准备这次任务；跑完自动完成（执行体的返回值就是结果），报错记成失败
--- 会在当前协程让出后才会开始跑，或者用 `await` 来跑。
---@param func fun(task: Task): any
---@return Task
function M:executeAsync(func)
    self.parent = coroutine.running()

    ---@async
    moe.await.call(function ()
        self.thread = coroutine.running()
        taskMap[self.thread] = self
        self:delay()
        local ok, result = xpcall(func, function (err)
            if errorHandler then
                errorHandler(err)
            end
            self:reject(err)
        end, self)
        if ok then
            self:resolve(result)
        end
        Delete(self)
    end)

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

--- 一次 race 的赢家
---@class Task.RaceWinner
---@field win integer # 赢家编号
---@field task Task

--- 并发跑多路，**谁先结完算谁赢、其余当场取消**（取消会连带收掉挂在它们下面的结算）
---@async
---@param branches (fun(task: Task): any)[] # 各路（各自同步风格地写；要用自己的 task 就收参数）
---@return Task.RaceWinner # 赢家（一路都没结完 = nil）
function API.race(branches)
    local count = #branches
    ---@type Task[]
    local tasks = {}

    for i = 1, count do
        tasks[i] = API.create():executeAsync(branches[i])
    end

    local win = moe.await.race(moe.util.map(tasks, function (task)
        return function () task:await() end
    end))

    -- 输家当场取消：连带收掉挂在它下面的结算
    for i = 1, count do
        if i ~= win then
            tasks[i]:cancel()
        end
    end

    local winner = {
        win = win,
        task = tasks[win],
    }

    return winner
end

--- 并发跑多路，**第一个成功算赢、报错的不算赢**（等别的路；全失败给 nil），其余当场取消
---@async
---@param branches (fun(task: Task): any)[] # 各路（各自同步风格地写；要用自己的 task 就收参数）
---@return Task.RaceWinner? # 赢家（一路都没成功 = nil）
function API.any(branches)
    local count = #branches
    ---@type Task[]
    local tasks = {}

    local win = moe.await.yield(function (resume)
        local alive = count
        for i = 1, count do
            tasks[i] = API.create()
                : onResolved(function ()
                    resume(i)
                end)
                : onRejected(function ()
                    -- 报错的不算赢；都倒下了才收工
                    alive = alive - 1
                    if alive == 0 then
                        resume(nil)
                    end
                end)
                : executeAsync(branches[i])
        end
    end)

    if not win then
        return nil
    end

    for i = 1, count do
        if i ~= win then
            tasks[i]:cancel()
        end
    end

    return {
        win = win,
        task = tasks[win],
    }
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
