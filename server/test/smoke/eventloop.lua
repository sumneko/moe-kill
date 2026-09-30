local lt     = require 'test.ltest'

---@async
lt.test('延迟队列中的任务会被执行', function ()
    local delayed = false

    moe.eventLoop.addDelayQueue(function ()
        delayed = true
    end)

    moe.await.sleep(0)
    lt.assertEquals('任务已执行', true, delayed)
end)

---@async
lt.test('定时器可重复触发', function ()
    local count = 0

    local timer = moe.timer.loop(0.001, function (_, tick)
        count = tick
    end)

    test.advance(0.001)
    moe.await.sleep(0)
    lt.assertEquals('推进一个周期：触发一次', 1, count)

    test.advance(0.002)
    moe.await.sleep(0)
    lt.assertEquals('再推进两个周期：累计三次', 3, count)

    timer:remove()
end)
