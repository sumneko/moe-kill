local lt = require 'suites.ltest'

---@class Test.Server.FlowHandler : Server.Handler
---@field decision? string
local FlowHandler = Class 'Test.Server.FlowHandler'

---@async
function FlowHandler:run(session)
    session:emit('game/start', { round = 1 })
    self.decision = session:requestInput('game/choose', { options = { 'a', 'b' } })
    session:emit('game/turnEnd', { round = 1 })
    session:finish()
end

lt.test('无外部客户端可跑通全流程', function ()
    lt.assertEquals('启动服务器', true, moe.server.start())

    local handler = New 'Test.Server.FlowHandler' ()
    local session = moe.server.createSession(handler)
    lt.assertEquals('会话已登记', session, moe.server.getSession())
    session:start()

    local pending = session:getPendingRequest()
    lt.assertEquals('等待外部输入', 'game/choose', pending?.kind)

    session:submit('a')
    lt.assertEquals('决策交回逻辑侧', 'a', handler.decision)
    lt.assertEquals('会话正常结束', moe.server.Phase.FINISHED, session:getPhase())

    local events = session:getEvents()
    lt.assertEquals('事件数', 2, #events)
    lt.assertEquals('首个事件', 'game/start', events[1].kind)
    lt.assertEquals('末个事件', 'game/turnEnd', events[2].kind)

    lt.assertEquals('销毁会话', true, moe.server.destroySession(session))
    lt.assertEquals('登记已清空', nil, moe.server.getSession())
    lt.assertEquals('停止服务器', true, moe.server.stop())
    lt.assertEquals('重复停止安全', false, moe.server.stop())
end)
