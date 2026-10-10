local lt      = require 'test.ltest'
local support = require 'test.user.support'

local newGame   = support.newGame
local dealCards = support.dealCards

---@async
lt.test('询问：要牌时问客户端，回包的 id 转回牌', function ()
    local game, players = newGame()
    local me = assert(players[1])

    local c1, c2 = dealCards(game, me)

    ---@type Proto.Request.Ask.Select?
    local sent = nil
    local _ <close> = moe.client.register('Ask.Select', function (_, params)
        ---@cast params Proto.Request.Ask.Select
        sent = params
        local condition = assert(params.card)
        return { card = { condition.ids[1] } }
    end)

    local ask = moe.askCard.create {
        game      = game,
        to        = me,
        reason    = '测试',
        condition = { card = { c1, c2 } },
    }
    ask:apply():await()

    local params = assert(sent, '没问过客户端')
    lt.assertEquals('两张都是候选', 2, #assert(params.card).ids)
    lt.assertEquals('张数区间带上了', 1, assert(params.card).min)
    lt.assertEquals('这次成了', true, ask.success)
    lt.assertEquals('拿到的是一张真牌', true, ask.card == c1 or ask.card == c2)
end)

---@async
lt.test('询问：回包里的牌 id 不认 ⇒ 这次不算成立', function ()
    local game, players = newGame()
    local me = assert(players[1])

    local c1 = dealCards(game, me)

    local _ <close> = moe.client.register('Ask.Select', function ()
        return { card = { 9999 } }
    end)

    local ask = moe.askCard.create {
        game      = game,
        to        = me,
        reason    = '乱答',
        condition = { card = { c1 } },
    }
    ask:apply():await()

    lt.assertEquals('这次没成', false, ask.success)
    lt.assertEquals('没有牌', nil, ask.card)
end)

---@async
lt.test('询问：没给条件时不筛（候选 = 他牌区里的牌）', function ()
    local game, players = newGame()
    local me = assert(players[1])

    local c1, c2 = dealCards(game, me)

    ---@type Proto.Request.Ask.Select?
    local sent = nil
    local _ <close> = moe.client.register('Ask.Select', function (_, params)
        ---@cast params Proto.Request.Ask.Select
        sent = params
        local condition = assert(params.card)
        return { card = { condition.ids[1] } }
    end)

    local ask = moe.askCard.create {
        game   = game,
        to     = me,
        reason = '随便',
    }
    ask:apply():await()

    local params = assert(sent, '没问过客户端')
    lt.assertEquals('候选就是他手上那两张', 2, #assert(params.card).ids)
    lt.assertEquals('这次成了', true, ask.success)
    lt.assertEquals('拿到的是一张真牌', true, ask.card == c1 or ask.card == c2)
end)
