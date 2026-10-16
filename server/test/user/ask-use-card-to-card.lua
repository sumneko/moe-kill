local lt      = require 'test.ltest'
local support = require 'test.user.support'

---@async
lt.test('询问：要一次「对一张牌的使用」，走 Ask.Select，回包的 id 转回真牌', function ()
    local game, players = support.newPackageGame()
    local me = assert(players[1])

    local nullify = support.giveCard(game, me, '无懈可击', '黑桃', 11)

    ---@type Proto.Request.Ask.Select?
    local sent = nil
    local _ <close> = moe.client.register('Ask.Select', function (_, params)
        ---@cast params Proto.Request.Ask.Select
        sent = params
        local condition = assert(params.card)
        return { card = { condition.ids[1] } }
    end)

    local ask = moe.askUseCardToCard.create {
        game      = game,
        to        = me,
        reason    = '无懈可击',
        condition = { target = game:createCard('决斗', '黑桃', 1) },
    }
    ask:apply():await()

    local cardCond = assert(assert(sent, '没问过客户端').card)
    lt.assertEquals('候选只有那张【无懈可击】', 1, #cardCond.ids)
    lt.assertEquals('张数区间就是一张', '1,1', cardCond.min .. ',' .. cardCond.max)
    lt.assertEquals('这次成了', true, ask.success)
    lt.assertEquals('拿到的是一张真牌', nullify, ask.card)
end)

---@async
lt.test('询问：回包里的牌 id 不认 ⇒ 这次不算成立', function ()
    local game, players = support.newPackageGame()
    local me = assert(players[1])

    support.giveCard(game, me, '无懈可击', '黑桃', 11)

    local _ <close> = moe.client.register('Ask.Select', function ()
        return { card = { 9999 } }
    end)

    local ask = moe.askUseCardToCard.create {
        game      = game,
        to        = me,
        reason    = '无懈可击',
        condition = { target = game:createCard('决斗', '黑桃', 1) },
    }
    ask:apply():await()

    lt.assertEquals('这次没成', false, ask.success)
    lt.assertEquals('没有牌', nil, ask.card)
end)

---@async
lt.test('询问：带 responseTo 的询问把「冲哪次使用去的」交给了客户端', function ()
    local game, players = support.newPackageGame()
    local me    = assert(players[1])
    local other = assert(players[2])

    support.giveCard(game, me, '无懈可击', '黑桃', 11)

    local target  = game:createCard('决斗', '黑桃', 1)
    local useCard = moe.useCard.create {
        game    = game,
        user    = other,
        card    = target,
        targets = { me },
    }

    ---@type Proto.Request.Ask.Select?
    local sent = nil
    local _ <close> = moe.client.register('Ask.Select', function (_, params)
        ---@cast params Proto.Request.Ask.Select
        sent = params
        return {}
    end)

    local ask = moe.askUseCardToCard.create {
        game            = game,
        to              = me,
        reason          = '决斗',
        condition       = { target = target },
        responseOptions = { responseTo = useCard },
    }
    ask:apply():await()

    local responseTo = assert(assert(sent, '没问过客户端').responseTo, '没带来处')
    lt.assertEquals('响应的是那张【决斗】', '决斗', responseTo.card)
    lt.assertEquals('使用者是二号位', other.id, responseTo.player)
    lt.assertEquals('目标是当前玩家', me.id, responseTo.targets[1])
end)
