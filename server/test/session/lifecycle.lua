local lt = require 'test.ltest'

---@class Test.Server.IdleHandler : Server.Handler
local IdleHandler = Class 'Test.Server.IdleHandler'

---@async
function IdleHandler:run(session)
    session:finish()
end

lt.test('服务器可重复启停并交回控制权', function ()
    lt.assertEquals('初始未启动', false, moe.server.isStarted())
    lt.assertEquals('首次启动生效', true, moe.server.start())
    lt.assertEquals('启动后处于已启动', true, moe.server.isStarted())
    lt.assertEquals('重复启动无副作用', false, moe.server.start())

    local released = false
    moe.server.stop()
    released = true

    lt.assertEquals('停止后即返回调用方', true, released)
    lt.assertEquals('停止后处于未启动', false, moe.server.isStarted())
    lt.assertEquals('重复停止无副作用', false, moe.server.stop())
end)

lt.test('会话可走完生命周期', function ()
    local session = moe.server.createSession(New 'Test.Server.IdleHandler' ())
    lt.assertEquals('登记为当前会话', session, moe.server.getSession())
    lt.assertEquals('创建后未开始', moe.server.Phase.PENDING, session:getPhase())

    session:start()
    lt.assertEquals('入口返回即结束', moe.server.Phase.FINISHED, session:getPhase())

    lt.assertEquals('销毁成功', true, moe.server.destroySession(session))
    lt.assertEquals('销毁后阶段', moe.server.Phase.DESTROYED, session:getPhase())
    lt.assertEquals('重复销毁安全', false, moe.server.destroySession(session))
    lt.assertEquals('登记已清空', false, moe.server.hasSession())
end)

lt.test('非法阶段迁移被拒绝', function ()
    local session = moe.server.createSession(New 'Test.Server.IdleHandler' ())

    lt.assertError('未开始时提交输入', function ()
        session:submit('输入')
    end)
    lt.assertError('未开始时结束', function ()
        session:finish()
    end)
    lt.assertEquals('阶段未变', moe.server.Phase.PENDING, session:getPhase())

    session:start()
    lt.assertError('重复启动', function ()
        session:start()
    end)
    lt.assertError('重复结束', function ()
        session:finish()
    end)

    moe.server.destroySession(session)
    lt.assertError('已销毁会话无法启动', function ()
        session:start()
    end)
    lt.assertError('已销毁会话无法提交', function ()
        session:submit('输入')
    end)
    lt.assertError('已销毁会话无法发出事件', function ()
        session:emit('事件')
    end)
    lt.assertEquals('阶段仍为已销毁', moe.server.Phase.DESTROYED, session:getPhase())
end)

lt.test('中止记录原因并冻结阶段', function ()
    local session = moe.server.createSession(New 'Test.Server.IdleHandler' ())
    session:abort('测试中止')

    lt.assertEquals('阶段为已中止', moe.server.Phase.ABORTED, session:getPhase())
    lt.assertEquals('原因可查询', '测试中止', session:getAbortReason())
    lt.assertError('已中止会话无法启动', function ()
        session:start()
    end)
    moe.server.destroySession(session)
end)

lt.test('未挂载处理器无法创建会话', function ()
    ---@type any
    local missing
    lt.assertError('缺少处理器', function ()
        moe.server.createSession(missing)
    end)

    ---@type any
    local incomplete = {}
    lt.assertError('处理器缺少入口', function ()
        moe.server.createSession(incomplete)
    end)

    lt.assertEquals('未登记任何会话', false, moe.server.hasSession())
end)

lt.test('同时只能有一个会话', function ()
    local session = moe.server.createSession(New 'Test.Server.IdleHandler' ())
    lt.assertError('重复创建会话', function ()
        moe.server.createSession(New 'Test.Server.IdleHandler' ())
    end)
    lt.assertEquals('原会话未被覆盖', session, moe.server.getSession())

    moe.server.destroySession(session)
    local second = moe.server.createSession(New 'Test.Server.IdleHandler' ())
    lt.assertNotEquals('销毁后可再建会话', session, second)
    moe.server.destroySession(second)
end)
