local lt      = require 'test.ltest'
local support = require 'test.user.support'

local newGame   = support.newGame
local dealCards = support.dealCards

---@async
lt.test('询问：一次「给出」两半一起问（牌 + 目标）', function ()
    local game, players = newGame()
    local me  = assert(players[1])
    local you = assert(players[2])

    local c1, c2 = dealCards(game, me)

    ---@type Proto.Request.Ask.Select?
    local sent = nil
    local _ <close> = moe.client.register('Ask.Select', function (_, params)
        ---@cast params Proto.Request.Ask.Select
        sent = params
        local card = assert(params.card)
        return { card = { card.ids[1] }, player = { you.id } }
    end)

    local ask = moe.askCardWithTarget.create {
        game       = game,
        to         = me,
        reason     = '测试',
        conditions = {
            card   = { card = { c1, c2 } },
            target = { player = you },
        },
    }
    ask:apply():await()

    local params = assert(sent, '没问过客户端')
    lt.assertEquals('牌那半 = 两张候选', 2, #assert(params.card).ids)
    lt.assertEquals('目标那半 = 他一个', 1, #assert(params.player).ids)
    lt.assertEquals('目标是他', you.id, assert(params.player).ids[1])
    lt.assertEquals('这次成了', true, ask.success)
    lt.assertEquals('拿到的是一张真牌', true, ask.card == c1 or ask.card == c2)
    lt.assertEquals('答复的目标是他', you, ask.target)
end)

---@async
lt.test('询问：目标不在候选里 ⇒ 内核拒收', function ()
    local game, players = newGame()
    local me  = assert(players[1])
    local you = assert(players[2])

    local c1 = dealCards(game, me)

    local _ <close> = moe.client.register('Ask.Select', function (_, params)
        ---@cast params Proto.Request.Ask.Select
        local card = assert(params.card)
        return { card = { card.ids[1] }, player = { you.id } }
    end)

    local ask = moe.askCardWithTarget.create {
        game       = game,
        to         = me,
        reason     = '乱答',
        conditions = {
            card   = { card = { c1 } },
            target = { player = me },
        },
    }
    ask:apply():await()

    lt.assertEquals('这次没成', false, ask.success)
end)
