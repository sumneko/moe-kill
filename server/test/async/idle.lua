local lt = require 'test.ltest'

---@async
lt.test('空闲时不空转', function ()
    local before = test.loopTicks
    -- 虚拟时钟不会自己走，这里等的是墙钟（事件循环没事做就该睡着，不该空转）
    moe.loopWaiter.wait(0.2)
    local delta = test.loopTicks - before

    lt.assertEquals('空闲 200 毫秒内迭代次数远低于空转', true, delta < 50)
end)

---@async
lt.test('定时任务：时间冻结着，推到点才触发', function ()
    local firedAt
    local startAt = moe.timer.clock()

    moe.timer.wait(0.05, function ()
        firedAt = moe.timer.clock()
    end)

    moe.await.sleep(0)
    lt.assertEquals('不推进时间：还没到点，不触发', nil, firedAt)

    test.advance(0.04)
    moe.await.sleep(0)
    lt.assertEquals('推到 40 毫秒：仍不到 50 毫秒，不触发', nil, firedAt)

    test.advance(0.02)
    moe.await.sleep(0)
    lt.assertEquals('推到 60 毫秒：触发了', true, firedAt ~= nil)
    lt.assertEquals('触发发生在到点那一刻（50 毫秒）', startAt + 50, firedAt)
end)
