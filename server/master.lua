local fs     = require 'bee.filesystem'
local time   = require 'bee.time'
local thread = require 'bee.thread'

moe.threadName = 'master'
thread.setname 'master'

local entryPath = fs.absolute(fs.path(arg[0]))
local rootPath  = entryPath:parent_path()
if moe.args.ROOT then
    rootPath = fs.absolute(fs.path(moe.args.ROOT))
end

---@class MoeKill.Env
---@field ROOT_PATH bee.fspath
---@field LOG_PATH bee.fspath
---@field LOG_FILE bee.fspath
moe.env = {
    ROOT_PATH = rootPath,
    LOG_PATH  = rootPath / (moe.args.LOGPATH or 'log'),
}

fs.create_directories(moe.env.LOG_PATH)
moe.env.LOG_FILE = moe.env.LOG_PATH / 'service.log'

require 'tools.log'

local messageFormat = '[{}][{%5s}][{}] {}\n'

---@diagnostic disable-next-line: lowercase-global
log = New 'Log' {
    clock = function ()
        return time.monotonic() / 1000.0
    end,
    time  = function ()
        return time.time() // 1000
    end,
    path  = moe.env.LOG_FILE:string(),
    level = tostring(moe.args.LOGLEVEL or 'info'):lower(),
    print = function (timeStamp, level, sourceStr, message)
        local fullMessage = messageFormat % { timeStamp, level, sourceStr, message }
        log:write(fullMessage)
        if level == 'error' or level == 'fatal' then
            io.stderr:write(fullMessage)
        end
        return true
    end,
}

log.info('moe-kill startup')
log.info('THREAD:', moe.threadName)
log.info('ROOT_PATH:', moe.env.ROOT_PATH:string())
log.info('LOG_FILE:', moe.env.LOG_FILE:string())
log.info('RUNTIME:', _VERSION)
log.info('LOGLEVEL:', log.level)

moe.timer.loop(60, function ()
    log.info('MEMORY: {%.1f} MB' % { collectgarbage('count') / 1024 })
end)
