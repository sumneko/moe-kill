collectgarbage('generational')
collectgarbage('param', 'minormul', 20)
collectgarbage('param', 'minormajor', 100)
collectgarbage('param', 'majorminor', 20)

require 'moe-kill'
require 'master'

xpcall(function ()
    if not moe.args.DEVELOP then
        return
    end
    local dbg = require 'debugger'
    dbg:start(moe.args.DBGADDRESS .. ':' .. moe.args.DBGPORT)
    if moe.args.DBGWAIT then
        dbg:event 'wait'
    end
end, log.warn)

if moe.args.TEST then
    local testEntry = (moe.env.ROOT_PATH / 'test.lua'):string()
    dofile(testEntry)
    return
end

print = log.debug

moe.server.start()

log.info('enter service mode')
moe.eventLoop.start(moe.eventLoopOptions(), log.error)
