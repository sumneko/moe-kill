local thread = require 'bee.thread'

---@class EventLoop.Options
---@field waiter?   fun(seconds: number?) # 阻塞等待：睡满秒数，或被完成事件 / 唤醒请求打断；nil 表示无限期等待直到被唤醒
---@field deadline? fun(): number?        # 距离下一个定时任务到期还有多少秒；没有定时任务时返回 nil
---@field waker?    fun()                 # 请求立即唤醒正在阻塞的等待

---@class EventLoop
local M = {}

---@package
M.tasks = {}
---@package
M.highTasks = {}
---@package
M.started = false

---@type fun(seconds: number?)
local waiter = function (seconds)
    if not seconds then
        seconds = 0.1
    end
    thread.sleep(math.max(math.floor(seconds * 1000), 1))
end

---@type fun(): number?
local deadline = function ()
    return nil
end

---@type fun()
local waker = function ()
end

---@param options? EventLoop.Options
---@param errorHandler? fun(err: string)
---@return boolean
function M.start(options, errorHandler)
    options = options or {}
    waiter   = options.waiter   or waiter
    deadline = options.deadline or deadline
    waker    = options.waker    or waker
    if not errorHandler then
        errorHandler = print
    end
    M.started = true
    while M.started do
        M.runTask(errorHandler)
        M.runDelayQueue(100, errorHandler)
        if M.started and not M.delayQueue then
            waiter(M.getWaitSeconds())
        end
    end
    return true
end

---@return boolean
function M.stop()
    if not M.started then
        return false
    end
    M.started = false
    waker()
    return true
end

-- 请求立即唤醒正在阻塞的等待
function M.wake()
    waker()
end

---@private
---@return number?
function M.getWaitSeconds()
    local seconds = deadline()
    if not seconds then
        return nil
    end
    local ms = math.ceil(seconds * 1000) + 1
    if ms < 1 then
        ms = 1
    end
    return ms / 1000
end

---@private
function M.runTask(errorHandler)
    for i = 1, #M.highTasks do
        xpcall(M.highTasks[i], errorHandler)
    end
    for i = 1, #M.tasks do
        xpcall(M.tasks[i], errorHandler)
    end
end

---@private
---@param max integer
---@param errorHandler fun(err: any)
---@return boolean # 是否还有剩余任务
function M.runDelayQueue(max, errorHandler)
    local queue = M.delayQueue
    if not queue then
        return false
    end
    for i = 1, max do
        if not queue[i] then
            break
        end
        xpcall(queue[i], errorHandler)
        for j = 1, #M.highTasks do
            xpcall(M.highTasks[j], errorHandler)
        end
    end
    if not queue[max + 1] then
        M.delayQueue = nil
        return false
    end
    M.delayQueue = {}
    table.move(queue, max + 1, #queue, 1, M.delayQueue)
    return true
end

---@param callback fun()
function M.addTask(callback)
    M.tasks[#M.tasks+1] = callback
end

---@param callback fun()
function M.addHighTask(callback)
    M.highTasks[#M.highTasks+1] = callback
end

function M.addDelayQueue(callback)
    if not M.delayQueue then
        M.delayQueue = {}
    end
    M.delayQueue[#M.delayQueue+1] = callback
end

return M
