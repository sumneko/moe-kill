local lt     = require 'test.ltest'

---@async
lt.test('延迟队列中的任务会被执行', function ()
    local delayed = false

    moe.eventLoop.addDelayQueue(function ()
        delayed = true
    end)

    local waited = 0
    while not delayed and waited < 1000 do
        moe.await.sleep(0.001)
        waited = waited + 1
    end

    lt.assertEquals('任务已执行', true, delayed)
end)

---@async
lt.test('定时器可重复触发', function ()
    local count = 0

    local timer = moe.timer.loop(0.001, function (_, tick)
        count = tick
    end)

    local waited = 0
    while count < 3 and waited < 2000 do
        moe.await.sleep(0.001)
        waited = waited + 1
    end

    timer:remove()
    lt.assertEquals('至少触发三次', true, count >= 3)
end)
