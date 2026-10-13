local epoll   = require 'bee.epoll'
local thread  = require 'bee.thread'
local channel = require 'bee.channel'

---@class LoopWaiter.Watch
---@field fd any
---@field onEvent fun(events: integer)

---@class LoopWaiter
local M = {}

local ep, createErr = epoll.create(64)
if not ep then
    error('无法创建 epoll 实例: ' .. tostring(createErr), 0)
end

local wakeChannel = channel.create('moe-kill:event-loop#' .. thread.id)

---@type LoopWaiter.Watch
local wakeWatch = {
    fd = wakeChannel:fd(),
    onEvent = function ()
        local ok = wakeChannel:pop()
        while ok do
            ok = wakeChannel:pop()
        end
    end,
}

local wakeOk, wakeErr = ep:event_add(wakeWatch.fd, epoll.EPOLLIN, wakeWatch)
if not wakeOk then
    error('无法注册自唤醒通道: ' .. tostring(wakeErr), 0)
end

---@param timeout integer # 毫秒，-1 表示无限期
local function waitOnce(timeout)
    for watch, events in ep:wait(timeout) do
        xpcall(watch.onEvent, log.error, events)
    end
end

-- 取出已就绪的事件并分发（不阻塞）
function M.poll()
    waitOnce(0)
end

-- 阻塞等待：睡满秒数，或被事件源 / 唤醒请求打断（nil 表示无限期）
---@param seconds? number
function M.wait(seconds)
    local ms = -1
    if seconds then
        ms = math.floor(seconds * 1000)
        if ms < 0 then
            ms = 0
        end
    end
    waitOnce(ms)
end

-- 请求唤醒：投递一次通知，阻塞中的等待立即返回
--（**瞬时**信号：循环没在阻塞等待时会被它自己的 poll 消费掉 —— 需要持久条件的场合用状态，别指望它）
function M.wake()
    wakeChannel:push(true)
end

-- 注册事件源：关心的事件就绪时调 onEvent（回调自行取走数据）
---@param fd any
---@param onEvent fun(events: integer)
---@param events? integer # `bee.epoll` 的事件位，可组合（省略 = 只关心可读）
---@return LoopWaiter.Watch
function M.watch(fd, onEvent, events)
    ---@type LoopWaiter.Watch
    local watch = {
        fd = fd,
        onEvent = onEvent,
    }
    local ok, err = ep:event_add(fd, events or epoll.EPOLLIN, watch)
    if not ok then
        error('注册外部事件源失败: ' .. tostring(err), 2)
    end
    return watch
end

-- 改一个事件源关心的事件
---@param watch LoopWaiter.Watch
---@param events integer
function M.modify(watch, events)
    local ok, err = ep:event_mod(watch.fd, events, watch)
    if not ok then
        error('改外部事件源失败: ' .. tostring(err), 2)
    end
end

-- 注销一个事件源
---@param watch LoopWaiter.Watch
function M.unwatch(watch)
    ep:event_del(watch.fd)
end

return M
