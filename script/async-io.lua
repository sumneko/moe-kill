local async   = require 'bee.async'
local channel = require 'bee.channel'
local fs      = require 'bee.filesystem'

---@class AsyncIO.Watch
---@field fd any
---@field onReadable fun()

---@class AsyncIO.Register
---@field resolve? fun(ok: boolean, data: any) # 文件类操作的完成结果交回发起方
---@field watch? AsyncIO.Watch                # 可读事件源

---@class AsyncIO
local M = {}

local instance, createErr = async.create(64)
if not instance then
    error('无法创建异步 I/O 实例: ' .. tostring(createErr), 0)
end

M.instance = instance

---@param path string|bee.fspath
---@return string
local function toString(path)
    if type(path) == 'string' then
        return path
    end
    return path:string()
end

---@param watch AsyncIO.Watch
---@return boolean
---@return string?
local function arm(watch)
    if not instance:associate(watch.fd) then
        return false, '无法把事件源关联到异步 I/O 实例'
    end
    local ok, err = instance:submit_poll(watch.fd, {
        watch = watch,
    })
    return ok == true, err
end

---@param op integer
---@param reg AsyncIO.Register
---@param status integer
---@param data integer|bee.socket.fd|string
---@param errno integer
local function dispatch(op, reg, status, data, errno)
    local watch = reg.watch
    if watch then
        local ok, traceback = xpcall(watch.onReadable, debug.traceback)
        if not ok then
            log.error(traceback)
        end
        local armed, armErr = arm(watch)
        if not armed then
            log.warn('重新注册外部事件源失败: {}' % { tostring(armErr) })
        end
        return
    end
    local resolve = reg.resolve
    if not resolve then
        log.warn('异步完成事件没有等待方: op = {}' % { op })
        return
    end
    reg.resolve = nil
    if status == async.SUCCESS then
        resolve(true, data)
    else
        resolve(false, '异步操作失败: op = {}, status = {}, errno = {}' % { op, status, errno })
    end
end

local wakeChannel = channel.create('moe-kill:event-loop')

---@type AsyncIO.Watch
local wakeWatch = {
    fd = wakeChannel:fd(),
    onReadable = function ()
        local ok = wakeChannel:pop()
        while ok do
            ok = wakeChannel:pop()
        end
    end,
}

local wakeArmed, wakeErr = arm(wakeWatch)
if not wakeArmed then
    error('无法注册自唤醒通道: ' .. tostring(wakeErr), 0)
end

-- 取出当前已完成的 I/O 事件并分发
function M.poll()
    for op, reg, status, data, errno in instance:poll() do
        dispatch(op, reg, status, data, errno)
    end
end

-- 阻塞等待：睡满 seconds（nil 表示无限期），或被完成事件 / 唤醒请求打断
---@param seconds number?
function M.wait(seconds)
    local ms = -1
    if seconds then
        ms = math.max(math.floor(seconds * 1000), 1)
    end
    for op, reg, status, data, errno in instance:wait(ms) do
        dispatch(op, reg, status, data, errno)
    end
end

-- 请求唤醒：投递一次通知，阻塞中的等待立即返回
function M.wake()
    wakeChannel:push(true)
end

-- 注册可读事件源：变为可读时调用 onReadable（调用方自行取走数据），完成后再自动注册
---@param fd any
---@param onReadable fun()
---@return AsyncIO.Watch
function M.watch(fd, onReadable)
    ---@type AsyncIO.Watch
    local watch = {
        fd = fd,
        onReadable = onReadable,
    }
    local ok, err = arm(watch)
    if not ok then
        error('注册外部事件源失败: ' .. tostring(err), 2)
    end
    return watch
end

-- 异步读取整个文件
---@async
---@param path string|bee.fspath
---@return string
function M.readFile(path)
    local sPath = toString(path)
    if not fs.exists(sPath) then
        error('文件不存在: ' .. sPath, 2)
    end
    local size = fs.file_size(sPath)
    local f, err = io.open(sPath, 'rb')
    if not f then
        error(err, 2)
    end
    if size == 0 then
        f:close()
        return ''
    end
    if not instance:associate_file(f) then
        f:close()
        error('无法把文件关联到异步 I/O 实例: ' .. sPath, 2)
    end
    ---@type AsyncIO.Register
    local reg = {}
    local settled = table.pack(moe.await.yield(function (resume)
        reg.resolve = resume
        if not instance:submit_file_read(f, size, 0, reg) then
            f:close()
            error('提交异步文件读失败: ' .. sPath, 0)
        end
    end))
    f:close()
    if not settled[1] then
        error(settled[2], 2)
    end
    return settled[2]
end

-- 异步写入整个文件
---@async
---@param path string|bee.fspath
---@param content string
---@return boolean
function M.writeFile(path, content)
    local sPath = toString(path)
    local f, err = io.open(sPath, 'wb')
    if not f then
        error(err, 2)
    end
    if content == '' then
        f:close()
        return true
    end
    if not instance:associate_file(f) then
        f:close()
        error('无法把文件关联到异步 I/O 实例: ' .. sPath, 2)
    end
    ---@type AsyncIO.Register
    local reg = {}
    local settled = table.pack(moe.await.yield(function (resume)
        reg.resolve = resume
        if not instance:submit_file_write(f, content, 0, reg) then
            f:close()
            error('提交异步文件写失败: ' .. sPath, 0)
        end
    end))
    f:close()
    if not settled[1] then
        error(settled[2], 2)
    end
    return true
end

return M
