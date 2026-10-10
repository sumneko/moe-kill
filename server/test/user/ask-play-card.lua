local lt      = require 'test.ltest'
local support = require 'test.user.support'

local newGame   = support.newGame
local dealCards = support.dealCards

---@async
lt.test('询问：要一张打出的牌，回包的 id 转回真牌', function ()
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

    local ask = moe.askPlayCard.create {
        game      = game,
        to        = me,
        reason    = '杀',
        condition = { zone = '手牌' },
    }
    ask:apply():await()

    local params  = assert(sent, '没问过客户端')
    local cardCond = assert(params.card)
    lt.assertEquals('两张手牌都是候选', 2, #cardCond.ids)
    lt.assertEquals('张数区间就是一张', '1,1', cardCond.min .. ',' .. cardCond.max)
    lt.assertEquals('这次成了', true, ask.success)
    lt.assertEquals('拿到的是一张真牌', true, ask.card == c1 or ask.card == c2)
end)

---@async
lt.test('询问：回包里的牌 id 不认 ⇒ 这次不算成立', function ()
    local game, players = newGame()
    local me = assert(players[1])

    dealCards(game, me)

    local _ <close> = moe.client.register('Ask.Select', function ()
        return { card = { 9999 } }
    end)

    local ask = moe.askPlayCard.create {
        game      = game,
        to        = me,
        reason    = '杀',
        condition = { zone = '手牌' },
    }
    ask:apply():await()

    lt.assertEquals('这次没成', false, ask.success)
    lt.assertEquals('没有牌', nil, ask.card)
end)
