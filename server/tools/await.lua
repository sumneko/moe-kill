---@class Await
local M = {}

---@type fun(traceback: string)
local errorHandler = function () end

---@type fun(time: number, callback: fun())?
local waker

local function presume(co, ...)
    local suc, err = coroutine.resume(co, ...)
    if not suc then
        errorHandler(debug.traceback(co, err))
        coroutine.close(co)
    end
end

---@class Await.API
local API = {}

--当前协程休眠一会儿
---@async
---@param time number
function API.sleep(time)
    if not waker then
        error('需要先试用 setSleepWaker 设置唤醒器')
    end
    if not coroutine.isyieldable() then
        errorHandler(debug.traceback('当前协程无法让出！'))
        return
    end
    local co = coroutine.running()
    waker(time, function ()
        if coroutine.status(co) ~= 'suspended' then
            return
        end
        presume(co)
    end)
    coroutine.yield()
end

--当前协程让出
---@async
---@param callback fun(resume: fun(...)) # 当前协程让出，直到 resume 被调用。调用 resume 传入的参数将作为当前协程的返回值。
---@return ...
function API.yield(callback)
    local co = coroutine.running()
    local resolved, yielded, fastResults
    local function resume(...)
        if resolved then
            return
        end
        resolved = true
        if yielded then
            if coroutine.status(co) ~= 'suspended' then
                return
            end
            presume(co, ...)
        else
            fastResults = table.pack(...)
        end
    end
    callback(resume)
    if resolved then
        return table.unpack(fastResults, 1, fastResults.n)
    else
        yielded = true
        return coroutine.yield()
    end
end

---@param callback async fun()
---@return thread
function API.call(callback)
    local co = coroutine.create(callback)
    presume(co)
    return co
end

---当前协程等待多个异步函数执行完毕
---@async
---@param callbacks async fun()[]
---@return [boolean, ...][]
function API.waitAll(callbacks)
    local cur = coroutine.running()
    local cos = {}
    local results = {}
    local count = #callbacks
    for i = 1, count do
        local callback = callbacks[i]
        local co = coroutine.create(function ()
            results[i] = { xpcall(callback, errorHandler) }
            count = count - 1
            if count == 0 and coroutine.status(cur) == 'suspended' then
                presume(cur)
            end
        end)
        cos[i] = co
    end
    for i = 1, count do
        local co = cos[i]
        presume(co)
    end
    if count > 0 then
        coroutine.yield()
    end
    return results
end

---当前协程并发跑多个异步函数，返回**最先结束的那一路**（报错也算结束；其余各跑各的，这里**不管**它们 —— 要连取消一起做用 `moe.task.race`，要「第一个成功」的用 `moe.task.any`）
---@async
---@param callbacks (async fun(): any)[] # 若干路（各自的返回值就是它这一路的结果）
---@return integer # 先结束的那条路的编号
---@return [boolean, ...][]
function API.race(callbacks)
    local cur = coroutine.running()
    local count = #callbacks
    ---@type thread[]
    local cos = {}
    ---@type integer?
    local winner = nil
    local results = {}

    for i = 1, count do
        local callback = callbacks[i]
        local co = coroutine.create(function ()
            results[i] = { xpcall(callback, errorHandler) }
            if winner == nil then
                winner = i
                if coroutine.status(cur) == 'suspended' then
                    presume(cur)
                end
            end
        end)
        cos[i] = co
    end
    for i = 1, count do
        local co = cos[i]
        presume(co)
    end
    if not winner then
        coroutine.yield()
    end
    ---@cast winner -?
    return winner, results
end

--把一笔回调登记到下一个调度（不让当前协程让出）
---@param callback fun()
function API.wake(callback)
    if not waker then
        error('需要先试用 setSleepWaker 设置唤醒器')
    end
    waker(0, callback)
end

--设置错误处理器
---@param handler fun(traceback: string) # 当有错误发生时，会以错误堆栈为参数调用该函数
function API.setErrorHandler(handler)
    errorHandler = handler
end

--设置唤醒器
---@param f fun(time: number, callback: fun()) # 需要传入一个计时器实现函数。当时间到达时，实现函数需要调用 callback。
function API.setSleepWaker(f)
    waker = f
end

return API
