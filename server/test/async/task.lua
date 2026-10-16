local lt = require 'test.ltest'

lt.test('任务：没有执行体的任务定下结果就当场收口', function ()
    local task = moe.task.create()
    task:resolve(42)

    lt.assertEquals('收掉了', false, IsValid(task))
    lt.assertEquals('结果留在它身上', 42, task.result)
end)

lt.test('任务：没有执行体的任务失败也当场收口（回调当场跑过）', function ()
    local task = moe.task.create()
    ---@type any
    local gotErr = nil
    task:onRejected(function (err)
        gotErr = err
    end)
    task:reject('不干了')

    lt.assertEquals('收掉了', false, IsValid(task))
    lt.assertEquals('失败的回调当场跑过', '不干了', gotErr)
end)

---@async
lt.test('任务：没有执行体的任务被定了结果 ⇒ 挂在它上面那一路立刻收尾', function ()
    local task    = moe.task.create()
    local pending = moe.task.create { task = task }
    pending:executeSync(function ()
        return task:await()
    end)

    lt.assertEquals('这会儿还挂着', false, pending.resolved)

    task:reject('不干了')
    moe.await.sleep(0)

    lt.assertEquals('被叫醒了', true, pending.resolved)
    lt.assertEquals('拿到的结果是空', nil, pending.result)
end)

---@async
lt.test('任务：有执行体的任务被外面定了结果 ⇒ 不提前收掉，让执行体跑完', function ()
    local task  = moe.task.create()
    local steps = {}
    task:executeSync(function ()
        steps[#steps + 1] = '起'
        moe.await.sleep(0)
        steps[#steps + 1] = '醒'
    end)
    lt.assertEquals('执行体已经开跑', '起', steps[#steps])

    task:reject('外面定了')

    lt.assertEquals('不提前收掉', true, IsValid(task))

    moe.await.sleep(0)
    lt.assertEquals('执行体照样跑完', '醒', steps[#steps])
    lt.assertEquals('跑完才收尾', false, IsValid(task))
end)
