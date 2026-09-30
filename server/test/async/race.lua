local lt = require 'test.ltest'

---@async
lt.test('await.race：先结束的那一路胜出', function ()
    local win, results = moe.await.race {
        function ()
            moe.await.sleep(0.05)
            return '慢'
        end,
        function ()
            return '快'
        end,
    }

    lt.assertEquals('第二路先结束', 2, win)
    lt.assertEquals('它正常返回', true, results[2][1])
    lt.assertEquals('结果就是它的返回值', '快', results[2][2])
    lt.assertEquals('先结束的那一路之外还没有结果', nil, results[1])
end)

---@async
lt.test('await.race：报错的那一路也算「结束」', function ()
    lt.expectErrors(1)

    local win, results = moe.await.race {
        function ()
            moe.await.sleep(0.05)
            return '慢'
        end,
        function ()
            error('故意报错')
        end,
    }

    lt.assertEquals('第二路先结束', 2, win)
    lt.assertEquals('它是失败的（原因进了错误日志）', false, results[2][1])
end)

---@async
lt.test('task.race：谁先结完谁赢，其余当场取消', function ()
    local slowDone = false
    local fastRan = false
    local winner = assert(moe.task.race {
        function ()
            moe.await.sleep(0.05)
            slowDone = true
            return '慢'
        end,
        function ()
            fastRan = true
            return '快'
        end,
    })

    lt.assertEquals('第二路跑过了', true, fastRan)
    lt.assertEquals('第二路赢', 2, winner.win)
    lt.assertEquals('赢家的结果', '快', winner.task.result)

    -- 输家当场就被取消了：把时钟推过它那个到点时刻，它也不会醒过来做事
    test.advance(0.05)
    moe.await.sleep(0)
    lt.assertEquals('输家被取消、它后面的代码没跑', false, slowDone)
end)

---@async
lt.test('task.race：报错的那一路先结束，也是它赢', function ()
    local winner = assert(moe.task.race {
        function ()
            error('故意报错')
        end,
        function ()
            moe.await.sleep(0)
            return '后来的'
        end,
    })

    lt.assertEquals('报错的那一路先结束，就是它赢', 1, winner.win)
    lt.assertEquals('没有结果', nil, winner.task.result)
    lt.assertEquals('失败原因带回来了', true, tostring(winner.task.err):find('故意报错') ~= nil)
end)

---@async
lt.test('task.any：第一个成功的那一路赢，其余当场取消', function ()
    local slowDone = false
    local fastRan = false
    local winner = assert(moe.task.any {
        function ()
            moe.await.sleep(0.05)
            slowDone = true
            return '慢'
        end,
        function ()
            fastRan = true
            return '快'
        end,
    })

    lt.assertEquals('第二路跑过了', true, fastRan)
    lt.assertEquals('第二路赢', 2, winner.win)
    lt.assertEquals('赢家的结果', '快', winner.task.result)

    test.advance(0.05)
    moe.await.sleep(0)
    lt.assertEquals('输家被取消、它后面的代码没跑', false, slowDone)
end)

---@async
lt.test('task.any：报错的不算赢，等别的那一路成功', function ()
    local winner = assert(moe.task.any {
        function ()
            error('故意报错')
        end,
        function ()
            moe.await.sleep(0)
            return '后来的'
        end,
    })

    lt.assertEquals('成功的那一路赢', 2, winner.win)
    lt.assertEquals('结果', '后来的', winner.task.result)
end)

---@async
lt.test('task.any：全都失败就没有赢家', function ()
    local winner = moe.task.any {
        function ()
            error('故意报错')
        end,
        function ()
            error('也报错')
        end,
    }

    lt.assertEquals('没有赢家', nil, winner)
end)
