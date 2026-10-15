local lt = require 'test.ltest'

---@async
lt.test('动画等待：倍率 0 时不等', function ()
    local game   = lt.game()
    local before = moe.timer.clock()
    local done   = false

    ---@async
    moe.await.call(function ()
        game:animSleep(1)
        done = true
    end)

    lt.assertEquals('当场就回来了', true, done)
    lt.assertEquals('时钟一点没动', before, moe.timer.clock())
end)

---@async
lt.test('动画等待：倍率 1 时按秒等', function ()
    local game = lt.game()
    local restore <close> = moe.util.defer(function () moe.animScale = 0 end)
    moe.animScale = 1

    local startClock = moe.timer.clock()
    local done       = false

    ---@async
    moe.await.call(function ()
        game:animSleep(1)
        done = true
    end)

    moe.await.sleep(0)
    lt.assertEquals('还没到点：还等着', false, done)

    test.advance(1)
    moe.await.sleep(0)
    lt.assertEquals('到点：回来了', true, done)
    lt.assertEquals('正好等了 1 秒', startClock + 1000, moe.timer.clock())
end)

---@async
lt.test('动画等待：按倍率缩放', function ()
    local game = lt.game()
    local restore <close> = moe.util.defer(function () moe.animScale = 0 end)
    moe.animScale = 0.5

    local done = false

    ---@async
    moe.await.call(function ()
        game:animSleep(1)
        done = true
    end)

    test.advance(0.5)
    moe.await.sleep(0)
    lt.assertEquals('半倍：0.5 秒就回来', true, done)
end)
