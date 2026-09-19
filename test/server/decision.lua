local lt = require 'test.ltest'

---@class Test.Server.AnswerHandler : Server.Handler
---@field first? any
---@field second? any
---@field third? any
local AnswerHandler = Class 'Test.Server.AnswerHandler'

---@async
function AnswerHandler:run(session)
    self.first, self.second, self.third = session:requestInput('ask', { count = 2 })
    session:finish()
end

---@class Test.Server.SleepyHandler : Server.Handler
---@field value? any
local SleepyHandler = Class 'Test.Server.SleepyHandler'

---@async
function SleepyHandler:run(session)
    self.value = session:requestInput('ask')
    moe.await.sleep(0.02)
    session:finish()
end

---@class Test.Server.CatchHandler : Server.Handler
---@field timeout? number
---@field error? string
local CatchHandler = Class 'Test.Server.CatchHandler'

---@param timeout? number
function CatchHandler:__init(timeout)
    self.timeout = timeout
end

---@async
function CatchHandler:run(session)
    ---@async
    local function ask()
        session:requestInput('wait', nil, self.timeout)
    end
    local ok, err = xpcall(ask, tostring)
    self.error = ok and nil or err
    if session:getPhase() == moe.server.Phase.RUNNING then
        session:finish()
    end
end

lt.test('单值决策往返', function ()
    local handler = New 'Test.Server.AnswerHandler' ()
    local session = moe.server.createSession(handler)
    session:start()

    local pending = session:getPendingRequest()
    lt.assertEquals('待处理类型可见', 'ask', pending?.kind)
    lt.assertEquals('负载表可见', 2, pending?.payload?.count)

    session:submit('答案')
    lt.assertEquals('第一值交回', '答案', handler.first)
    lt.assertEquals('第二值缺省', nil, handler.second)
    lt.assertEquals('无遗留待处理事项', nil, session:getPendingRequest())
    lt.assertEquals('会话已结束', moe.server.Phase.FINISHED, session:getPhase())
    moe.server.destroySession(session)
end)

lt.test('多值决策往返', function ()
    local handler = New 'Test.Server.AnswerHandler' ()
    local session = moe.server.createSession(handler)
    session:start()
    session:submit('一', 2, true)

    lt.assertEquals('第一值', '一', handler.first)
    lt.assertEquals('第二值', 2, handler.second)
    lt.assertEquals('第三值', true, handler.third)
    moe.server.destroySession(session)
end)

---@async
lt.test('无等待请求时提交报错', function ()
    local handler = New 'Test.Server.SleepyHandler' ()
    local session = moe.server.createSession(handler)
    session:start()
    session:submit('值')

    lt.assertEquals('提交值已交回', '值', handler.value)
    lt.assertEquals('仍在运行', moe.server.Phase.RUNNING, session:getPhase())
    lt.assertError('无等待请求时提交', function ()
        session:submit('多余')
    end)

    moe.await.sleep(0.05)
    lt.assertEquals('休眠后自行结束', moe.server.Phase.FINISHED, session:getPhase())
    moe.server.destroySession(session)
end)

---@async
---@async
lt.test('决策超时唤醒挂起方', function ()
    local handler = New 'Test.Server.CatchHandler' (0.01)
    local session = moe.server.createSession(handler)
    session:start()

    lt.assertEquals('处于等待输入', true, session:getPendingRequest() ~= nil)
    moe.await.sleep(0.05)
    lt.assertEquals('收到超时错误', '决策等待超时', handler.error)
    lt.assertEquals('不再处于等待输入', nil, session:getPendingRequest())
    lt.assertEquals('会话已结束', moe.server.Phase.FINISHED, session:getPhase())
    moe.server.destroySession(session)
end)

lt.test('主动取消唤醒挂起方', function ()
    local handler = New 'Test.Server.CatchHandler' ()
    local session = moe.server.createSession(handler)
    session:start()
    session:cancelRequest()

    lt.assertEquals('收到取消错误', '决策请求已取消', handler.error)
    lt.assertEquals('不再处于等待输入', nil, session:getPendingRequest())
    moe.server.destroySession(session)
end)

---@async
lt.test('无等待请求时取消报错', function ()
    local session = moe.server.createSession(New 'Test.Server.SleepyHandler' ())
    session:start()
    session:submit('值')

    lt.assertError('无等待请求时取消', function ()
        session:cancelRequest()
    end)

    moe.await.sleep(0.05)
    moe.server.destroySession(session)
end)

lt.test('中止唤醒挂起方', function ()
    local handler = New 'Test.Server.CatchHandler' ()
    local session = moe.server.createSession(handler)
    session:start()
    session:abort('测试中止')

    lt.assertEquals('阶段为已中止', moe.server.Phase.ABORTED, session:getPhase())
    lt.assertEquals('原因交回挂起方', '测试中止', handler.error)
    lt.assertEquals('不再处于等待输入', nil, session:getPendingRequest())
    moe.server.destroySession(session)
end)
