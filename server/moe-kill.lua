---@class MoeKill
---@field args Args
---@field env MoeKill.Env
---@field util Utility
---@field fsu fsu
---@field json table
---@field uri table
---@field gc table
---@field timer Timer
---@field await Await.API
---@field eventLoop EventLoop
---@field asyncIO AsyncIO
---@field sevent table
---@field tools MoeKill.Tools
---@field reload Reload
---@field card Card.API
---@field zone Zone.API
---@field orderedZone OrderedZone.API
---@field random Random.API
---@field attribute AttributeSystem.API
---@field event Event.API
---@field desk Desk.API
---@field player Player.API
---@field game Game.API
---@field effect Effect.API
---@field useCard UseCard.API
---@field damage Damage.API
---@field loader Loader
---@field server Server
---@field inspect fun(root: any): string
moe = {}

local class = require 'tools.class'

Class   = class.declare
New     = class.new
Delete  = class.delete
Type    = class.type
IsValid = class.isValid
Extends = class.extends
Presize = class.presize

local args = require 'args'

moe.args = args.current(arg)

moe.util = require 'tools.utility'
moe.util.enableCloseFunction()
moe.util.enableFormatString()
moe.util.enableDividStringAsPath()

local fs   = require 'bee.filesystem'
local time = require 'bee.time'

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
moe.env.LOG_FILE = moe.env.LOG_PATH / (moe.args.TEST and 'test.log' or 'service.log')

require 'tools.log'

local messageFormat = '[{}][{%5s}][{}] {}\n'

---@param path string # 日志文件
---@param errorStream file* # error / fatal 除写文件外再写到这个流
---@return Log
local function createLog(path, errorStream)
    return New 'Log' {
        clock = function ()
            return time.monotonic() / 1000.0
        end,
        time  = function ()
            return time.time() // 1000
        end,
        path  = path,
        level = tostring(moe.args.LOGLEVEL or 'info'):lower(),
        print = function (timeStamp, level, sourceStr, message)
            local fullMessage = messageFormat % { timeStamp, level, sourceStr, message }
            log:write(fullMessage)
            if level == 'error' or level == 'fatal' then
                errorStream:write(fullMessage)
            end
            return true
        end,
    }
end

---@diagnostic disable-next-line: lowercase-global
log = createLog(moe.env.LOG_FILE:string(), moe.args.TEST and io.stdout or io.stderr)

moe.fsu     = require 'tools.fs-utility'
moe.json    = require 'tools.json'
moe.uri     = require 'tools.uri'
moe.gc      = require 'tools.gc'
moe.timer   = require 'tools.timer'
moe.await   = require 'tools.await'
moe.eventLoop = require 'tools.event-loop'
moe.sevent  = require 'tools.simple-event'
moe.asyncIO = require 'async-io'

---@class MoeKill.Tools
moe.tools = {
    linkedTable   = require 'tools.linked-table',
    pathTable     = require 'tools.path-table',
    caselessTable = require 'tools.caseless-table',
    pqueue        = require 'tools.priority-queue',
    activePool    = require 'tools.active-pool',
}

moe.reload = require 'tools.reload'
---@diagnostic disable-next-line: lowercase-global
include    = moe.reload.include

require 'core'

moe.server = require 'session'

local inspect = require 'tools.inspect'

local inspectOptions = {
    process = function (item, path)
        if item == _G then
            return '<_G>'
        end
        if path[#path] == 'text' then
            return '***'
        end
        if type(item) == 'string' and #item > 1000 then
            return item:sub(1, 450) .. '...' .. item:sub(-450)
        end
        return item
    end,
}

function moe.inspect(root)
    return inspect.inspect(root, inspectOptions)
end

moe.await.setErrorHandler(function (traceback)
    log.error(traceback)
end)

moe.await.setSleepWaker(function (time, callback)
    if time <= 0 then
        moe.eventLoop.addDelayQueue(callback)
    else
        moe.timer.wait(time, callback)
    end
end)

moe.eventLoop.addHighTask(function ()
    moe.asyncIO.poll()
end)

moe.eventLoop.addHighTask(moe.timer.update)

---@return EventLoop.Options
function moe.eventLoopOptions()
    return {
        waiter   = function (seconds)
            moe.asyncIO.wait(seconds)
        end,
        deadline = moe.timer.getNextDeadline,
        waker    = moe.asyncIO.wake,
    }
end

return moe
