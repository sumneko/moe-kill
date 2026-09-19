local lt = require 'test.ltest'

---@class Test.Server.EventHandler : Server.Handler
---@field decision? string
local EventHandler = Class 'Test.Server.EventHandler'

---@async
function EventHandler:run(session)
    session:emit('round/begin', { round = 1 })
    session:emit('round/ready', { round = 1 })
    self.decision = session:requestInput('choose', { options = { '打', '过' } })
    session:emit('round/end', { round = 1, decision = self.decision })
    session:finish()
end

lt.test('未产生事件时读取到空集合', function ()
    local session = moe.server.createSession(New 'Test.Server.EventHandler' ())
    lt.assertEquals('事件数为零', 0, #session:getEvents())
    moe.server.destroySession(session)
end)

lt.test('事件按发出顺序记录', function ()
    local handler = New 'Test.Server.EventHandler' ()
    local session = moe.server.createSession(handler)
    session:start()

    local before = session:getEvents()
    lt.assertEquals('请求前的事件数', 2, #before)
    lt.assertEquals('第一个事件', 'round/begin', before[1].kind)
    lt.assertEquals('第二个事件', 'round/ready', before[2].kind)
    lt.assertEquals('负载可读', 1, before[1].payload?.round)

    session:submit('打')

    lt.assertEquals('快照不随后续事件变化', 2, #before)
    local after = session:getEvents()
    lt.assertEquals('新读取含全部事件', 3, #after)
    lt.assertEquals('第三个事件', 'round/end', after[3].kind)
    lt.assertEquals('负载区分先后', '打', after[3].payload?.decision)
    moe.server.destroySession(session)
end)
