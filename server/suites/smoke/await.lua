local lt = require 'suites.ltest'

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

    local waited = 0
    while not resumed and waited < 1000 do
        moe.await.sleep(0.001)
        waited = waited + 1
    end

    lt.assertEquals('协程已恢复', true, resumed)
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

    local waited = 0
    while not finished and waited < 2000 do
        moe.await.sleep(0.001)
        waited = waited + 1
    end

    lt.assertEquals('休眠后继续执行', true, finished)
    lt.assertNotEquals('时间已推进', started, moe.timer.clock())
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

    local waited = 0
    while not captured and waited < 1000 do
        moe.await.sleep(0.001)
        waited = waited + 1
    end

    moe.await.setErrorHandler(function (traceback)
        log.error(traceback)
    end)

    lt.assertEquals('错误已捕获', true, captured ~= nil)
    lt.assertEquals('错误信息可见', true, (captured or ''):find('smoke%-await%-error') ~= nil)
end)
