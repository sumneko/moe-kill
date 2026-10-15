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
    require 'test'
    return
end

--- 把协议类型产物写给前端（改完声明跑一次）
if moe.args.GEN_PROTO then
    log.info('协议类型写好了：{}' % { moe.protoType.write() })
    return
end

print = log.debug

--- 取一个数字参数（没给就用默认）
---@param value Args.Value?
---@param default integer
---@return integer
local function numberOf(value, default)
    if type(value) == 'number' then
        return value
    end
    if type(value) == 'string' then
        return tonumber(value) or default
    end
    return default
end

--- 取一个「逗号分开的清单」（没给就用默认）
---@param value Args.Value?
---@param default string[]
---@return string[]
local function listOf(value, default)
    if type(value) ~= 'string' then
        return default
    end
    ---@type string[]
    local list = {}
    for one in value:gmatch('[^,]+') do
        list[#list + 1] = one
    end
    return list
end

if not moe.args.SINGLE then
    log.error('现在只支持单局模式（加 --single 起）；lobby 还没做')
    return
end

moe.server.start {
    port     = numberOf(moe.args.PORT, 31415),
    seats    = numberOf(moe.args.SEATS, 8),
    packages = listOf(moe.args.PACKAGES, { '身份场', '标准' }),
}

-- 时钟由这里驱动：timer 不认识真实时间，每轮循环把「当前真实毫秒」告诉它
local beeTime = require 'bee.time'
local startMS = beeTime.monotonic()
moe.eventLoop.addHighTask(function ()
    moe.timer.update(beeTime.monotonic() - startMS)
end)

log.info('enter service mode')
moe.eventLoop.start(moe.eventLoopOptions(), log.error)
