local lt      = require 'test.ltest'
local support = require 'test.user.support'

---@async
lt.test('端到端：视为要确认 ⇒ 先问 Ask.Choice，答发动就不再要牌', function ()
    local game, players = support.newGame()
    local me = assert(players[1])

    local source = game:createCard('杀')
    game:moveCard(source, me:getZone('判定'))
    me:addViewAs('闪', source, { confirm = true })

    ---@type string[]
    local asked = {}
    local _ <close> = moe.client.register('Ask.Choice', function (_, params)
        ---@cast params Proto.Request.Ask.Choice
        asked[#asked + 1] = '确认:' .. params.reason
        return { choice = 1 }
    end)
    local _ <close> = moe.client.register('Ask.Select', function (_, params)
        ---@cast params Proto.Request.Ask.Select
        asked[#asked + 1] = '选牌'
        return { card = {} }
    end)

    local ask = moe.askPlayCard.create {
        game      = game,
        to        = me,
        reason    = '探针',
        condition = { name = '闪' },
    }
    ask:apply():await()

    lt.assertEquals('只问了确认那一次（没落到选牌）', 1, #asked)
    lt.assertEquals('缘由是那张来源牌', '确认:杀', asked[1])
    lt.assertEquals('这次响应成了', true, ask.success)
    lt.assertEquals('顶上的是一张虚拟牌', true, ask.card ~= nil and ask.card.virtual == true)
end)

---@async
lt.test('端到端：视为要素材 ⇒ 客户端收到选牌，选完就算发动了', function ()
    local game, players = support.newGame()
    local me = assert(players[1])

    local _, jink = support.dealCards(game, me)
    me:addViewAs('闪', nil, { condition = { name = '闪', zone = '手牌' } })

    ---@type string[]
    local asked = {}
    local _ <close> = moe.client.register('Ask.Select', function (_, params)
        ---@cast params Proto.Request.Ask.Select
        asked[#asked + 1] = params.reason
        local condition = assert(params.card)
        return { card = { condition.ids[1] } }
    end)

    local ask = moe.askPlayCard.create {
        game      = game,
        to        = me,
        reason    = '探针',
        condition = { name = '闪' },
    }
    ask:apply():await()

    local produced = assert(ask.card)
    lt.assertEquals('客户端被要了一次牌', 1, #asked)
    lt.assertEquals('缘由是视为的牌名', '闪', asked[1])
    lt.assertEquals('这次成了', true, ask.success)
    lt.assertEquals('答复是造出来的虚拟牌', true, produced.virtual == true)
    lt.assertEquals('素材就是那张实体【闪】', jink, assert(produced.subcards)[1])
end)
