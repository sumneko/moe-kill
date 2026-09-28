local epoll   = require 'bee.epoll'
local thread  = require 'bee.thread'
local channel = require 'bee.channel'

---@class LoopWaiter.Watch
---@field fd any
---@field onReadable fun()

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
    onReadable = function ()
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
    for watch in ep:wait(timeout) do
        xpcall(watch.onReadable, log.error)
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

-- 注册可读事件源：变为可读时调用 onReadable（回调自行取走数据）
---@param fd any
---@param onReadable fun()
---@return LoopWaiter.Watch
function M.watch(fd, onReadable)
    ---@type LoopWaiter.Watch
    local watch = {
        fd = fd,
        onReadable = onReadable,
    }
    local ok, err = ep:event_add(fd, epoll.EPOLLIN, watch)
    if not ok then
        error('注册外部事件源失败: ' .. tostring(err), 2)
    end
    return watch
end

return M
