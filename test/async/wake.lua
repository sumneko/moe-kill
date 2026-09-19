local lt      = require 'test.ltest'
local btime   = require 'bee.time'
local channel = require 'bee.channel'

lt.test('唤醒请求让等待立即返回', function ()
    moe.asyncIO.wake()

    local start = btime.monotonic()
    moe.asyncIO.wait(0.5)
    local elapsed = (btime.monotonic() - start) / 1000.0

    lt.assertEquals('远早于超时返回', true, elapsed < 0.2)
end)

lt.test('外部事件源可读时被唤醒', function ()
    local box = channel.create('moe-kill:test-async-io')
    local received = {}

    moe.asyncIO.watch(box:fd(), function ()
        local ok, value = box:pop()
        if ok then
            received[#received + 1] = value
        end
    end)

    box:push('hello')
    moe.asyncIO.wait(0.5)

    lt.assertEquals('收到数据', 1, #received)
    lt.assertEquals('数据内容', 'hello', received[1])
end)

lt.test('没有数据时不产生虚假唤醒', function ()
    local box = channel.create('moe-kill:test-async-idle')
    local notified = 0

    moe.asyncIO.watch(box:fd(), function ()
        notified = notified + 1
    end)

    local start = btime.monotonic()
    moe.asyncIO.wait(0.05)
    local elapsed = (btime.monotonic() - start) / 1000.0

    lt.assertEquals('没有可读通知', 0, notified)
    lt.assertEquals('等待了完整时长', true, elapsed >= 0.04)
end)
