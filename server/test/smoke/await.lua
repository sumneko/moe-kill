local lt = require 'test.ltest'

---@async
lt.test('协程可挂起并由定时器恢复', function ()
    local first, second
    local resumed = false

    ---@async
    moe.await.call(function ()
        first, second = moe.await.yield(function (resume)
            moe.timer.wait(0, function ()
                resume('value', 42)
            end)
        end)
        resumed = true
    end)

    moe.await.sleep(0)
    lt.assertEquals('时钟不动：定时器不到点，没恢复', false, resumed)

    test.advance(0.001)
    moe.await.sleep(0)
    lt.assertEquals('推到点：恢复了', true, resumed)
    lt.assertEquals('第一个返回值', 'value', first)
    lt.assertEquals('第二个返回值', 42, second)
end)

---@async
lt.test('协程可按时长休眠', function ()
    local finished = false
    local started  = moe.timer.clock()

    ---@async
    moe.await.call(function ()
        moe.await.sleep(0.01)
        finished = true
    end)

    moe.await.sleep(0)
    lt.assertEquals('时钟不动：还睡着', false, finished)

    test.advance(0.01)
    moe.await.sleep(0)
    lt.assertEquals('推到点：醒过来了', true, finished)
    lt.assertNotEquals('时钟前进了', started, moe.timer.clock())
end)

---@async
lt.test('协程内未捕获错误进入统一错误处理器', function ()
    local captured

    local function handler(traceback)
        captured = traceback
    end

    moe.await.setErrorHandler(handler)

    moe.await.call(function ()
        error('smoke-await-error')
    end)

    moe.await.sleep(0)

    moe.await.setErrorHandler(function (traceback)
        log.error(traceback)
    end)

    lt.assertEquals('错误已捕获', true, captured ~= nil)
    lt.assertEquals('错误信息可见', true, (captured or ''):find('smoke%-await%-error') ~= nil)
end)
