local lt      = require 'test.ltest'
local support = require 'test.user.support'

local newGame = support.newGame

---@async
lt.test('询问：选项问客户端，回包的索引换回字符串', function ()
    local game, players = newGame()
    local me = assert(players[1])

    ---@type Proto.Request.Ask.Choice?
    local sent = nil
    local _ <close> = moe.client.register('Ask.Choice', function (_, params)
        ---@cast params Proto.Request.Ask.Choice
        sent = params
        return { choice = 2 }
    end)

    local ask = moe.askChoice.create {
        game    = game,
        to      = me,
        reason  = '八卦阵',
        options = { '发动', '不发动' },
    }
    ask:apply():await()

    local params = assert(sent, '没问过客户端')
    lt.assertEquals('缘由原样带过去', '八卦阵', params.reason)
    lt.assertEquals('选项原样带过去', 2, #params.options)
    lt.assertEquals('总是允许主动取消', true, params.cancelable)
    lt.assertEquals('这次成了', true, ask.success)
    lt.assertEquals('换回来的是那个字符串', '不发动', ask.choice)
end)

---@async
lt.test('询问：索引越界 ⇒ 当没答（这次不成立）', function ()
    local game, players = newGame()
    local me = assert(players[1])

    local _ <close> = moe.client.register('Ask.Choice', function ()
        return { choice = 99 }
    end)

    local ask = moe.askChoice.create {
        game    = game,
        to      = me,
        reason  = '八卦阵',
        options = { '发动' },
    }
    ask:apply():await()

    lt.assertEquals('这次没成', false, ask.success)
    lt.assertEquals('没有选项', nil, ask.choice)
end)
