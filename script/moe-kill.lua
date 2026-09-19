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
---@field core Core
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

moe.core = require 'core'

moe.server = require 'server'

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
