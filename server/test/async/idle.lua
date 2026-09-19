local lt = require 'test.ltest'

---@async
lt.test('空闲时不空转', function ()
    local before = test.loopTicks
    moe.await.sleep(0.2)
    local delta = test.loopTicks - before

    lt.assertEquals('空闲 200 毫秒内迭代次数远低于空转', true, delta < 50)
end)

---@async
lt.test('定时任务按时执行', function ()
    local firedAt
    local startAt = moe.timer.clock()

    moe.timer.wait(0.05, function ()
        firedAt = moe.timer.clock()
    end)

    moe.await.sleep(0.2)

    lt.assertEquals('任务已执行', true, firedAt ~= nil)
    if not firedAt then
        return
    end
    local elapsed = (firedAt - startAt) / 1000.0
    lt.assertEquals('延迟不小于 50 毫秒', true, elapsed >= 0.05)
    lt.assertEquals('延迟不超过 150 毫秒', true, elapsed < 0.15)
end)
