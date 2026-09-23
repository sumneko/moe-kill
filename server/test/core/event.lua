local lt = require 'test.ltest'

lt.test('事件：按名分发', function ()
    local event = moe.event.create()
    ---@type string[]
    local log = {}
    event:on('甲', function () log[#log+1] = '甲的1' end)
    event:on('乙', function () log[#log+1] = '乙的1' end)

    event:fire('甲')
    lt.assertEquals('只触发同名的回调', '甲的1', table.concat(log, ','))

    event:fire('乙')
    lt.assertEquals('不同时机名互不干扰', '甲的1,乙的1', table.concat(log, ','))
end)

lt.test('事件：注册顺序即执行顺序', function ()
    local event = moe.event.create()
    ---@type integer[]
    local log = {}
    for i = 1, 3 do
        event:on('甲', function () log[#log+1] = i end)
    end

    event:fire('甲')

    lt.assertEquals('按注册顺序执行', '1,2,3', table.concat(log, ','))
end)

lt.test('事件：撤销一次注册', function ()
    local event = moe.event.create()
    ---@type integer[]
    local log = {}
    local undo = event:on('甲', function () log[#log+1] = 1 end)
    event:on('甲', function () log[#log+1] = 2 end)

    event:fire('甲')
    lt.assertEquals('两个都执行了', '1,2', table.concat(log, ','))

    undo()
    undo()
    log = {}
    event:fire('甲')
    lt.assertEquals('撤销只影响那一次注册，重复撤销安全', '2', table.concat(log, ','))
end)

lt.test('事件：未注册的时机名是空操作', function ()
    local event = moe.event.create()

    lt.assertEquals('一开始没有注册过', false, event:has('甲'))
    event:fire('甲')
    lt.assertEquals('触发后仍然没有注册过', false, event:has('甲'))
end)

lt.test('事件：回调报错不影响其余回调', function ()
    lt.expectErrors(1)
    local event = moe.event.create()
    ---@type integer[]
    local log = {}
    event:on('甲', function () log[#log+1] = 1 end)
    event:on('甲', function () error('事件回调故意报错') end)
    event:on('甲', function () log[#log+1] = 3 end)

    event:fire('甲')

    lt.assertEquals('报错的那个被跳过，其余照常执行', '1,3', table.concat(log, ','))
end)

lt.test('事件：上下文透传', function ()
    local event = moe.event.create()
    local received
    event:on('甲', function (payload) received = payload end)

    ---@type table<string, any>
    local payload = { count = 4 }
    event:fire('甲', payload)

    lt.assertEquals('回调收到触发时传的上下文', payload, received)
end)

lt.test('事件：clear 清空全部注册', function ()
    local event = moe.event.create()
    local count = 0
    event:on('甲', function () count = count + 1 end)
    event:on('乙', function () count = count + 1 end)

    event:clear()
    event:fire('甲')
    event:fire('乙')

    lt.assertEquals('清空后不再触发', 0, count)
    lt.assertEquals('清空后没有已注册的时机名', 0, #event:getNames())
end)

lt.test('事件：可以列出已注册的时机名', function ()
    local event = moe.event.create()
    event:on('b', function () end)
    event:on('a', function () end)

    lt.assertEquals('按名字排序返回', 'a,b', table.concat(event:getNames(), ','))
    lt.assertEquals('注册过的名字在列', true, event:has('a'))
    lt.assertEquals('没注册的名字不在列', false, event:has('c'))
end)
